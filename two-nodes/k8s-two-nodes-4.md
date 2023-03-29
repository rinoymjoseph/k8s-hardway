# ssh into bootstrap machine

kubectl config set-cluster rinoys \
        --certificate-authority=pki/ca/ca.pem \
        --embed-certs=true \
        --server=https://192.168.0.151:6443 \
        --kubeconfig=configs/admin/admin-remote.kubeconfig

kubectl config set-credentials admin \
        --client-certificate=pki/admin/admin.pem \
        --client-key=pki/admin/admin-key.pem \
        --embed-certs=true \
        --kubeconfig=configs/admin/admin-remote.kubeconfig

kubectl config set-context rinoys \
        --cluster=rinoys \
        --user=admin \
        --kubeconfig=configs/admin/admin-remote.kubeconfig

kubectl config use-context rinoys --kubeconfig=configs/admin/admin-remote.kubeconfig

mkdir -p ~/.kube
# Then make it permanent
cp configs/admin/admin-remote.kubeconfig ~/.kube/config

kubectl get no
---------------------------------------------------------------------------------------------------

curl https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico-etcd.yaml -o calico.yaml

# Set ETCD IPs
sed -i 's/etcd_endpoints:\ "http:\/\/<ETCD_IP>:<ETCD_PORT>"/etcd_endpoints:\ "https:\/\/192.168.0.151:2379"/g' calico.yaml
# Set Certificate data in secret
sed -i "s/# etcd-cert: null/etcd-cert: $(cat pki\/kube_apiserver\/kubernetes.pem | base64 -w 0)/g" calico.yaml
sed -i "s/# etcd-key: null/etcd-key: $(cat pki\/kube_apiserver\/kubernetes-key.pem | base64 -w 0)/g" calico.yaml
sed -i "s/# etcd-ca: null/etcd-ca: $(cat pki\/ca\/ca.pem | base64 -w 0)/g" calico.yaml
# Setup Config map with secret information
sed -i "s/etcd_ca: \"\"/etcd_ca: \"\/calico-secrets\/etcd-ca\"/g" calico.yaml
sed -i "s/etcd_cert: \"\"/etcd_cert: \"\/calico-secrets\/etcd-cert\"/g" calico.yaml
sed -i "s/etcd_key: \"\"/etcd_key: \"\/calico-secrets\/etcd-key\"/g" calico.yaml
# Setup the POD CIDR ENV
sed -i 's/# - name: CALICO_IPV4POOL_CIDR/- name: CALICO_IPV4POOL_CIDR/g' calico.yaml
sed -i 's/#   value: "192.168.0.0\/16"/  value: "10.200.0.0\/16"/g' calico.yaml