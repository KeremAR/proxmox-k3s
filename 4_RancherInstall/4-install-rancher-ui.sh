#!/bin/bash

# Note all of these commands should be done from the admin machine"
# SSH To the admin VM first
# Note the IP of the admin machine

# ADMIN_VM_IP=$(head -n 1 VM_IPs.txt | cut -d '=' -f2 | xargs)
# ssh -i id_rsa ubuntu@$ADMIN_VM_IP

echo "########## Rancher UI Install ###########"

sleep 1

echo ""
echo "Plan to define a domain name for your rancher instance suffix, ie rancher.yourexampledomain.com"
echo "This does not have to be a publicly facing fqdn."
echo "NOTE Currently .local domain suffixes are not supported"
echo ""

sleep 4

echo "This is not crucial for the rancher install as it will be accessed via a loadbalancer IP on your LAN."
echo "However, in later steps when using an Ingress setup with instances in a k3s cluster such as Nextcloud, having a resolvable domain name is crucial"
echo ""

sleep 5


# Step 4.0 Define domain
###########################################################
# NOTE DO NOT USE QUOTES "" when assigning DOMAINNAME

DOMAINNAME=yourexampledomain.com

##########################################################


read -p "Do you want to use the DOMAINNAME $DOMAINNAME for your Rancher UI instance | rancher.$DOMAINNAME ? (yes/no): " user_input
user_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')

# Check if the user entered 'yes' or 'y'
if [[ "$user_input" == "yes" || "$user_input" == "y" ]]; then
    echo "DOMAINNAME $DOMAINNAME will be used. | rancher.$DOMAINNAME | Continuing with next script section..."
else
     echo "Exiting script...use nano to edit DOMAINNAME in script then execute again"
     exit 1
fi

# Step 4.1 Getting IP Range information

# Retrieve the lbrange value from Script 3
lbrange=$(grep -oP 'lbrange=\K[^\n]+' ./3-install-k3s-from-JimsGarage.sh)

# Extract the beginning value before the '-'
lbrange_start=$(echo "$lbrange" | cut -d'-' -f1)

# Extract the last octet and add 2
last_octet=$(echo "$lbrange_start" | awk -F'.' '{print $4}')

subnet=$(echo "$lbrange_start" | awk -F'.' '{print $1"."$2"."$3}')

# increment last_octet
rancherip="${subnet}.$((last_octet + 1))"

# Notify user

echo ""
echo "Your load balancer range starts at $lbrange_start"
echo ""
echo "This also means your Nginx initial 'HelloWorld' page is at $lbrange_start"
echo "Therefore your Rancher IP will be deploy at the next IP at $rancherip"
echo ""

sleep 5

# Step 4.2 Helm Install and Rancher initial setup
 curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
 
 chmod 700 get_helm.sh
 ./get_helm.sh

helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
kubectl create namespace cattle-system

# If you have installed the CRDs manually, instead of setting `installCRDs` or `crds.enabled` to `true` in your Helm install command, you should upgrade your CRD resources before upgrading the Helm chart:
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.3/cert-manager.crds.yaml

# Step 4.3 Install cert manager

# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Next delete these entries
kubectl delete crd certificaterequests.cert-manager.io
kubectl delete crd certificates.cert-manager.io
kubectl delete crd challenges.acme.cert-manager.io
kubectl delete crd issuers.cert-manager.io
kubectl delete crd orders.acme.cert-manager.io
kubectl delete crd clusterissuers.cert-manager.io

echo ""
echo "Waiting for cert manager installation to be available..."
echo "Please wait..."
echo ""

# Confirm existing entries are empty
kubectl get crds | grep cert-manager

# Install the cert-manager Helm chart
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true
  
 # Confirm the cert manager is now there
kubectl get pods --namespace cert-manager
 

#Step 4.4 install and deploy rancher

 # install helm rancher to the given namespace below
helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=rancher."$DOMAINNAME" \
  --set bootstrapPassword=admin

 echo ""
 echo "Deploying the rancher system to the vm/nodes...It will stay on step 0 for a while. This may take about 5 minutes..."

 kubectl -n cattle-system rollout status deploy/rancher

# Check if deployment worked
kubectl -n cattle-system get deploy rancher
 
# Expose/connect system to load balancer
kubectl expose deployment rancher --name=rancher-lb --port=443 --type=LoadBalancer -n cattle-system


# Step 4.5 Install traefik for ingress

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

helm repo add traefik https://traefik.github.io/charts
helm repo update

echo ""
echo "Now installing traefik for ingress..."
echo ""

helm install traefik traefik/traefik --namespace kube-system --create-namespace

kubectl get pods -n kube-system

# Step 4.6 Install Longhorn for persistent storage management

echo ""
echo "Creating Namespace 'longhorn-system' and gathering Longhorn installation..."

kubectl create namespace longhorn-system
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm fetch longhorn/longhorn --version 1.8.1 --untar --untardir ~/longhorn/

echo ""
echo "Installing Longhorn. This part also takes a few minutes. Please wait..."
echo ""
    
helm upgrade --install longhorn ~/longhorn/longhorn \
  --namespace=longhorn-system --timeout=10m0s \
  --values=/home/ubuntu/longhorn/longhorn/values.yaml \
  --version=1.8.1 --wait=true \
  --labels=catalog.cattle.io/cluster-repo-name=rancher-charts
  
# Step 4.7 Then after longhorn installed, mark test-k3s-04 and test-k3s-05 as non-schedule-able nodes in longhorn

echo "Marking test-k3s-04 and test-k3s-05 as non-storage nodes in longhorn..."
echo ""

kubectl label nodes test-k3s-04 longhorn.storage/disable=true
kubectl label nodes test-k3s-05 longhorn.storage/disable=true

kubectl label nodes test-k3s-04 longhorn.io/disable-scheduling=true
kubectl label nodes test-k3s-05 longhorn.io/disable-scheduling=true

kubectl get nodes --show-labels

# Finishing up. Command to get load balancer connection information
kubectl get svc -n cattle-system

echo ""
echo "Log in to the new load balancer (External-IP to k3s) $rancherip in your browser."
echo "In the next script, we'll address DNS to access it by name."
echo ""
echo "Use admin as your default bootstrap password."
echo ""
echo "NOTE, SAVE your generated rancher password from rancher UI on your computer!!"
echo ""
echo "Next continue on to Script 5A."