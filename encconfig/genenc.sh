#!/usr/bin/env bash
set -euo pipefail

. ../config

if [ ! -e key ]; then
  head -c 32 /dev/urandom | base64 > key
fi

enc_key=$(cat key)
cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${enc_key}
      - identity: {}
EOF

for instance in "${controllers[@]}"; do
  ip=${intips[$instance]}
  ssh "${user}@${ip}" sudo mkdir -p /opt/kubernetes
  scp \
    encryption-config.yaml \
    "${user}@${ip}:~/"
  ssh "${user}@${ip}" "sudo mv encryption-config.yaml /opt/kubernetes/"
done
