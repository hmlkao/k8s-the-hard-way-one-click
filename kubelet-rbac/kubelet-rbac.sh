#!/usr/bin/env bash
#
# Configure RBAC permissions to allow K8s API server to access
# Kubelet API on each worker node.
#
# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/08-bootstrapping-kubernetes-controllers.md#rbac-for-kubelet-authorization
#
set -euo pipefail

. ../config



# Crate cluster role
cat > cluster-role.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF
scp cluster-role.yaml "${user}@${extips[${controllers[0]}]}:/tmp/"
ssh "${user}@${extips[${controllers[0]}]}" kubectl apply --kubeconfig /opt/kubernetes/admin.kubeconfig -f /tmp/cluster-role.yaml



# Create Cluster role binding
cat > cluster-role-binding.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF
scp cluster-role-binding.yaml "${user}@${extips[${controllers[0]}]}:/tmp/"
ssh "${user}@${extips[${controllers[0]}]}" kubectl apply --kubeconfig /opt/kubernetes/admin.kubeconfig -f /tmp/cluster-role-binding.yaml
