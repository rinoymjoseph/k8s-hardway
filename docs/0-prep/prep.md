cat << EOF | sudo tee /etc/hosts
127.0.0.1 localhost
127.0.1.1 $(hostname -s)
# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
192.168.0.150 k8s-controllers-lb
192.168.0.151 k8s-controller-1
192.168.0.152 k8s-controller-2
192.168.0.153 k8s-controller-3
192.168.0.161 k8s-worker-1
192.168.0.162 k8s-worker-2
192.168.0.163 k8s-worker-3
EOF