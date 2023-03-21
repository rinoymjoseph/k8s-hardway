# Install cfssl

wget -q --show-progress --https-only --timestamping https://github.com/cloudflare/cfssl/releases/download/v1.6.1/cfssl_1.6.1_linux_amd64 https://github.com/cloudflare/cfssl/releases/download/v1.6.1/cfssljson_1.6.1_linux_amd64
chmod +x cfssl_1.6.1_linux_amd64 cfssljson_1.6.1_linux_amd64
sudo mv cfssl_1.6.1_linux_amd64 /usr/local/bin/cfssl
sudo mv cfssljson_1.6.1_linux_amd64 /usr/local/bin/cfssljson

# Provisioning CA

- Create a few directories for the TLS certs to live in.

mkdir -p pki/{admin,api,ca,clients,controller,front-proxy,proxy,scheduler,service-account,users}

TLS_C="IN"
TLS_L="Kochi"
TLS_OU="rinoys"
TLS_ST="Kerala"

# Generate the CA (Certificate Authority) config files & certificates

cat > pki/ca/ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > pki/ca/ca-csr.json <<EOF
{
  "CN": "Kubernetes",
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

cfssl gencert -initca pki/ca/ca-csr.json | cfssljson -bare pki/ca/ca


