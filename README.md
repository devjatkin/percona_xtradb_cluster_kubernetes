## Percona XtraDB Replication for MySQL on Kubernetes

This repository contains a demonstration example of running Percona XtraDB cluster.

### Basic concept

The main idea is using Kubernetes configmap during bootstrap Galera cluster.

### QUICK START
Into project cloud.google.com console run 


          $ kubectl create -f pxc-cluster.yml

          $ kubectl cluster-info

### REQUIREMENTS
Setting up kubectl.
The following steps should be done from a local workstation to configure kubectl to work with a new cluster.

https://coreos.com/kubernetes/docs/latest/configure-kubectl.html

### INSTALLATION

          $ docker build -t your/image .

or

          $ docker build -t gcr.io/<your-project-id>/image .

          $ gcloud docker push gcr.io/<your-project-id>/image

          $ kubectl create -f pxc-cluster.yml
          
          $ kubectl cluster-info

