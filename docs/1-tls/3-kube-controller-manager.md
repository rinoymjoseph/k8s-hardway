# Generate the kube-controller-manager cert and key
# These are used so that the kube-controller-manager can authenticate with the kube-api-server.

cat > pki/controller/kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${TLS_C}",
      "L": "${TLS_L}",
      "O": "system:kube-controller-manager",
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
  -profile=kubernetes \
  pki/controller/kube-controller-manager-csr.json | cfssljson -bare pki/controller/kube-controller-manager
