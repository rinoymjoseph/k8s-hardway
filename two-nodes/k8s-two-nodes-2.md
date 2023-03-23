# ssh into controllers

sudo hostnamectl set-hostname k8s-controller-1

cat << EOF | sudo tee /etc/hosts
127.0.0.1 localhost
127.0.1.1 $(hostname -s)
# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
192.168.0.151 k8s-controller-1
192.168.0.161 k8s-worker-1
EOF

mkdir ~/downloads

cd ~/downloads

# Get the files required and move them into place
wget -q --show-progress --https-only --timestamping "https://github.com/etcd-io/etcd/releases/download/v3.5.1/etcd-v3.5.1-linux-amd64.tar.gz"
tar -xzvf etcd-v3.5.1-linux-amd64.tar.gz
sudo mv etcd-v3.5.1-linux-amd64/etcd* /usr/local/bin/

wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.23.0/bin/linux/amd64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.23.0/bin/linux/amd64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.23.0/bin/linux/amd64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.23.0/bin/linux/amd64/kubectl"
chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/

# Create directories

sudo mkdir -p /etc/kubernetes/config
sudo mkdir -p /etc/etcd /var/lib/etcd
sudo mkdir -p /var/lib/kubernetes/

# Movet pki

cd ~/pki

sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
sudo cp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem \
    front-proxy-key.pem front-proxy.pem /var/lib/kubernetes/

cd ~/data-encryption

sudo cp encryption-config.yaml /var/lib/kubernetes/

cd ~/configs
sudo cp kube-controller-manager.kubeconfig /var/lib/kubernetes/
sudo cp kube-scheduler.kubeconfig /var/lib/kubernetes/
-----------------------------------------------------------------------------------------------
# Configuring the ETCD server

# Create the service file
cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos
[Service]
ExecStart=/usr/local/bin/etcd \\
  --name k8s-controller-1 \\
  --data-dir=/var/lib/etcd \\
  --listen-peer-urls https://192.168.0.151:2380 \\
  --listen-client-urls https://192.168.0.151:2379,https://127.0.0.1:2379 \\
  --initial-advertise-peer-urls https://192.168.0.151:2380 \\
  --initial-cluster k8s-controller-1=https://192.168.0.151:2380 \\
  --initial-cluster-state new \\
  --initial-cluster-token etcd-cluster-1 \\
  --advertise-client-urls https://192.168.0.151:2379 \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --client-cert-auth \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-client-cert-auth \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

# Start it up
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd

# Rejoice (and test)!
sudo etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem

# Results
bbf8ddbd0b1c5fdc, started, k8s-controller-1, https://192.168.0.151:2380, https://192.168.0.151:2379, false
--------------------------------------------------------------------------------------------------------
# Configure the kube-apiserver

# Create an audit policy for the api server to implement.

cat <<EOF | sudo tee /etc/kubernetes/audit-policy.yaml
apiVersion: audit.k8s.io/v1 # This is required.
kind: Policy
# Don't generate audit events for all requests in RequestReceived stage.
omitStages:
  - "RequestReceived"
rules:
  # Log pod changes at RequestResponse level
  - level: RequestResponse
    resources:
    - group: ""
      # Resource "pods" doesn't match requests to any subresource of pods,
      # which is consistent with the RBAC policy.
      resources: ["pods"]
  # Log "pods/log", "pods/status" at Metadata level
  - level: Metadata
    resources:
    - group: ""
      resources: ["pods/log", "pods/status"]

  # Don't log requests to a configmap called "controller-leader"
  - level: None
    resources:
    - group: ""
      resources: ["configmaps"]
      resourceNames: ["controller-leader"]

  # Don't log watch requests by the "system:kube-proxy" on endpoints or services
  - level: None
    users: ["system:kube-proxy"]
    verbs: ["watch"]
    resources:
    - group: "" # core API group
      resources: ["endpoints", "services"]

  # Don't log authenticated requests to certain non-resource URL paths.
  - level: None
    userGroups: ["system:authenticated"]
    nonResourceURLs:
    - "/api*" # Wildcard matching.
    - "/version"

  # Log the request body of configmap changes in kube-system.
  - level: Request
    resources:
    - group: "" # core API group
      resources: ["configmaps"]
    # This rule only applies to resources in the "kube-system" namespace.
    # The empty string "" can be used to select non-namespaced resources.
    namespaces: ["kube-system"]

  # Log configmap and secret changes in all other namespaces at the Metadata level.
  - level: Metadata
    resources:
    - group: "" # core API group
      resources: ["secrets", "configmaps"]

  # Log all other resources in core and extensions at the Request level.
  - level: Request
    resources:
    - group: "" # core API group
    - group: "extensions" # Version of group should NOT be included.

  # A catch-all rule to log all other requests at the Metadata level.
  - level: Metadata
    # Long-running requests like watches that fall under this rule will not
    # generate an audit event in RequestReceived.
    omitStages:
      - "RequestReceived"
