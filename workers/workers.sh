#!/usr/bin/env bash
#
# Bootstrap Kubernetes worker nodes
#
# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/09-bootstrapping-kubernetes-workers.md#bootstrapping-the-kubernetes-worker-nodes
#
set -euo pipefail

. ../config

crictl_version=1.16.1
cni_version=0.3.1
cni_plugins_version=0.8.3
runc_version=1.0.0-rc9
containerd_version=1.3.1

# Provision worker nodes
for instance in "${workers[@]}"; do
  # Install required packages
  ssh "${user}@${intips[${instance}]}" sudo apt update
  ssh "${user}@${intips[${instance}]}" sudo apt -Vy install socat conntrack ipset

  # Disable swap
  ssh "${user}@${intips[${instance}]}" sudo swapoff -a
done

################ CNI Networking ##################

i=0
for instance in "${workers[@]}"; do
  ip="${intips[$instance]}"
  pod_cidr="10.200.${i}.0/24"

  # Download CNI plugins
  ssh "${user}@${ip}" wget -q --https-only --timestamping \
    "https://github.com/containernetworking/plugins/releases/download/v${cni_plugins_version}/cni-plugins-linux-amd64-v${cni_plugins_version}.tgz"
  ssh "${user}@${ip}" sudo mkdir -pv /opt/cni/bin
  ssh "${user}@${ip}" sudo tar -xvf "cni-plugins-linux-amd64-v${cni_plugins_version}.tgz" -C /opt/cni/bin/
  ssh "${user}@${ip}" rm -v "cni-plugins-linux-amd64-v${cni_plugins_version}.tgz"

  # Download CNI binaries
  ssh "${user}@${ip}" wget -q --https-only --timestamping \
    "https://github.com/kubernetes-sigs/cri-tools/releases/download/v${crictl_version}/crictl-v${crictl_version}-linux-amd64.tar.gz"
  ssh "${user}@${ip}" tar -xvf "crictl-v${crictl_version}-linux-amd64.tar.gz"
  ssh "${user}@${ip}" rm -v "crictl-v${crictl_version}-linux-amd64.tar.gz"
  ssh "${user}@${ip}" chmod +x crictl
  ssh "${user}@${ip}" sudo mv -v crictl /usr/local/bin/

  # Create CNI config
  cat > 10-bridge.conf <<EOF
{
    "cniVersion": "${cni_version}",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${pod_cidr}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF
  scp 10-bridge.conf "${user}@${ip}:."
  rm 10-bridge.conf
  ssh "${user}@${ip}" sudo mkdir -pv /etc/cni/net.d
  ssh "${user}@${ip}" sudo mv -v 10-bridge.conf /etc/cni/net.d/

  # Create loopback
  cat > 99-loopback.conf <<EOF
{
    "cniVersion": "${cni_version}",
    "name": "lo",
    "type": "loopback"
}
EOF
  scp 99-loopback.conf "${user}@${ip}:."
  rm 99-loopback.conf
  ssh "${user}@${ip}" sudo mkdir -pv /etc/cni/net.d
  ssh "${user}@${ip}" sudo mv -v 99-loopback.conf /etc/cni/net.d/

  # Increment instance ID
  i=$((i + 1))
done

############### Runc ###############

for instance in "${workers[@]}"; do
  ip="${intips[$instance]}"

  # Download binaries
  ssh "${user}@${ip}" wget -q --https-only --timestamping \
    "https://github.com/opencontainers/runc/releases/download/v${runc_version}/runc.amd64"
  ssh "${user}@${ip}" sudo mv -v runc.amd64 /usr/local/bin/runc
done

############### Containerd ################

for instance in "${workers[@]}"; do
  ip="${intips[$instance]}"

  # Download binaries
  ssh "${user}@${ip}" wget -q --https-only --timestamping \
    "https://github.com/containerd/containerd/releases/download/v${containerd_version}/containerd-${containerd_version}.linux-amd64.tar.gz"
  ssh "${user}@${ip}" mkdir -pv containerd
  ssh "${user}@${ip}" tar -xvf "containerd-${containerd_version}.linux-amd64.tar.gz" -C containerd
  ssh "${user}@${ip}" rm -v "containerd-${containerd_version}.linux-amd64.tar.gz"
  ssh "${user}@${ip}" sudo mv -v containerd/bin/* /usr/local/bin/
  ssh "${user}@${ip}" sudo rm -rfv containerd

  # Create config
  ssh "${user}@${ip}" sudo mkdir -p /etc/containerd/
  cat > containerd-config.toml << EOF
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
EOF
  scp containerd-config.toml "${user}@${ip}:config.toml"
  rm containerd-config.toml
  ssh "${user}@${ip}" sudo mv -v config.toml /etc/containerd/

  # Create service
  cat > containerd.service <<EOF
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF
  scp containerd.service "${user}@${ip}:."
  rm containerd.service
  ssh "${user}@${ip}" sudo mv -v containerd.service /etc/systemd/system/

  # Run service
  ssh "${user}@${ip}" sudo systemctl daemon-reload
  ssh "${user}@${ip}" sudo systemctl enable containerd
  ssh "${user}@${ip}" sudo systemctl restart containerd
done

############### Kubelet ################

i=0
for instance in "${workers[@]}"; do
  ip="${intips[$instance]}"
  pod_cidr="10.200.${i}.0/24"

  # Download binaries
  ssh "${user}@${ip}" wget -q --https-only --timestamping \
    "https://storage.googleapis.com/kubernetes-release/release/v${k8s_ver}/bin/linux/amd64/kubelet"
  ssh "${user}@${ip}" chmod +x kubelet
  ssh "${user}@${ip}" sudo mv -v kubelet /usr/local/bin/

  # Create config
  cat > kubelet.yaml <<EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/opt/kubernetes/pki/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${pod_cidr}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/opt/kubernetes/pki/${instance}.pem"
tlsPrivateKeyFile: "/opt/kubernetes/pki/${instance}-key.pem"
EOF
  scp kubelet.yaml "${user}@${ip}:."
  rm kubelet.yaml
  ssh "${user}@${ip}" sudo mkdir -pv /opt/kubernetes/config/
  ssh "${user}@${ip}" sudo mv -v kubelet.yaml /opt/kubernetes/config/

  # Create service
  cat > kubelet.service <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/opt/kubernetes/config/kubelet.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/opt/kubernetes/${instance}.kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  scp kubelet.service "${user}@${ip}:."
  rm kubelet.service
  ssh "${user}@${ip}" sudo mv -v kubelet.service /etc/systemd/system/

  # Run service
  ssh "${user}@${ip}" sudo systemctl daemon-reload
  ssh "${user}@${ip}" sudo systemctl enable kubelet
  ssh "${user}@${ip}" sudo systemctl restart kubelet

  # Increment instance ID
  i=$((i + 1))
done

############### Kube-proxy ################

for instance in "${workers[@]}"; do
  ip="${intips[$instance]}"

  # Download binaries
  ssh "${user}@${ip}" wget -q --https-only --timestamping \
    "https://storage.googleapis.com/kubernetes-release/release/v${k8s_ver}/bin/linux/amd64/kube-proxy"
  ssh "${user}@${ip}" chmod +x kube-proxy
  ssh "${user}@${ip}" sudo mv -v kube-proxy /usr/local/bin/

  # Create config
  cat > kube-proxy.yaml <<EOF
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/opt/kubernetes/kube-proxy.kubeconfig"
mode: "iptables"
clusterCIDR: "${cluster_cidr}"
EOF
  scp kube-proxy.yaml "${user}@${ip}:."
  rm kube-proxy.yaml
  ssh "${user}@${ip}" sudo mkdir -pv /opt/kubernetes/config/
  ssh "${user}@${ip}" sudo mv -v kube-proxy.yaml /opt/kubernetes/config/

  # Create service
  cat > kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/opt/kubernetes/config/kube-proxy.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  scp kube-proxy.service "${user}@${ip}:."
  rm kube-proxy.service
  ssh "${user}@${ip}" sudo mv -v kube-proxy.service /etc/systemd/system/

  # Run service
  ssh "${user}@${ip}" sudo systemctl daemon-reload
  ssh "${user}@${ip}" sudo systemctl enable kube-proxy
  ssh "${user}@${ip}" sudo systemctl restart kube-proxy
done

############### Kubectl ################

for instance in "${workers[@]}"; do
  ip="${intips[$instance]}"

  ssh "${user}@${ip}" wget -q --https-only --timestamping \
    "https://storage.googleapis.com/kubernetes-release/release/v${k8s_ver}/bin/linux/amd64/kubectl"

  ssh "${user}@${ip}" chmod +x kubectl
  ssh "${user}@${ip}" sudo mv -v kubectl /usr/local/bin/
done
