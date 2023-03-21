# Setting up ETCD

# Configuring the ETCD server
# Change ens3 to your interface name.

INTERNAL_IP=$(ip addr show ens3 | grep -Po 'inet \K[\d.]+') #THIS controller's internal IP
ETCD_NAME=$(hostname -s)

# Create the service file
cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos
[Service]
ExecStart=/usr/local/bin/etcd \\
  --name k8s-controller-1 \\
  --data-dir=/var/lib/etcd \\
  --listen-peer-urls https://192.168.0.151:2380 \\
  --listen-client-urls https://192.168.0.151:2379,https://127.0.0.1:2379 \\
  --initial-advertise-peer-urls https://192.168.0.151:2380 \\
  --initial-cluster k8s-controller-1=https://192.168.0.151:2380 \\
  --initial-cluster-state new \\
  --initial-cluster-token etcd-cluster-1 \\
  --advertise-client-urls https://192.168.0.151:2379 \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --client-cert-auth \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-client-cert-auth \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

# Start it up
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd

# Rejoice (and test)!
sudo etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem

# Results
bbf8ddbd0b1c5fdc, started, k8s-controller-1, https://192.168.0.151:2380, https://192.168.0.151:2379, false
