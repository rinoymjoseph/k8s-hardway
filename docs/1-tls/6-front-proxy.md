# Generate the front-proxy cert and key
# These are used so that the kube-proxy can support an extension API server.

cat > pki/front-proxy/front-proxy-csr.json <<EOF
{
  "CN": "front-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${TLS_C}",
      "L": "${TLS_L}",
      "O": "front-proxy",
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
  pki/front-proxy/front-proxy-csr.json | cfssljson -bare pki/front-proxy/front-proxy
