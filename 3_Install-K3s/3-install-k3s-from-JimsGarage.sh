#!/bin/bash

# SSH To the admin VM first
# Note the IP of the admin machine

ADMIN_VM_IP=$(head -n 1 VM_IPs.txt | cut -d '=' -f2 | xargs)
# ssh -i id_rsa ubuntu@$ADMIN_VM_IP

# Courtesy of James Turland
# https://github.com/JamesTurland/JimsGarage/blob/main/Kubernetes/K3S-Deploy/k3s.sh
# https://github.com/JamesTurland
# Script modified to have Longhorn storage nodes


echo -e " \033[33;5m    __  _          _        ___                            \033[0m"
echo -e " \033[33;5m    \ \(_)_ __ ___( )__    / _ \__ _ _ __ __ _  __ _  ___  \033[0m"
echo -e " \033[33;5m     \ \ | '_ \` _ \/ __|  / /_\/ _\` | '__/ _\` |/ _\` |/ _ \ \033[0m"
echo -e " \033[33;5m  /\_/ / | | | | | \__ \ / /_\\  (_| | | | (_| | (_| |  __/ \033[0m"
echo -e " \033[33;5m  \___/|_|_| |_| |_|___/ \____/\__,_|_|  \__,_|\__, |\___| \033[0m"
echo -e " \033[33;5m                                               |___/       \033[0m"

echo -e " \033[36;5m         _  _________   ___         _        _ _           \033[0m"
echo -e " \033[36;5m        | |/ |__ / __| |_ _|_ _  __| |_ __ _| | |          \033[0m"
echo -e " \033[36;5m        | ' < |_ \__ \  | || ' \(_-|  _/ _\` | | |          \033[0m"
echo -e " \033[36;5m        |_|\_|___|___/ |___|_||_/__/\__\__,_|_|_|          \033[0m"
echo -e " \033[36;5m                                                           \033[0m"
echo -e " \033[32;5m             https://youtube.com/@jims-garage              \033[0m"
echo -e " \033[32;5m                                                           \033[0m"


# Step 3.0A Define variables

#############################################
# YOU SHOULD ONLY NEED TO EDIT THIS SECTION #
#############################################

# Define the additional network parameters

# Loadbalancer IP range. MAKE SURE THIS RANGE IS AVAILABLE. The sites we'll deploy will be in this range.
# MODIFIED for your network (192.168.0.x)
lbrange=192.168.0.110-192.168.0.115

# Set the virtual IP address (VIP) - NOT NEEDED for single master setup, but keeping for script compatibility
# MODIFIED for your network  
vip=192.168.0.99

#############################################


# Step 3.0B Predefined default variables 

# IP Addresses extracted from Script 2D generated text file but defined in 2B
# Function to extract an IP from VM_IPs.txt based on variable name
extract_ip() {
  local var_name=$1
  grep "^$var_name" VM_IPs.txt | cut -d '=' -f2 | xargs
}

# Extract IPs - MODIFIED for 2 VM setup only
TEST_K3S_01_IP=$(extract_ip "TEST_K3S_01_IP")  # Master VM
TEST_K3S_02_IP=$(extract_ip "TEST_K3S_02_IP")  # Worker VM

# Removed unused IP extractions for non-existent VMs:
# TEST_K3S_03_IP, TEST_K3S_04_IP, TEST_K3S_05_IP
# TEST_LONGHORN01_IP, TEST_LONGHORN02_IP, TEST_LONGHORN03_IP

# MODIFIED for 2 VM setup:
# Single master node (VM 201) - runs K3s server + management tools
master1=$TEST_K3S_01_IP    # 192.168.0.101 (k3s-master)

# Single worker node (VM 202) - runs all workloads  
worker1=$TEST_K3S_02_IP    # 192.168.0.102 (k3s-worker)

# Removed additional masters and workers for minimal setup:
# master2, master3 (HA not needed)
# worker2, worker3, worker4, worker5 (Longhorn VMs removed)


# Version of Kube-VIP to deploy
KVVERSION="v0.6.3"

# K3S Version
k3sVersion="v1.26.10+k3s2"

# User of remote machines
user=ubuntu

# Interface used on remotes
interface=eth0

# MODIFIED arrays for 2 VM setup:

# Array of additional master nodes (empty for single master)
masters=()

# Array of worker nodes (only one worker)
workers1=($worker1)

# Array of all nodes (2 VMs total)
all=($master1 $worker1)

# Array of all nodes minus master1 (only worker nodes)
allnomaster1=($worker1)

#ssh certificate name variable
certName=id_rsa

#ssh config file
config_file=~/.ssh/config


# Step 3.0C prep admin machine before installation

# Move SSH certs to ~/.ssh and change permissions
cp /home/$user/{$certName,$certName.pub} /home/$user/.ssh
chmod 600 /home/$user/.ssh/$certName 
chmod 644 /home/$user/.ssh/$certName.pub

# Install k3sup to local machine if not already present
if ! command -v k3sup version &> /dev/null
then
    echo -e " \033[31;5mk3sup not found, installing\033[0m"
    curl -sLS https://get.k3sup.dev | sh
    sudo install k3sup /usr/local/bin/
else
    echo -e " \033[32;5mk3sup already installed\033[0m"
fi

