# CNI networking
# This is the part where some people can fall over because it can cause a little confusion for some.
# The POD_CIDR for THIS worker node is the range that the pods will use for networking on THIS worker 
# node. It is different per node and is sliced out of the main POD_CIDR that was defined at the top of 
# the article. Remember that? It’s 10.200.0.0/16.

# since you set 10.200.0.0/16 as the POD_CIDR at the top of the article to be the main network 
# you’ll use you can specify ANY subnet within 10.200.0.0/16 for each worker node.
# A subnet such as 10.200.1.0/24.

# For the many worker nodes, you can ensure this is set to 10.200.0.0/24, 10.200.1.0/24, 10.200.2.0/24
# and so on for each worker node. This doesn’t need to be within the 192.168.0.0/24 network that the 
# nodes work on because it is an internal network used by the cluster.

# Config files
# Now you can create the CNI bridge network config file.

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