EOF

# Create the service

cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes
[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=192.168.0.151 \\
  --allow-privileged=true \\
  --apiserver-count=1 \\
  --audit-policy-file=/etc/kubernetes/audit-policy.yaml \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://192.168.0.151:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname \\
  --proxy-client-cert-file=/var/lib/kubernetes/front-proxy.pem \\
  --proxy-client-key-file=/var/lib/kubernetes/front-proxy-key.pem \\
  --requestheader-allowed-names=front-proxy-client \\
  --requestheader-client-ca-file=/var/lib/kubernetes/ca.pem\\
  --requestheader-extra-headers-prefix=X-Remote-Extra- \\
  --requestheader-group-headers=X-Remote-Group \\
  --requestheader-username-headers=X-Remote-User \\
  --runtime-config='api/all=true' \\
  --secure-port=6443 \\
  --service-account-issuer=https://192.168.0.151:6443 \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-account-signing-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

# Start kube-apiserver

sudo systemctl daemon-reload
sudo systemctl enable kube-apiserver
sudo systemctl start kube-apiserver

# Check service logs
journalctl -u kube-apiserver.service -f
-------------------------------------------------------------------------------------

# Configure the kube-controller-manager

cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes
[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --allocate-node-cidrs=true \\
  --bind-address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable kube-controller-manager
sudo systemctl start kube-controller-manager

journalctl -u kube-controller-manager.service  -f
------------------------------------------------------------------------------------------
# Configure the kube-scheduler

# Create the yaml config files

cat <<EOF | sudo tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1beta2
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF


# Now configure the service

cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes
[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

# Star service

sudo systemctl daemon-reload
sudo systemctl enable kube-scheduler
sudo systemctl start kube-scheduler
---------------------------------------------------------------------------------------
# Setup the HTTP health checks
# Since the /healthz check sits on port 6443, and you’re not exposing that, you need to get nginx installed as a proxy (or any other proxy service you wish of course).

sudo apt update
sudo apt install -y nginx
cat > kubernetes.default.svc.cluster.local <<EOF
server {
  listen      80;
  server_name kubernetes.default.svc.cluster.local;
location /healthz {
     proxy_pass                    https://127.0.0.1:6443/healthz;
     proxy_ssl_trusted_certificate /var/lib/kubernetes/ca.pem;
  }
}
EOF
sudo rm /etc/nginx/sites-enabled/default
sudo mv kubernetes.default.svc.cluster.local /etc/nginx/sites-available/kubernetes.default.svc.cluster.local
sudo ln -s /etc/nginx/sites-available/kubernetes.default.svc.cluster.local /etc/nginx/sites-enabled/
sudo systemctl restart nginx

# Verify all is healthy
kubectl get componentstatuses --kubeconfig admin.kubeconfig

# You should get a response with no errors from controller-manager, scheduler and etcd-x as shown below.

## Results

Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE                         ERROR
scheduler            Healthy   ok                              
controller-manager   Healthy   ok                              
etcd-0               Healthy   {"health":"true","reason":""} 

# Test the nginx proxy is working

curl -H "Host: kubernetes.default.svc.cluster.local" -i http://127.0.0.1/healthz

## Results

HTTP/1.1 200 OK
Server: nginx/1.18.0 (Ubuntu)
Date: Tue, 21 Mar 2023 13:05:12 GMT
Content-Type: text/plain; charset=utf-8
Content-Length: 2
Connection: keep-alive
Audit-Id: 3e6af70b-80b2-4c32-86d2-c67328ceb772
Cache-Control: no-cache, private
X-Content-Type-Options: nosniff

# Create the ClusterRole and ClusterRoleBinding on one of the controllers.
# This allows the kube-apiserver to “talk” to the kubelet. Without this requests would fail.

cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF

cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF