#!/bin/bash

########## Rancher UI Install ##########


# Define a domain name for your rancher instance suffix, ie rancher.example.com or rancher.example.local
# This does not have to be a publicly facing fqdn.
# In my case I have a local fqdn with on-premise DNS for a .com local suffix domain
# This is not crucial for rancher install as it will be accessed via loadbalancer IP.
# However, in later steps when installing instances within a k3s cluster such as nextcloud, having a resolvable domain name is crucial

DOMAINNAME="ne-inc.com"

# Step 4.1 Note all of these commands should be done from the admin machine

# SSH To the admin VM first
# Note the IP of the admin machine

# ADMIN_VM_IP="192.168.100.6"
# ssh -i id_rsa ubuntu@$ADMIN_VM_IP

#Helm Install

 curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
 
 chmod 700 get_helm.sh
 ./get_helm.sh

# Rancher initial setup
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest

kubectl create namespace cattle-system

# If you have installed the CRDs manually, instead of setting `installCRDs` or `crds.enabled` to `true` in your Helm install command, you should upgrade your CRD resources before upgrading the Helm chart:
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.3/cert-manager.crds.yaml

# Step 4.2 add and install cert manager

# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io

# Update your local Helm chart repository cache
helm repo update

# Next delete these entries
kubectl delete crd certificaterequests.cert-manager.io
kubectl delete crd certificates.cert-manager.io
kubectl delete crd clusters.cert-manager.io
kubectl delete crd challenges.cert-manager.io
kubectl delete crd orders.cert-manager.io
kubectl delete crd challenges.acme.cert-manager.io
kubectl delete crd issuers.cert-manager.io
kubectl delete crd orders.acme.cert-manager.io
kubectl delete crd clusterissuers.cert-manager.io

# Confirm existing entries are empty
kubectl get crds | grep cert-manager

# Install the cert-manager Helm chart
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true
  
 # Confirm the cert manager is now there
kubectl get pods --namespace cert-manager
 

Step 4.3 install and deploy rancher

 # install helm rancher to the given namespace below
helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=rancher."$DOMAINNAME" \
  --set bootstrapPassword=admin

 # deploy the rancher system to the vm/nodes, this may take 10 min
 kubectl -n cattle-system rollout status deploy/rancher

# Check if deployment worked
kubectl -n cattle-system get deploy rancher
 
# Expose/connect system to load balancer
kubectl expose deployment rancher --name=rancher-lb --port=443 --type=LoadBalancer -n cattle-system

# Added in delay to give load balancer a chance to start
sleep 30

# Command to see if the load balancer connection worked
kubectl get svc -n cattle-system

echo "Log in to the new IP load balancer in your browser"
echo ""
echo "NOTE, SAVE your generated rancher password from rancher UI on your computer!!"
