#!/usr/bin/env bash
#
# Provision all master nodes
#
set -euo pipefail

. ../config

for instance in "${controllers[@]}"; do
  ips+=("${intips[$instance]}")
  cluster_ips=$(IFS=","; echo "${ips[*]}")
done

for instance in "${controllers[@]}"; do
  ip=${intips[$instance]}
  urls+=("https://$ip:2379")
  cluster_urls=$(IFS=","; echo "${urls[*]}")
done

############### Kubectl ################

for instance in "${controllers[@]}"; do
  ip="${intips[$instance]}"

  ssh "${user}@${ip}" sudo mkdir -vp /opt/kubernetes/config

  ssh "${user}@${ip}" wget -q --https-only --timestamping \
    "https://storage.googleapis.com/kubernetes-release/release/v${k8s_ver}/bin/linux/amd64/kubectl"

  ssh "${user}@${ip}" chmod +x kubectl
  ssh "${user}@${ip}" sudo mv -v kubectl /usr/local/bin/
done

################ Kube api server #################

for instance in "${controllers[@]}"; do
  ip="${intips[$instance]}"

  # Download binaries
  ssh "${user}@${ip}" wget -q --https-only --timestamping \
    "https://storage.googleapis.com/kubernetes-release/release/v${k8s_ver}/bin/linux/amd64/kube-apiserver"
  ssh "${user}@${ip}" chmod +x kube-apiserver
  ssh "${user}@${ip}" sudo mv -v kube-apiserver /usr/local/bin/

  # Create service
  cat > "kube-apiserver-${instance}.service" <<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${ip} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/opt/kubernetes/pki/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/opt/kubernetes/pki/ca.pem \\
  --etcd-certfile=/opt/kubernetes/pki/api-server.pem \\
  --etcd-keyfile=/opt/kubernetes/pki/api-server-key.pem \\
  --etcd-servers=${cluster_urls} \\
  --event-ttl=1h \\
  --encryption-provider-config=/opt/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/opt/kubernetes/pki/ca.pem \\
  --kubelet-client-certificate=/opt/kubernetes/pki/api-server.pem \\
  --kubelet-client-key=/opt/kubernetes/pki/api-server-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/opt/kubernetes/pki/service-account.pem \\
  --service-cluster-ip-range=${service_cluster_ip_range} \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/opt/kubernetes/pki/api-server.pem \\
  --tls-private-key-file=/opt/kubernetes/pki/api-server-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  scp "kube-apiserver-${instance}.service" "${user}@${ip}":kube-apiserver.service

  # Run service
  ssh "${user}@${ip}" sudo mv -v kube-apiserver.service /etc/systemd/system/kube-apiserver.service
  ssh "${user}@${ip}" sudo systemctl daemon-reload
  ssh "${user}@${ip}" sudo systemctl enable kube-apiserver
  ssh "${user}@${ip}" sudo systemctl restart kube-apiserver
done

##################### Kube controller manager ###########################

for instance in "${controllers[@]}"; do
  ip="${intips[$instance]}"

  ssh "${user}@${ip}" wget -q --https-only --timestamping \
    "https://storage.googleapis.com/kubernetes-release/release/v${k8s_ver}/bin/linux/amd64/kube-controller-manager"

  ssh "${user}@${ip}" chmod +x kube-controller-manager
  ssh "${user}@${ip}" sudo mv -v kube-controller-manager /usr/local/bin/

  cat > kube-controller-manager-${instance}.service <<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=${cluster_cidr} \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/opt/kubernetes/pki/ca.pem \\
  --cluster-signing-key-file=/opt/kubernetes/pki/ca-key.pem \\
  --kubeconfig=/opt/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/opt/kubernetes/pki/ca.pem \\
  --service-account-private-key-file=/opt/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=${service_cluster_ip_range} \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  scp "./kube-controller-manager-${instance}.service" "${user}@${ip}":kube-controller-manager.service

  ssh "${user}@${ip}" sudo mv -v kube-controller-manager.service /etc/systemd/system/kube-controller-manager.service
  ssh "${user}@${ip}" sudo systemctl daemon-reload
  ssh "${user}@${ip}" sudo systemctl enable kube-controller-manager
  ssh "${user}@${ip}" sudo systemctl restart kube-controller-manager
done

##################### Kube scheduler ########################

for instance in "${controllers[@]}"; do
  ip="${intips[$instance]}"

  ssh "${user}@${ip}" sudo mkdir -pv /opt/kubernetes/config

  # Download binaries
  ssh "${user}@${ip}" wget -q --https-only --timestamping \
    "https://storage.googleapis.com/kubernetes-release/release/v${k8s_ver}/bin/linux/amd64/kube-scheduler"

  ssh "${user}@${ip}" chmod +x kube-scheduler
  ssh "${user}@${ip}" sudo mv -v kube-scheduler /usr/local/bin/

  # Config
  cat > "kube-scheduler-${instance}.yaml" <<EOF
apiVersion: kubescheduler.config.k8s.io/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/opt/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF
  scp "kube-scheduler-${instance}.yaml" "${user}@${ip}":kube-scheduler.yaml
  ssh "${user}@${ip}" sudo mv -v "kube-scheduler.yaml" /opt/kubernetes/config/

  # Create service
  cat > "kube-scheduler-${instance}.service" <<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/opt/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  scp "./kube-scheduler-${instance}.service" "${user}@${ip}":kube-scheduler.service
  ssh "${user}@${ip}" sudo mv -v kube-scheduler.service /etc/systemd/system/kube-scheduler.service

  # Run service
  ssh "${user}@${ip}" sudo systemctl daemon-reload
  ssh "${user}@${ip}" sudo systemctl enable kube-scheduler
  ssh "${user}@${ip}" sudo systemctl restart kube-scheduler
done
