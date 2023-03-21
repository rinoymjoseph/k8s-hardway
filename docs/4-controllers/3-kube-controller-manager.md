# Configure the kube-controller-manager
# The Kube-Controller-Manager is a collection of controllers. Some of them include:

# Node controller: Responsible for noticing and responding when nodes go down.
# Job controller: Watches for Job objects that represent one-off tasks, then creates Pods to run those tasks to completion.
# Endpoints controller: Populates the Endpoints object (that is, joins Services & Pods).
# Service Account & Token controllers: Create default accounts and API access tokens for new namespaces.
# There are many other controllers but the Kube-Controller-Manager collates them all together and allows us to deploy them in a single binary.

sudo cp ~/kube-controller-manager.kubeconfig /var/lib/kubernetes/

# Now configure the service

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