# ssh into workers

sudo hostnamectl set-hostname k8s-worker-1

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

# Getting more binaries
# Get fetching those binaries again (ignore kubectl if single node as you should already have it):

mkdir ~/downloads
cd ~/downloads

wget -q --show-progress --https-only --timestamping \
https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.22.0/crictl-v1.22.0-linux-amd64.tar.gz \
https://github.com/containernetworking/plugins/releases/download/v1.0.1/cni-plugins-linux-amd64-v1.0.1.tgz \
https://storage.googleapis.com/kubernetes-release/release/v1.23.0/bin/linux/amd64/kubectl \
https://storage.googleapis.com/kubernetes-release/release/v1.23.0/bin/linux/amd64/kube-proxy \
https://storage.googleapis.com/kubernetes-release/release/v1.23.0/bin/linux/amd64/kubelet

# Create some dirs

sudo mkdir -p \
 /etc/cni/net.d \
 /opt/cni/bin \
 /var/lib/kubelet \
 /var/lib/kube-proxy \
 /var/lib/kubernetes \
 /var/run/kubernetes

# and now get it all installed

sudo tar -xvf cni-plugins-linux-amd64-v1.0.1.tgz -C /opt/cni/bin/
chmod +x kubectl kube-proxy kubelet 
sudo mv kubectl kube-proxy kubelet /usr/local/bin/

# Copy/Move files

cd ~/pki/
sudo cp k8s-worker-1-key.pem k8s-worker-1.pem /var/lib/kubelet/
sudo cp ca.pem /var/lib/kubernetes/

cd ~/configs
sudo cp k8s-worker-1.kubeconfig /var/lib/kubelet/kubeconfig
sudo cp kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

# Install crio

OS=xUbuntu_22.04
CRIO_VERSION=1.23

echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /"|sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRIO_VERSION/$OS/ /"|sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.list

curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION/$OS/Release.key | sudo apt-key add -
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | sudo apt-key add -

sudo apt update
sudo apt install cri-o cri-o-runc -y

sudo apt show cri-o

sudo systemctl enable crio.service
sudo systemctl start crio.service
sudo systemctl status crio.service

sudo apt install cri-tools

crictl images

# If you do have swap then this will only disable swap until your next reboot.
# To disable it permanently, comment it out of `/etc/fstab`

Confirm SWAP is off with:

free
##Results
  total used free shared buff/cache available
  Mem: 7.7G 692M 339M 104M 6.7G 6.6G
  Swap: 0B 0B 0B
-------------------------------------------------------------------

# CNI networking

cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "0.4.0",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "10.200.0.0/24"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

# Now the loopback config….

cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{

    "cniVersion": "0.4.0",
    "name": "lo",
    "type": "loopback"
}
EOF
-------------------------------------------------------------------------------------------
# Configure kubelet

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

# Generate config

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
sudo systemctl enable kubelet kube-proxy
sudo systemctl start kubelet kube-proxy

# Verify it all
# Jump back over to the controllers, since this where you currently have the admin.kubeconfig stored and run:

kubectl get nodes --kubeconfig admin.kubeconfig

## Results
NAME       STATUS   ROLES    AGE   VERSION
worker-0   Ready    <none>   52s   v1.12.0
worker-1   Ready    <none>   52s   v1.12.0
worker-2   Ready    <none>   52s   v1.12.0

