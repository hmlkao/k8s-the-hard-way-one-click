#!/usr/bin/env bash
#
# Create /healthz endpoint on all control nodes to check K8s status
#
set -euo pipefail

. ../config

for instance in "${controllers[@]}"; do
  ip=${intips[$instance]}
  ssh "${user}@${ip}" sudo apt update
  ssh "${user}@${ip}" sudo apt install -y nginx

  # Create config file for nginx
  cat > kubernetes.default.svc.cluster.local <<EOF
server {
  listen      80;
  server_name kubernetes.default.svc.cluster.local;

  location /healthz {
     proxy_pass                    https://127.0.0.1:6443/healthz;
     proxy_ssl_trusted_certificate /opt/kubernetes/pki/ca.pem;
  }
}
EOF

  # Copy Nginx config file to servers
  scp \
    kubernetes.default.svc.cluster.local \
    "${user}@${ip}:~/"
  ssh "${user}@${ip}" sudo mv kubernetes.default.svc.cluster.local /etc/nginx/sites-available/
  ssh "${user}@${ip}" sudo ln -s \
    /etc/nginx/sites-available/kubernetes.default.svc.cluster.local \
    /etc/nginx/sites-enabled/kubernetes.default.svc.cluster.local

  ssh "${user}@${ip}" sudo systemctl enable nginx
  ssh "${user}@${ip}" sudo systemctl restart nginx

  # Wait for startup
  sleep 2

  # Show component status
  ssh "${user}@${ip}" kubectl --kubeconfig /opt/kubernetes/admin.kubeconfig get componentstatuses
done
