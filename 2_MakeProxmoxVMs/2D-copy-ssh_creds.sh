#!/bin/bash

# Step 2D.0: Switch user to ubuntuprox (if you haven't already)
if [ "$(whoami)" != "ubuntuprox" ]; then
  su - ubuntuprox
else
  echo "Confirmed user is logged in as ubuntuprox."
  echo ""
fi

# Step 2D.1 Gather IPs from all VMs

# Function to extract CIDR and IP from the source script
extract_ip() {
    local var_name=$1
    local cidr=$(grep -oP "${var_name}=\"\K[0-9.]+/[0-9]+" 2B-make-vms-from-template.sh)
    echo "$cidr" "${cidr%/*}"
}

# Define VM names in output order - MODIFIED for 2 VM setup
vm_names=(
    TEST_K3S_01_CIDR TEST_K3S_02_CIDR
)
# Removed ADMIN_VM_CIDR and all other VMs - only using Master and Worker

# Extract IPs and preserve order
vm_ips=()
for name in "${vm_names[@]}"; do
    read cidr ip < <(extract_ip "$name")
    vm_ips+=("${name/_CIDR/}_IP = $ip")
    declare "${name/_CIDR/}_IP=$ip"
done

# Step 2D.2 - Prompt to update all VMs
read -p "Do you want to check for VM updates, apply them, and reboot VMs? (y/n): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    for entry in "${vm_ips[@]}"; do
        ip=$(echo "$entry" | awk '{ print $NF }')
        until ping -c 1 "$ip" &>/dev/null; do
            echo "$ip is not responding, retrying..."
            sleep 2
        done
        echo "$ip is up."
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -t -i ./.ssh/id_rsa ubuntu@"$ip" \
            "sudo apt update && sudo apt full-upgrade -y && sudo reboot"
    done
    echo -e "\nVM updates complete.\n"
else
    echo "Skipping VM updates."
fi

echo ""
echo "ensuring Master VM is fully up before proceeding..."
sleep 15
# Step 2D.3 - Wait for Master VM to be reachable and copy SSH keys
MASTER_VM_IP=$(echo "${vm_ips[0]}" | awk '{ print $NF }')  # First IP is Master VM (k3s-master)

until ping -c 1 $MASTER_VM_IP &>/dev/null; do
    echo "$MASTER_VM_IP is not responding, retrying..."
    sleep 2
done
echo "Master VM ($MASTER_VM_IP) is up"

while true; do
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$MASTER_VM_IP \
        "ls /home/ubuntu/id_rsa /home/ubuntu/id_rsa.pub" &>/dev/null

    if [ $? -eq 0 ]; then
        echo "Key files found on Master VM. Exiting loop."
        break
    else
        echo "Key files missing, copying SSH keys to Master VM..."
        scp -o StrictHostKeyChecking=no \
            /home/ubuntuprox/.ssh/id_rsa \
            /home/ubuntuprox/.ssh/id_rsa.pub \
            ubuntu@$MASTER_VM_IP:/home/ubuntu/
        break
    fi

    echo "SSH not ready, waiting 5 seconds before retrying..."
    sleep 5
done

# Step 2D.4 - Save IPs locally and copy to Admin VM (if missing)

[ -f VM_IPs.txt ] || {
    echo "Creating local VM_IPs.txt..."
    for entry in "${vm_ips[@]}"; do echo "$entry"; done > VM_IPs.txt
}

ssh -i ./.ssh/id_rsa ubuntu@$MASTER_VM_IP '[ -f ~/VM_IPs.txt ]' || {
    echo "Copying VM_IPs.txt to Master VM..."
    scp -i ./.ssh/id_rsa VM_IPs.txt ubuntu@$MASTER_VM_IP:~/ 
}

# Step 2D.5: SSH to Master VM and prepare scripts

# The rest of our work for the remainder of the project will be done from Master VM.
# Master VM will serve as both K3s controller and management node.

# SSH to the Master VM to get files to it
ssh -i ./.ssh/id_rsa ubuntu@$MASTER_VM_IP <<EOF

  # Set permissions for SSH keys
  chmod 600 /home/ubuntu/id_rsa
  chmod 644 /home/ubuntu/id_rsa.pub

  echo "Downloading scripts (if they don't already exist) and making scripts executable..."
  echo ""
  echo "Next, continue with Script 3."
  echo ""

  FILE="3-install-k3s-from-JimsGarage.sh"
  [ -f "\$FILE" ] || curl -sO "https://raw.githubusercontent.com/KeremAR/proxmox-k3s/main/3_Install-K3s/\$FILE" && chmod +x "\$FILE"

  # K3s installation script ready
  # Cloud-Native Infrastructure scripts will be downloaded after K3s installation
  
EOF

# Step 2D.6: SSH to Master VM to continue with the next section and execute scripts. 
# This last line also lets us ssh back to the Master VM if we exited out of the Proxmox shell.
echo ""
echo "=== TRANSITIONING TO MASTER VM ==="
echo "From this point forward, all scripts will run on Master VM (192.168.0.101)"
echo "Master VM serves as both K3s controller and management node."
echo ""
ssh -t -i ./.ssh/id_rsa ubuntu@$MASTER_VM_IP "ls;bash"