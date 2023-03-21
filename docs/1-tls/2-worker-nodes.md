# Generate the worker(s) certs and keys
# These are used so that the worker nodes can authenticate with the kube-api-server.

for instance in k8s-worker-1 k8s-worker-2 k8s-worker-3; do
cat > pki/clients/${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${TLS_C}",
      "L": "${TLS_L}",
      "O": "system:nodes",
      "OU": "${TLS_OU}",
      "ST": "${TLS_ST}"
    }
  ]
}
EOF
INTERNAL_IP=$(ip addr show ens18 | grep -Po 'inet \K[\d.]+')
cfssl gencert \
  -ca=pki/ca/ca.pem \
  -ca-key=pki/ca/ca-key.pem \
  -config=pki/ca/ca-config.json \
  -hostname=${instance},${INTERNAL_IP} \
  -profile=kubernetes \
  pki/clients/${instance}-csr.json | cfssljson -bare pki/clients/${instance}
done