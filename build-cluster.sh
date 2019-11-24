#!/usr/bin/env bash
set -euo pipefail
IFS=$'/n/t'

# Create infrastructure
# (
#   cd terraform
#   terraform apply
# )

# Create certificates for all components
# (
#   cd pki
#   ./gencert.sh
# )

# Create kubeconfigs for all components
# (
#   cd kubeconfigs
#   ./genconfigs.sh
# )

# Create
# (
#   cd encconfig
#   ./genenc.sh
# )

# Bootstrap ETCD
# (
#   cd etcd
#   ./boot-etcd.sh
# )

# Bootstrap control plane components
# (
#   cd control-plane
#   ./control-plane.sh
# )

# Make operational healtz check
# (
#   cd health-check
#   ./health-check.sh
# )

# RBAC for Kubelet Authorization
# (
#   cd kubelet-rbac
#   ./kubelet-rbac.sh
# )

# Bootstrap worker components
# (
#   cd workers
#   ./workers.sh
# )

# Generate kubeconfig file
. config

export KUBECONFIG=./kubeconfig
kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=pki/k8s-ca/ca.pem \
    --embed-certs=true \
    --server=https://${kubeapi_ip}:6443
kubectl config set-credentials ondra \
    --client-certificate=pki/k8s-client-ondra/ondra.pem \
    --client-key=pki/k8s-client-ondra/ondra-key.pem
kubectl config set-context kubernetes-the-hard-way \
    --cluster=kubernetes-the-hard-way \
    --user=ondra
kubectl config use-context kubernetes-the-hard-way
