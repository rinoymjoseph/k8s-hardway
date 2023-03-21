# Generate Worker kubeconfigs
# If you’re on a single node you can just remove the first and last 
# line and replace ${instance} with your single node hostname.

for instance in k8s-worker-1 k8s-worker-2 k8s-worker-3; do
kubectl config set-cluster rinoys\
    --certificate-authority=pki/ca/ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=configs/clients/${instance}.kubeconfig
kubectl config set-credentials system:node:${instance} \
    --client-certificate=pki/clients/${instance}.pem \
    --client-key=pki/clients/${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=configs/clients/${instance}.kubeconfig
kubectl config set-context default \
    --cluster=rinoys \
    --user=system:node:${instance} \
    --kubeconfig=configs/clients/${instance}.kubeconfig 
kubectl config use-context default --kubeconfig=configs/clients/${instance}.kubeconfig
done