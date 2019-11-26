#!/usr/bin/env bash
#set -euo pipefail

. ../config

etcd_ver=3.4.3

for instance in "${controllers[@]}"; do
  ip=${intips[$instance]}
  urls+=("$instance=https://$ip:2380")
  cluster_urls=$(IFS=","; echo "${urls[*]}")
done

for instance in "${controllers[@]}"; do
  ip=${intips[$instance]}

  ssh "${user}@${ip}" wget -q --show-progress --https-only --timestamping \
    "https://github.com/etcd-io/etcd/releases/download/v${etcd_ver}/etcd-v${etcd_ver}-linux-amd64.tar.gz"
  ssh "${user}@${ip}" tar -xf "etcd-v${etcd_ver}-linux-amd64.tar.gz"
  ssh "${user}@${ip}" sudo mv -v "etcd-v${etcd_ver}-linux-amd64/etcd"* /usr/local/bin/
  ssh "${user}@${ip}" sudo mkdir -pv /etc/etcd /var/lib/etcd

  cat > "./etcd-${instance}.service" << EOF
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=simple
ExecStart=/usr/local/bin/etcd \\
  --name ${instance} \\
  --cert-file=/opt/kubernetes/pki/api-server.pem \\
  --key-file=/opt/kubernetes/pki/api-server-key.pem \\
  --peer-cert-file=/opt/kubernetes/pki/api-server.pem \\
  --peer-key-file=/opt/kubernetes/pki/api-server-key.pem \\
  --trusted-ca-file=/opt/kubernetes/pki/ca.pem \\
  --peer-trusted-ca-file=/opt/kubernetes/pki/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${intips[$instance]}:2380 \\
  --listen-peer-urls https://${intips[$instance]}:2380 \\
  --listen-client-urls https://${intips[$instance]}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${intips[$instance]}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster ${cluster_urls} \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  scp "./etcd-${instance}.service" "${user}@${ip}":etcd.service

  ssh "${user}@${ip}" sudo mv -v etcd.service /etc/systemd/system/etcd.service
  ssh "${user}@${ip}" sudo systemctl daemon-reload
  ssh "${user}@${ip}" sudo systemctl enable etcd
  ssh "${user}@${ip}" sudo reboot
done

# Run etcd service after all cluster member are prepared to run
# otherwise service can end in dead state
# DOESN'T WORK I have to reboot OS
# for instance in "${controllers[@]}"; do
#   ip=${intips[$instance]}
#   # ETCD will not start if there is no other cluster members, run it in background
#   ssh "${user}@${ip}" sudo -b nohup bash -c "systemctl restart etcd </dev/null 2>&1 1>/dev/null"
# done

# Wait for all ETCD members boot up
sleep 30

ssh "${user}@${ip}" sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/opt/kubernetes/pki/ca.pem \
  --cert=/opt/kubernetes/pki/api-server.pem \
  --key=/opt/kubernetes/pki/api-server-key.pem
