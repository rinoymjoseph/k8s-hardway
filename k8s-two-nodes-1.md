86:AC:41:71:70:7D 192.168.0.149 - k8s-bootstrap
86:AC:41:B6:DC:C2 192.168.0.151 - k8s-controller-1
86:AC:41:A9:79:16 192.168.0.161 - k8s-worker-1

# ssh into k8s-bootstrap

sudo hostnamectl set-hostname k8s-bootstrap

cat << EOF | sudo tee /etc/hosts
127.0.0.1 localhost
127.0.1.1 $(hostname -s)
# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
192.168.0.149 k8s-bootstrap
192.168.0.151 k8s-controller-1
192.168.0.161 k8s-worker-1
EOF


# Install kubectl

curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.23.0/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install cfssl

wget -q --show-progress --https-only --timestamping https://github.com/cloudflare/cfssl/releases/download/v1.6.1/cfssl_1.6.1_linux_amd64 https://github.com/cloudflare/cfssl/releases/download/v1.6.1/cfssljson_1.6.1_linux_amd64
chmod +x cfssl_1.6.1_linux_amd64 cfssljson_1.6.1_linux_amd64
sudo mv cfssl_1.6.1_linux_amd64 /usr/local/bin/cfssl
sudo mv cfssljson_1.6.1_linux_amd64 /usr/local/bin/cfssljson

# Provisioning CA

- Create a few directories for the TLS certs to live in.

mkdir -p pki/{admin,api,ca,clients,controller,front-proxy,proxy,scheduler,service-account,users}

TLS_C="IN"
TLS_L="Kochi"
TLS_OU="Rinoys"
TLS_ST="Kerala"

# Generate the CA (Certificate Authority) config files & certificates

cat > pki/ca/ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > pki/ca/ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${TLS_C}",
      "L": "${TLS_L}",
      "O": "Kubernetes",
      "OU": "${TLS_OU}",
      "ST": "${TLS_ST}"
    }
  ]
}
EOF

cfssl gencert -initca pki/ca/ca-csr.json | cfssljson -bare pki/ca/ca
------------------------------------------------------------------------------------

# Generate the admin user config files and certificates
# These will be used for the user to be able to interact with the cluster via kubectl.

cat > pki/admin/admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${TLS_C}",
      "L": "${TLS_L}",
      "O": "system:masters",
      "OU": "${TLS_OU}",
      "ST": "${TLS_ST}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=pki/ca/ca.pem \
  -ca-key=pki/ca/ca-key.pem \
  -config=pki/ca/ca-config.json \
  -profile=kubernetes \
  pki/admin/admin-csr.json | cfssljson -bare pki/admin/admin
-----------------------------------------------------------------------------------------

# Generate the worker(s) certs and keys
# These are used so that the worker nodes can authenticate with the kube-api-server.

