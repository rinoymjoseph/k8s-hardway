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