# Install Kubectl if not already present
if ! command -v kubectl version &> /dev/null
then
    echo -e " \033[31;5mKubectl not found, installing\033[0m"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
else
    echo -e " \033[32;5mKubectl already installed\033[0m"
fi

# Step 3.0D Check for SSH config file, create if needed, add/change Strict Host Key Checking (don't use in production!)

if [ ! -f "$config_file" ]; then
  # Create the file and add the line
  echo "StrictHostKeyChecking no" > "$config_file"
  # Set permissions to read and write only for the owner
  chmod 600 "$config_file"
  echo "File created and line added."
else
  # Check if the line exists
  if grep -q "^StrictHostKeyChecking" "$config_file"; then
    # Check if the value is not "no"
    if ! grep -q "^StrictHostKeyChecking no" "$config_file"; then
      # Replace the existing line
      sed -i 's/^StrictHostKeyChecking.*/StrictHostKeyChecking no/' "$config_file"
      echo "Line updated."
    else
      echo "Line already set to 'no'."
    fi
  else
    # Add the line to the end of the file
    echo "StrictHostKeyChecking no" >> "$config_file"
    echo "Line added."
  fi
fi

# Step 3.0E Prep nodes by adding ssh keys for all nodes
for node in "${all[@]}"; do
  ssh-copy-id $user@$node
done

# Install policycoreutils for each node
for newnode in "${all[@]}"; do
  ssh $user@$newnode -i ~/.ssh/$certName sudo su <<EOF
  NEEDRESTART_MODE=a apt-get install policycoreutils -y
  exit
EOF
  echo -e " \033[32;5mPolicyCoreUtils installed!\033[0m"
done

# Step 3.1 install, Bootstrap First k3s Node
mkdir ~/.kube

# Step 3.1: Install K3s on single master node (SIMPLIFIED for single master setup)
echo -e " \033[33;5mInstalling K3s on single master node...\033[0m"
k3sup install \
  --ip $master1 \
  --user $user \
  --k3s-version $k3sVersion \
  --k3s-extra-args "--disable traefik --disable servicelb --flannel-iface=$interface --node-ip=$master1" \
  --merge \
  --sudo \
  --local-path $HOME/.kube/config \
  --ssh-key $HOME/.ssh/$certName \
  --context k3s-single
echo -e " \033[32;5mSingle master node bootstrapped successfully!\033[0m"

# Step 3.2: SKIPPED - Kube-VIP for HA (not needed for single master)
echo -e " \033[33;5mSkipping Kube-VIP setup - single master deployment\033[0m"

# Step 3.6A: Add new master nodes (servers) & workers
# Step 3.3: SKIPPED - Additional master nodes (masters array is empty)
echo -e " \033[33;5mSkipping additional master nodes - single master deployment\033[0m"
for newnode in "${masters[@]}"; do
  echo "No additional masters to join (single master setup)"
done

# Step 3.4: Add single worker node
echo -e " \033[33;5mJoining worker node to cluster...\033[0m"
for newagent in "${workers1[@]}"; do
  k3sup join \
    --ip $newagent \
    --user $user \
    --sudo \
    --k3s-version $k3sVersion \
    --server-ip $master1 \
    --ssh-key $HOME/.ssh/$certName
  echo -e " \033[32;5mWorker node joined successfully!\033[0m"
done

# Step 3.5: SKIPPED - Longhorn storage nodes (workers2 array is empty)
echo -e " \033[33;5mSkipping Longhorn storage nodes - using local-path-provisioner\033[0m"
for newagent in "${workers2[@]}"; do
  echo "No Longhorn storage nodes (minimal setup)"
done

# Step 3.6: SKIPPED - kube-vip Cloud Provider (not needed for single master with MetalLB)
echo -e " \033[33;5mSkipping kube-vip cloud provider - using MetalLB for LoadBalancer\033[0m"

# Step 3.8: Install Metallb
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.12.1/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

# Download ipAddressPool and configure using lbrange above
curl -sO https://raw.githubusercontent.com/JamesTurland/JimsGarage/main/Kubernetes/K3S-Deploy/ipAddressPool
cat ipAddressPool | sed 's/$lbrange/'$lbrange'/g' > $HOME/ipAddressPool.yaml
kubectl apply -f $HOME/ipAddressPool.yaml

# Step 3.9: Test with Nginx
kubectl apply -f https://raw.githubusercontent.com/inlets/inlets-operator/master/contrib/nginx-sample-deployment.yaml -n default
kubectl expose deployment nginx-1 --port=80 --type=LoadBalancer -n default

echo -e " \033[32;5mWaiting for K3S to sync and LoadBalancer to come online\033[0m"

while [[ $(kubectl get pods -l app=nginx -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
   sleep 1
done

# Step 3.10: Deploy IP Pools and l2Advertisement
kubectl wait --namespace metallb-system \
                --for=condition=ready pod \
                --selector=component=controller \
                --timeout=120s
kubectl apply -f ipAddressPool.yaml
kubectl apply -f https://raw.githubusercontent.com/JamesTurland/JimsGarage/main/Kubernetes/K3S-Deploy/l2Advertisement.yaml

kubectl get nodes
kubectl get svc
kubectl get pods --all-namespaces -o wide

echo -e " \033[32;5mHappy Kubing! Access Nginx at EXTERNAL-IP above\033[0m"