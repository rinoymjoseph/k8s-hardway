# Copy the files to the controllers and workers as shown below.
# If you’re on a single node then simply copy all files listed below 
# for both controllers & workers to the single node.

for instance in k8s-worker-1 k8s-worker-2 k8s-worker-3; do
  scp pki/ca/ca.pem pki/clients/${instance}-key.pem pki/clients/${instance}.pem USER@${instance}:~/
done
for instance in k8s-controller-1 k8s-controller-2 k8s-controller-3; do
  scp pki/ca/ca.pem pki/ca/ca-key.pem pki/api/kubernetes-key.pem pki/api/kubernetes.pem pki/service-account/service-account-key.pem pki/service-account/service-account.pem pki/front-proxy/front-proxy-key.pem pki/front-proxy/front-proxy.pem USER@${instance}:~/
done

scp pki/ca/ca.pem pki/api/kubernetes-key.pem pki/api/kubernetes.pem USER@k8s-controllers-lb:~/