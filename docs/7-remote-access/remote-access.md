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