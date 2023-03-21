# Generating the data encryption key and config
# This will be used for encrypting data between nodes.

mkdir data-encryption

ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat > data-encryption/encryption-config.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
    - aescbc:
        keys:
        - name: key1
          secret: ${ENCRYPTION_KEY}
    - identity: {}
EOF

# Now push them to the controller(s) or the single node if that’s what you’re using.

for instance in k8s-controller-0 k8s-controller-1 k8s-controller-2; do
  scp data-encryption/encryption-config.yaml USER@${instance}:~/
done