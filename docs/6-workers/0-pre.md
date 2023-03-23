# ssh into workers

sudo hostnamectl set-hostname k8s-worker-1

# Getting more binaries
# Get fetching those binaries again (ignore kubectl if single node as you should already have it):

mkdir ~/downloads

wget -q --show-progress --https-only --timestamping \
https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.22.0/crictl-v1.22.0-linux-amd64.tar.gz \
https://github.com/opencontainers/runc/releases/download/v1.0.3/runc.amd64 \
https://github.com/containernetworking/plugins/releases/download/v1.0.1/cni-plugins-linux-amd64-v1.0.1.tgz \
https://github.com/containerd/containerd/releases/download/v1.5.8/containerd-1.5.8-linux-amd64.tar.gz \
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

mkdir containerd
tar -xvf crictl-v1.22.0-linux-amd64.tar.gz
tar -xvf containerd-1.5.8-linux-amd64.tar.gz -C containerd
sudo tar -xvf cni-plugins-linux-amd64-v1.0.1.tgz -C /opt/cni/bin/
sudo mv runc.amd64 runc
chmod +x crictl kubectl kube-proxy kubelet runc 
sudo mv crictl kubectl kube-proxy kubelet runc /usr/local/bin/
sudo mv containerd/bin/* /bin/

# If you do have swap then this will only disable swap until your next reboot.
# To disable it permanently, comment it out of `/etc/fstab`

Confirm SWAP is off with:

free
##Results
  total used free shared buff/cache available
  Mem: 7.7G 692M 339M 104M 6.7G 6.6G
  Swap: 0B 0B 0B