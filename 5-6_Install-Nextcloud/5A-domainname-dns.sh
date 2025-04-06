#!/bin/bash

# SSH To the admin VM first
# Note the IP of the admin machine

ADMIN_VM_IP=$(cat ADMIN_VM_IP.txt)
# ssh -i id_rsa ubuntu@$ADMIN_VM_IP

########## Prep for Nextcloud Install and DNS Setup ###########

# Step 5A.0 Commit to a resolvable local (or external) domain name

# Define a domain name for your soon to be nextcloud instance suffix, ie nextcloud.yourexampledomain.com
# NOTE Currently .local domain suffixes are not supported
# This DOES NOT have to be a publicly facing fqdn. It can work completely internal.
# NOTE DO NOT USE QUOTES "" when assigning DOMAINNAME

DOMAINNAME=yourexampledomain.com

# Note, the IP of the ingress will be revealed in Script 5B
# You will need to make nextcloud.yourexampledomain.com be resolvable at least internally
# If you don't have a local DNS server, alternatively you can modify your hosts file
# Make the IP of your ingress setup (defined in script 5B) correlate to your domain

# Check if the domain contains .local
if [[ "$DOMAINNAME" == *.local ]]; then
    echo "Your domain '$DOMAINNAME' contains '.local' in its suffix. Unfortunately .local domains are not supported."
	echo "Please use another suffix. However this DOES NOT have to be a publicly facing fqdn. It can work completely internal."
	echo ""
	echo "Exiting script...use nano to edit DOMAINNAME in script then execute again"
	exit 1
fi

read -p "Do you want to use the DOMAINNAME $DOMAINNAME for your nextcloud instance? | nextcloud.$DOMAINNAME (yes/no): " user_input
user_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')

# Check if the user entered 'yes' or 'y'
if [[ "$user_input" == "yes" || "$user_input" == "y" ]]; then
    echo "DOMAINNAME $DOMAINNAME will be used. | nextcloud.$DOMAINNAME | Continuing with next script section..."
else
	 echo "Exiting script...use nano to edit DOMAINNAME in script then execute again"
     exit 1
fi

# Step 5A.1 Getting IP Range information

# Retrieve the lbrange value from Script 3
lbrange=$(grep -oP 'lbrange=\K[^\n]+' ./3-install-k3s-from-JimsGarage.sh)

# Extract the beginning value before the '-'
lbrange_start=$(echo "$lbrange" | cut -d'-' -f1)

# Extract the last octet and add 2
last_octet=$(echo "$lbrange_start" | awk -F'.' '{print $4}')

subnet=$(echo "$lbrange_start" | awk -F'.' '{print $1"."$2"."$3}')

# increment last_octet
rancherip="${subnet}.$((last_octet + 1))"
nextcloudip="${subnet}.$((last_octet + 2))"

# Replace the last octet with the updated value

sleep 1
echo ""
echo "Your load balancer range starts at $lbrange_start"
echo ""
echo "This means that your nginx initial HelloWorld page is at $lbrange_start"
echo "This also means that your Rancher IP is at the next IP at $rancherip"
echo ""
echo "With this information, your nextcloud instance should be at the next IP at $nextcloudip"
echo ""
echo "We need to make nextcloud.$DOMAINNAME resolvable to your new IP $nextcloudip"
echo "If you don't have a DNS server on-premise, we can make your ubuntu-admin-vm into a lightweight DNS server"
echo ""

# Step 5A.2 DNS Server Setup

read -p "Pick YES to make the admin VM a local DNS server. NO assumes you will handle DNS elsewhere. (yes/no): " user_input
user_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')

# Check if the user entered 'yes' or 'y'
if [[ "$user_input" == "yes" || "$user_input" == "y" ]]; then
    echo ""
    echo "Installing dnsmasq on your ubuntu-admin-vm"

	# Step 5A.3 Install dnsmasq

	echo "DNSStubListener=no
	DNS=127.0.0.1
	FallbackDNS=8.8.8.8" | sudo tee -a /etc/systemd/resolved.conf /dev/null

	sudo systemctl restart systemd-resolved

	apt update > /dev/null 2>&1
	sudo apt install dnsmasq -y

	echo "server=127.0.0.53
	address=/nextcloud.$DOMAINNAME/$nextcloudip
	interface=eth0
	bind-interfaces" | sudo tee -a /etc/dnsmasq.conf > /dev/null

	sudo systemctl restart dnsmasq
	sudo systemctl restart systemd-resolved
	
    # Step 5A.4 Test the DNS resolution:
	sleep 2
	clear

	echo ""
	echo "Manually set your DNS server on your device to the IP of the Admin VM, $ADMIN_VM_IP"
	echo "Then run the command on your laptop (or any device) to test: nslookup nextcloud.$DOMAINNAME"
	echo ""
	echo "You should see $nextcloudip as the resolved IP address for nextcloud.$DOMAINNAME."
	echo "Again, make sure your DNS is manually set on your computer, ie $ADMIN_VM_IP and 8.8.8.8 as secondary"
	echo ""

	else
     	echo "You chose not to make the Admin VM a local DNS server."
     	echo "This means DNS will be handled elsewhere such as another DNS server or editing hosts files"
	fi

echo ""
echo "Confirm nextcloud.$DOMAINNAME is resolvable to IP $nextcloudip on devices that you will access your nextcloud instance."
echo ""

# Step 5A.5 If Longhogn was not manually installed after running Script 4, this will install it. This is a prerequisite for Script 6.

# Check if the namespace longhorn-system exists
kubectl get namespace longhorn-system &>/dev/null

# If the namespace doesn't exist, run the helm upgrade command
if [ $? -ne 0 ]; then
    echo "Namespace 'longhorn-system' does not exist. Installing Longhorn..."
	helm repo add longhorn https://charts.longhorn.io
    helm repo update
    helm fetch longhorn/longhorn --version 1.8.1 --untar --untardir ~/longhorn/
    cd longhorn
	cd longhorn

	    helm upgrade --install longhorn ~/longhorn/longhorn \
        --namespace=longhorn-system --timeout=10m0s \
        --values=values.yaml \
        --version=1.8.1 --wait=true \
        --labels=catalog.cattle.io/cluster-repo-name=rancher-charts
    
	echo ""
    cd ..
	cd ..
fi

echo "" 
echo "Next continue on to script 5B to test install nextcloud by running ./5B-optional-test-nextcloud-install.sh"


