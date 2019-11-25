#!/usr/bin/env bash
#
# Crate and distribute kubeconfigs to all nodes
#
set -euo pipefail
cert_dir=../pki

. ../config

# Generated kubelet configuration file
mkdir -p kubelet
for instance in "${workers[@]}"; do
  kubectl config set-cluster khw \
    --certificate-authority="$cert_dir/k8s-ca/ca.pem" \
    --embed-certs=true \
    --server="https://${kubeapi_ip}:6443" \
    --kubeconfig="kubelet/${instance}.kubeconfig"

  kubectl config set-credentials "system:node:${instance}" \
    --client-certificate="$cert_dir/k8s-client-${instance}/${instance}.pem" \
    --client-key="$cert_dir/k8s-client-${instance}/${instance}-key.pem" \
    --embed-certs=true \
    --kubeconfig="kubelet/${instance}.kubeconfig"

  kubectl config set-context default \
    --cluster=khw \
    --user="system:node:${instance}" \
    --kubeconfig="kubelet/${instance}.kubeconfig"

  kubectl config use-context default \
    --kubeconfig="kubelet/${instance}.kubeconfig"
done



# Generate kube-proxy config
mkdir -p kube-proxy
kubectl config set-cluster khw \
  --certificate-authority="$cert_dir/k8s-ca/ca.pem" \
  --embed-certs=true \
  --server="https://${kubeapi_ip}:6443" \
  --kubeconfig=kube-proxy/kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate="$cert_dir/k8s-client-proxy/kube-proxy.pem" \
  --client-key="$cert_dir/k8s-client-proxy/kube-proxy-key.pem" \
  --embed-certs=true \
  --kubeconfig=kube-proxy/kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=khw \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy/kube-proxy.kubeconfig

kubectl config use-context default \
  --kubeconfig=kube-proxy/kube-proxy.kubeconfig



# Generate kube controller manager config
mkdir -p kube-cm
kubectl config set-cluster khw \
  --certificate-authority="$cert_dir/k8s-ca/ca.pem" \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-cm/kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate="$cert_dir/k8s-client-cm/kube-controller-manager.pem" \
  --client-key="$cert_dir/k8s-client-cm/kube-controller-manager-key.pem" \
  --embed-certs=true \
  --kubeconfig=kube-cm/kube-controller-manager.kubeconfig

kubectl config set-context default \
  --cluster=khw \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-cm/kube-controller-manager.kubeconfig

kubectl config use-context default \
  --kubeconfig=kube-cm/kube-controller-manager.kubeconfig



# Generate kube scheduler config
mkdir -p kube-scheduler
kubectl config set-cluster khw \
  --certificate-authority="$cert_dir/k8s-ca/ca.pem" \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-scheduler/kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate="$cert_dir/k8s-client-ks/kube-scheduler.pem" \
  --client-key="$cert_dir/k8s-client-ks/kube-scheduler-key.pem" \
  --embed-certs=true \
  --kubeconfig=kube-scheduler/kube-scheduler.kubeconfig

kubectl config set-context default \
  --cluster=khw \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler/kube-scheduler.kubeconfig

kubectl config use-context default \
  --kubeconfig=kube-scheduler/kube-scheduler.kubeconfig



# Generate config for admin user
mkdir -p kube-admin
kubectl config set-cluster khw \
  --certificate-authority="$cert_dir/k8s-ca/ca.pem" \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-admin/admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate="$cert_dir/k8s-client-admin/admin.pem" \
  --client-key="$cert_dir/k8s-client-admin/admin-key.pem" \
  --embed-certs=true \
  --kubeconfig=kube-admin/admin.kubeconfig

kubectl config set-context default \
  --cluster=khw \
  --user=admin \
  --kubeconfig=kube-admin/admin.kubeconfig

kubectl config use-context default \
  --kubeconfig=kube-admin/admin.kubeconfig



######################## DISTRIBUTE CONFIGS ##########################

# Deploy certs to workers
for instance in "${workers[@]}"; do
  ip=${intips[$instance]}
  ssh "${user}@${ip}" sudo mkdir -p /opt/kubernetes
  scp \
    "kubelet/${instance}.kubeconfig" \
    "kube-proxy/kube-proxy.kubeconfig" \
    "${user}@${ip}:~/"
  ssh "${user}@${ip}" "sudo mv -v *.kubeconfig /opt/kubernetes/"
done



# Deploy certs to controllers
for instance in "${controllers[@]}"; do
  ip=${intips[$instance]}
  ssh "${user}@${ip}" sudo mkdir -p /opt/kubernetes
  scp \
    "kube-admin/admin.kubeconfig" \
    "kube-scheduler/kube-scheduler.kubeconfig" \
    "kube-cm/kube-controller-manager.kubeconfig" \
    "${user}@${ip}:~/"
  ssh "${user}@${ip}" "sudo mv -v *.kubeconfig /opt/kubernetes/"
done
