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

# Define VM names in output order
vm_names=(
    ADMIN_VM_CIDR
    TEST_K3S_01_CIDR TEST_K3S_02_CIDR TEST_K3S_03_CIDR TEST_K3S_04_CIDR TEST_K3S_05_CIDR
    TEST_LONGHORN01_CIDR TEST_LONGHORN02_CIDR TEST_LONGHORN03_CIDR
)

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

# Step 2D.3 - Wait for Admin VM to be reachable and copy SSH keys
ADMIN_VM_IP=$(echo "${vm_ips[0]}" | awk '{ print $NF }')  # First IP is Admin VM

until ping -c 1 $ADMIN_VM_IP &>/dev/null; do
    echo "$ADMIN_VM_IP is not responding, retrying..."
    sleep 2
done
echo "$ADMIN_VM_IP is up"

while true; do
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$ADMIN_VM_IP \
        "ls /home/ubuntu/id_rsa /home/ubuntu/id_rsa.pub" &>/dev/null

    if [ $? -eq 0 ]; then
        echo "Key files found on remote host. Exiting loop."
        break
    else
        echo "Key files missing, copying files..."
        scp -o StrictHostKeyChecking=no \
            /home/ubuntuprox/.ssh/id_rsa \
            /home/ubuntuprox/.ssh/id_rsa.pub \
            ubuntu@$ADMIN_VM_IP:/home/ubuntu/
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

ssh -i ./.ssh/id_rsa ubuntu@$ADMIN_VM_IP '[ -f ~/VM_IPs.txt ]' || {
    echo "Copying VM_IPs.txt to Admin VM..."
    scp -i ./.ssh/id_rsa VM_IPs.txt ubuntu@$ADMIN_VM_IP:~/ 
}

# Step 2D.5: SSH to Admin VM and prepare scripts

# The rest of our work for the remainder of the project will be done from here.

# SSH to the Admin VM to get files to it
ssh -i ./.ssh/id_rsa ubuntu@$ADMIN_VM_IP <<EOF

  # Set permissions for SSH keys
  chmod 600 /home/ubuntu/id_rsa
  chmod 644 /home/ubuntu/id_rsa.pub

  echo "Downloading scripts (if they don't already exist) and making scripts executable..."
  echo ""
  echo "Continue with Script 3."
  echo ""

  FILE="3-install-k3s-from-JimsGarage.sh"
  [ -f "\$FILE" ] || curl -sO "https://raw.githubusercontent.com/benspilker/proxmox-k3s/main/3_Install-K3s/\$FILE" && chmod +x "\$FILE"

  FILE="4-install-rancher-ui.sh"
  [ -f "\$FILE" ] || curl -sO "https://raw.githubusercontent.com/benspilker/proxmox-k3s/main/4_RancherInstall/\$FILE" && chmod +x "\$FILE"

  FILE="5A-domainname-dns.sh"
  [ -f "\$FILE" ] || curl -sO "https://raw.githubusercontent.com/benspilker/proxmox-k3s/main/5-6_Install-Nextcloud/\$FILE" && chmod +x "\$FILE"

  FILE="5B-optional-test-nextcloud-install.sh"
  [ -f "\$FILE" ] || curl -sO "https://raw.githubusercontent.com/benspilker/proxmox-k3s/main/5-6_Install-Nextcloud/\$FILE" && chmod +x "\$FILE"

  FILE="6-nextcloud-mysql-persistent.sh"
  [ -f "\$FILE" ] || curl -sO "https://raw.githubusercontent.com/benspilker/proxmox-k3s/main/5-6_Install-Nextcloud/\$FILE" && chmod +x "\$FILE"
  
EOF

# Step 2D.6: SSH to Admin VM to continue with the next section and execute scripts. This last line also lets us ssh back to the Admin VM if we exited out of the Proxmox shell.
ssh -t -i ./.ssh/id_rsa ubuntu@$ADMIN_VM_IP "ls;bash"