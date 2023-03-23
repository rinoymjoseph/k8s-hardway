# Configure kubelet

# The kubelet sits on the worker node and is what makes pods “real”.
# It receives an instruction to make a pod and in turn creates one within Containerd.

# Copy/Move files

sudo cp ~/k8s-worker-1-key.pem ~/k8s-worker-1.pem /var/lib/kubelet/
sudo cp ~/k8s-worker-1.kubeconfig /var/lib/kubelet/kubeconfig
sudo cp ~/ca.pem /var/lib/kubernetes/

# Generate config

cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "10.200.0.0/24"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/k8s-worker-1.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/k8s-worker-1-key.pem"
EOF

# Generate the SystemD service

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service
[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --cgroup-driver=systemd \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/crio/crio.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF


# Configure kube-proxy
# The Kube-proxy service is much like the kubelet, but for the network side of things.

# This is what allows NodePorts and alike to work. It receives instruction to create the
# requirements of a Service and makes them “real” within IPtables or IPVS.

# Generate config

sudo cp kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF

# Generate the SystemD Service

cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes
[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

# Now enable and start it all
**Before you do, make sure SWAP is off with sudo swapoff -a if you have SWAP space**

# Now you can continue by enabling and starting the services.

sudo systemctl daemon-reload
sudo systemctl enable containerd kubelet kube-proxy
sudo systemctl start containerd kubelet kube-proxy


# Verify it all
# Jump back over to the controllers, since this where you currently have the admin.kubeconfig stored and run:

kubectl get nodes --kubeconfig admin.kubeconfig

## Results
NAME       STATUS   ROLES    AGE   VERSION
worker-0   Ready    <none>   52s   v1.12.0
worker-1   Ready    <none>   52s   v1.12.0
worker-2   Ready    <none>   52s   v1.12.0

