#!/usr/bin/env bash

. ../config

#################### CERTIFICATES ########################

# Generate config for cfssl
cat > ca-config.json <<EOF
{
    "signing": {
        "default": {
            "expiry": "8760h"
        },
        "profiles": {
            "kubernetes": {
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ],
                "expiry": "8760h"
            }
        }
    }
}
EOF



# Generate k8s CA cert
mkdir -p k8s-ca
cat > k8s-ca/ca-csr.json <<EOF
{
  "CN": "Ondruv K8s",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF
cfssl gencert -initca k8s-ca/ca-csr.json | cfssljson -bare k8s-ca/ca



# Generate k8s client cert for 'admin' user
mkdir -p k8s-client-admin
cat > k8s-client-admin/admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:masters"
    }
  ]
}
EOF
cfssl gencert -ca=k8s-ca/ca.pem -ca-key=k8s-ca/ca-key.pem -config=ca-config.json -profile=kubernetes k8s-client-admin/admin-csr.json | cfssljson -bare k8s-client-admin/admin



# Generate k8s client cert for 'ondra' user
mkdir -p k8s-client-ondra
cat > k8s-client-ondra/ondra-csr.json <<EOF
{
  "CN": "ondra",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:masters"
    }
  ]
}
EOF
cfssl gencert -ca=k8s-ca/ca.pem -ca-key=k8s-ca/ca-key.pem -config=ca-config.json -profile=kubernetes k8s-client-ondra/ondra-csr.json | cfssljson -bare k8s-client-ondra/ondra



# Generate kubelet certs for each node
for instance in "${workers[@]}"; do
  mkdir -p "k8s-client-${instance}"
  dc=$(echo "$instance" | cut -d'-' -f3)

  cat > "k8s-client-${instance}/${instance}-csr.json" <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:nodes"
    }
  ]
}
EOF

  cfssl gencert \
    -ca=k8s-ca/ca.pem \
    -ca-key=k8s-ca/ca-key.pem \
    -config=ca-config.json \
    -hostname="${instance},${instance}.ohomolka.os${dc}.mall.local,${intips[$instance]}" \
    -profile=kubernetes \
    "k8s-client-${instance}/${instance}-csr.json" | cfssljson -bare "k8s-client-${instance}/${instance}"
done



# Generate Controller Manager cert
mkdir -p "k8s-client-cm"
cat > k8s-client-cm/kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:kube-controller-manager"
    }
  ]
}
EOF

cfssl gencert \
  -ca=k8s-ca/ca.pem \
  -ca-key=k8s-ca/ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  k8s-client-cm/kube-controller-manager-csr.json | cfssljson -bare k8s-client-cm/kube-controller-manager



# Generate Kube Proxy cert
mkdir -p "k8s-client-proxy"
cat > k8s-client-proxy/kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:node-proxier"
    }
  ]
}
EOF

cfssl gencert \
  -ca=k8s-ca/ca.pem \
  -ca-key=k8s-ca/ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  k8s-client-proxy/kube-proxy-csr.json | cfssljson -bare k8s-client-proxy/kube-proxy



# Generate Kube Scheduler cert
mkdir -p k8s-client-ks
cat > k8s-client-ks/kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:kube-scheduler"
    }
  ]
}
EOF

cfssl gencert \
  -ca=k8s-ca/ca.pem \
  -ca-key=k8s-ca/ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  k8s-client-ks/kube-scheduler-csr.json | cfssljson -bare k8s-client-ks/kube-scheduler



# Generate Kube API server cert
kube_api_ip=
k8s_hostnames=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

mkdir -p k8s-server
cat > k8s-server/k8s-server-csr.json <<EOF
{
  "CN": "Ondruv K8s API server",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF

for instance in "${controllers[@]}"; do
  ips+=("${intips[$instance]}")
  cluster_ips=$(IFS=","; echo "${ips[*]}")
done

cfssl gencert \
  -ca=k8s-ca/ca.pem \
  -ca-key=k8s-ca/ca-key.pem \
  -config=ca-config.json \
  -hostname="${cluster_ips},${kube_api_ip},127.0.0.1,${k8s_hostnames}" \
  -profile=kubernetes \
  k8s-server/k8s-server-csr.json | cfssljson -bare k8s-server/api-server



# Generate Service account cert
mkdir -p k8s-client-sa
cat > k8s-client-sa/service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF

cfssl gencert \
  -ca=k8s-ca/ca.pem \
  -ca-key=k8s-ca/ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  k8s-client-sa/service-account-csr.json | cfssljson -bare k8s-client-sa/service-account



######################### CERTS DEPLOY ##############################

# Deploy certs to workers
for instance in "${workers[@]}"; do
  ip=${intips[$instance]}
  ssh "${user}@${ip}" sudo mkdir -p /opt/kubernetes/pki
  scp \
    "k8s-ca/ca.pem" \
    "k8s-client-${instance}/${instance}.pem" \
    "k8s-client-${instance}/${instance}-key.pem" \
    "${user}@${ip}:~/"
  ssh "${user}@${ip}" "sudo mv *.pem /opt/kubernetes/pki/"
done



# Deploy certs to controllers
for instance in "${controllers[@]}"; do
  ip="${intips[$instance]}"
  ssh "${user}@${ip}" sudo mkdir -p /opt/kubernetes/pki
  scp \
    "k8s-ca/ca.pem" \
    "k8s-ca/ca-key.pem" \
    "k8s-server/api-server.pem" \
    "k8s-server/api-server-key.pem" \
    "k8s-client-sa/service-account.pem" \
    "k8s-client-sa/service-account-key.pem" \
    "${user}@${ip}:~/"
  ssh "${user}@${ip}" "sudo mv *.pem /opt/kubernetes/pki/"
done
