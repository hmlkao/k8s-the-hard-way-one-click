K8s The Hard Way One click
==========================
Based on Kelsey's [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)

Script doesn't solve the infrastructure. You can use terraform or whatever you want to build some. Simple example is in [terraform](/terraform) folder.

Script run all parts which deploy the whole cluster from scratch part by part.

Naming convention
-----------------
**Controller == Control node == Master node** Node labeled as master with running `kube-apiserver` and other K8s control plane components

Configuration
-------------
Check [config.example](/config.example) file.

Usage
-----
```bash
git clone git@github.com:hmlkao/k8s-the-hard-way-one-click.git
cd k8s-the-hard-way-one-click
./build-cluster.sh
```