cat > pki/clients/k8s-worker-1-csr.json <<EOF
{
  "CN": "system:node:k8s-worker-1",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${TLS_C}",
      "L": "${TLS_L}",
      "O": "system:nodes",
      "OU": "${TLS_OU}",
      "ST": "${TLS_ST}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=pki/ca/ca.pem \
  -ca-key=pki/ca/ca-key.pem \
  -config=pki/ca/ca-config.json \
  -hostname=k8s-worker-1,192.168.0.161\
  -profile=kubernetes \
  pki/clients/k8s-worker-1-csr.json | cfssljson -bare pki/clients/k8s-worker-1
--------------------------------------------------------------------------------------------------

# Generate the kube-controller-manager cert and key
# These are used so that the kube-controller-manager can authenticate with the kube-api-server.

cat > pki/controller/kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${TLS_C}",
      "L": "${TLS_L}",
      "O": "system:kube-controller-manager",
      "OU": "${TLS_OU}",
      "ST": "${TLS_ST}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=pki/ca/ca.pem \
  -ca-key=pki/ca/ca-key.pem \
  -config=pki/ca/ca-config.json \
  -profile=kubernetes \
  pki/controller/kube-controller-manager-csr.json | cfssljson -bare pki/controller/kube-controller-manager
-------------------------------------------------------------------------------------------------------------

# Generate the kube-proxy cert and key
# These are used so that the kube-proxy can authenticate with the kube-api-server.

cat > pki/proxy/kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${TLS_C}",
      "L": "${TLS_L}",
      "O": "system:node-proxier",
      "OU": "${TLS_OU}",
      "ST": "${TLS_ST}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=pki/ca/ca.pem \
  -ca-key=pki/ca/ca-key.pem \
  -config=pki/ca/ca-config.json \
  -profile=kubernetes \
  pki/proxy/kube-proxy-csr.json | cfssljson -bare pki/proxy/kube-proxy
----------------------------------------------------------------------------------------------------------
# Generate the scheduler cert and key
# These are used so that the kube-scheduler can authenticate with the kube-api-server.

cat > pki/scheduler/kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${TLS_C}",
      "L": "${TLS_L}",
      "O": "system:kube-scheduler",
      "OU": "${TLS_OU}",
      "ST": "${TLS_ST}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=pki/ca/ca.pem \
  -ca-key=pki/ca/ca-key.pem \
  -config=pki/ca/ca-config.json \
  -profile=kubernetes \
  pki/scheduler/kube-scheduler-csr.json | cfssljson -bare pki/scheduler/kube-scheduler
----------------------------------------------------------------------------------------------
# Generate the front-proxy cert and key
# These are used so that the kube-proxy can support an extension API server.

cat > pki/front-proxy/front-proxy-csr.json <<EOF
{
  "CN": "front-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${TLS_C}",
      "L": "${TLS_L}",
      "O": "front-proxy",
      "OU": "${TLS_OU}",
      "ST": "${TLS_ST}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=pki/ca/ca.pem \
  -ca-key=pki/ca/ca-key.pem \
  -config=pki/ca/ca-config.json \
  -profile=kubernetes \
  pki/front-proxy/front-proxy-csr.json | cfssljson -bare pki/front-proxy/front-proxy
-----------------------------------------------------------------------------------------------------
# Generate the api-server cert and key
# These are used so that the kube-api-server can be authenticated against.

cat > pki/api/kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${TLS_C}",
      "L": "${TLS_L}",
      "O": "Kubernetes",
      "OU": "${TLS_OU}",
      "ST": "${TLS_ST}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=pki/ca/ca.pem \
  -ca-key=pki/ca/ca-key.pem \
  -config=pki/ca/ca-config.json \
  -hostname=192.168.0.151,127.0.0.1,kubernetes.default \
  -profile=kubernetes \
  pki/api/kubernetes-csr.json | cfssljson -bare pki/api/kubernetes
-------------------------------------------------------------------------------------------------------------------
# Generate the service-account cert and key
# These are used so that service accounts can authenticate with the kube-api-server.

cat > pki/service-account/service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${TLS_C}",
      "L": "${TLS_L}",
      "O": "Kubernetes",
      "OU": "${TLS_OU}",
      "ST": "${TLS_ST}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=pki/ca/ca.pem \
  -ca-key=pki/ca/ca-key.pem \
  -config=pki/ca/ca-config.json \
  -profile=kubernetes \
  pki/service-account/service-account-csr.json | cfssljson -bare pki/service-account/service-account
-----------------------------------------------------------------------------------------------------------------
# Copy the files to the controllers and workers as shown below.
# If you’re on a single node then simply copy all files listed below 
# for both controllers & workers to the single node.

scp pki/ca/ca.pem pki/clients/k8s-worker-1-key.pem pki/clients/k8s-worker-1.pem ability@k8s-worker-1:~/

scp pki/ca/ca.pem pki/ca/ca-key.pem pki/api/kubernetes-key.pem pki/api/kubernetes.pem pki/service-account/service-account-key.pem pki/service-account/service-account.pem pki/front-proxy/front-proxy-key.pem pki/front-proxy/front-proxy.pem ability@k8s-controller-1:~/
--------------------------------------------------------------------------------------------------------------------

# Generate Worker kubeconfigs

kubectl config set-cluster rinoys\
    --certificate-authority=pki/ca/ca.pem \
    --embed-certs=true \
    --server=https://192.168.0.151:6443 \
    --kubeconfig=configs/clients/k8s-worker-1.kubeconfig

kubectl config set-credentials system:node:k8s-worker-1 \
    --client-certificate=pki/clients/k8s-worker-1.pem \
    --client-key=pki/clients/k8s-worker-1-key.pem \
    --embed-certs=true \
    --kubeconfig=configs/clients/k8s-worker-1.kubeconfig
    
kubectl config set-context default \
    --cluster=rinoys \
    --user=system:node:k8s-worker-1 \
    --kubeconfig=configs/clients/k8s-worker-1.kubeconfig

kubectl config use-context default --kubeconfig=configs/clients/k8s-worker-1.kubeconfig
------------------------------------------------------------------------------------------------------------------------

# Generate kube-proxy kubeconfig

kubectl config set-cluster rinoys \
  --certificate-authority=pki/ca/ca.pem \
  --embed-certs=true \
  --server=https://192.168.0.151:6443 \
  --kubeconfig=configs/proxy/kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate=pki/proxy/kube-proxy.pem \
  --client-key=pki/proxy/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=configs/proxy/kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=rinoys \
  --user=system:kube-proxy \
  --kubeconfig=configs/proxy/kube-proxy.kubeconfig
  
kubectl config use-context default --kubeconfig=configs/proxy/kube-proxy.kubeconfig
--------------------------------------------------------------------------------------------------------------------
# Generate kube-controller-manager kubeconfig

kubectl config set-cluster rinoys \
  --certificate-authority=pki/ca/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=configs/controller/kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=pki/controller/kube-controller-manager.pem \
  --client-key=pki/controller/kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=configs/controller/kube-controller-manager.kubeconfig

kubectl config set-context default \
  --cluster=rinoys \
  --user=system:kube-controller-manager \
  --kubeconfig=configs/controller/kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=configs/controller/kube-controller-manager.kubeconfig
----------------------------------------------------------------------------------------------------------------------
# Generate kube-scheduler kubeconfig

kubectl config set-cluster rinoys \
  --certificate-authority=pki/ca/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=configs/scheduler/kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=pki/scheduler/kube-scheduler.pem \
  --client-key=pki/scheduler/kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=configs/scheduler/kube-scheduler.kubeconfig

kubectl config set-context default \
  --cluster=rinoys \
  --user=system:kube-scheduler \
  --kubeconfig=configs/scheduler/kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=configs/scheduler/kube-scheduler.kubeconfig
-----------------------------------------------------------------------------------------------------------------------
# Generate admin user kubeconfig

kubectl config set-cluster rinoys \
  --certificate-authority=pki/ca/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=configs/admin/admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=pki/admin/admin.pem \
  --client-key=pki/admin/admin-key.pem \
  --embed-certs=true \
  --kubeconfig=configs/admin/admin.kubeconfig

kubectl config set-context default \
  --cluster=rinoys \
  --user=admin \
  --kubeconfig=configs/admin/admin.kubeconfig
  
kubectl config use-context default --kubeconfig=configs/admin/admin.kubeconfig
------------------------------------------------------------------------------------------------------------------------

# Finally, let’s move the kubeconfigs
# Now push them as you did with the TLS certs and configs.

scp configs/clients/k8s-worker-1.kubeconfig configs/proxy/kube-proxy.kubeconfig ability@k8s-worker-1:~/

scp configs/admin/admin.kubeconfig configs/controller/kube-controller-manager.kubeconfig configs/scheduler/kube-scheduler.kubeconfig ability@k8s-controller-1:~/
------------------------------------------------------------------------------------------------------------------
# Generating the data encryption key and config
# This will be used for encrypting data between nodes.

mkdir data-encryption

ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat > data-encryption/encryption-config.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
    - aescbc:
        keys:
        - name: key1
          secret: ${ENCRYPTION_KEY}
    - identity: {}
EOF

# Now push them to the controller(s) or the single node if that’s what you’re using.

scp data-encryption/encryption-config.yaml ability@k8s-controller-1:~/