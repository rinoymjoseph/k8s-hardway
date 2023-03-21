# Generate the api-server cert and key
# These are used so that the kube-api-server can be authenticated against.

# The KUBERNETES_PUBLIC_ADDRESS will be the IP/VIP/Pool IP of the load balancer that will direct all traffic to the controller nodes. In our case it’s 192.168.0.150.

# NOTE: The — ‘hostname=’ line may need adjusting if you have different IPs for your controllers.

KUBERNETES_PUBLIC_ADDRESS=192.168.0.150

cat > pki/api/kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${TLS_C}",
      "L": "${TLS_L}",
      "O": "Kubernetes",
      "OU": "${TLS_OU}",
      "ST": "${TLS_ST}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=pki/ca/ca.pem \
  -ca-key=pki/ca/ca-key.pem \
  -config=pki/ca/ca-config.json \
  -hostname=192.168.0.151,192.168.0.152,192.168.0.153,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,kubernetes.default \
  -profile=kubernetes \
  pki/api/kubernetes-csr.json | cfssljson -bare pki/api/kubernetes