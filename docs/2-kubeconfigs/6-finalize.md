# Finally, let’s move the kubeconfigs
# Now push them as you did with the TLS certs and configs.

for instance in k8s-worker-1 k8s-worker-2 k8s-worker-3; do
  scp configs/clients/${instance}.kubeconfig configs/proxy/kube-proxy.kubeconfig USER@${instance}:~/
done

for instance in k8s-controller-0 k8s-controller-1 k8s-controller-2; do
  scp configs/admin/admin.kubeconfig configs/controller/kube-controller-manager.kubeconfig configs/scheduler/kube-scheduler.kubeconfig USER@${instance}:~/
done