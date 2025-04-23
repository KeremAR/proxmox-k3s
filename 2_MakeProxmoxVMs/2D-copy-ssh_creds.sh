#!/bin/bash

# Step 2D.0: Switch user to ubuntuprox (if you haven't already)

if [ "$(whoami)" != "ubuntuprox" ]; then
  su - ubuntuprox
else
  echo "Confirmed user is logged in as ubuntuprox."
  echo ""
fi

# Step 2D.1 Upgrade all 9 VMs

read -p "Do you want to check for VM updates and apply them? (y/n): " confirm
if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    
  # Get a list of IP Addresses for all 9 VM's

  extract_ip() {
    local var_name=$1
    local cidr=$(grep -oP "${var_name}=\"\K[0-9.]+/[0-9]+" 2B-make-vms-from-template.sh)
    local ip=${cidr%/24}
    echo "$cidr" "$ip"
  }

  read ADMIN_VM_CIDR ADMIN_VM_IP < <(extract_ip "ADMIN_VM_CIDR")
  read TEST_K3S_01_CIDR TEST_K3S_01_IP < <(extract_ip "TEST_K3S_01_CIDR")
  read TEST_K3S_02_CIDR TEST_K3S_02_IP < <(extract_ip "TEST_K3S_02_CIDR")
  read TEST_K3S_03_CIDR TEST_K3S_03_IP < <(extract_ip "TEST_K3S_03_CIDR")
  read TEST_K3S_04_CIDR TEST_K3S_04_IP < <(extract_ip "TEST_K3S_04_CIDR")
  read TEST_K3S_05_CIDR TEST_K3S_05_IP < <(extract_ip "TEST_K3S_05_CIDR")
  read TEST_LONGHORN01_CIDR TEST_LONGHORN01_IP < <(extract_ip "TEST_LONGHORN01_CIDR")
  read TEST_LONGHORN02_CIDR TEST_LONGHORN02_IP < <(extract_ip "TEST_LONGHORN02_CIDR")
  read TEST_LONGHORN03_CIDR TEST_LONGHORN03_IP < <(extract_ip "TEST_LONGHORN03_CIDR")

  # Run a for each loop to apply updates to all VM's

  for vm_ip in $ADMIN_VM_IP $TEST_K3S_01_IP $TEST_K3S_02_IP $TEST_K3S_03_IP $TEST_K3S_04_IP $TEST_K3S_05_IP $TEST_LONGHORN01_IP $TEST_LONGHORN02_IP $TEST_LONGHORN03_IP; do
      while true; do
          if ping -c 1 "$vm_ip" &> /dev/null; then
              echo "$vm_ip is up."
              ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -t -i ./.ssh/id_rsa ubuntu@"$vm_ip" \
              "sudo apt update && sudo apt full-upgrade -y && sudo reboot"
              break
          else
              echo "$vm_ip is not responding, retrying..."
              sleep 2
          fi
      done
  done
      echo ""
      echo "VM updates complete."
  else
      echo "Skipping VM updates."
fi

# Step 2D.2: Ping the admin machine. Once reachable, copy SSH creds to it to be used for other VMs.

# Get the IP of the admin machine that was defined in Script 2B
# Extract the value of ADMIN_VM_CIDR from script 2B
ADMIN_VM_CIDR=$(grep -oP 'ADMIN_VM_CIDR="\K[0-9.]+/[0-9]+' 2B-make-vms-from-template.sh)
ADMIN_VM_IP=$(echo "$ADMIN_VM_CIDR" | sed 's#/24##')

# Continuously ping the device until it responds
while true; do
    if ping -c 1 $ADMIN_VM_IP &> /dev/null; then
        echo "$ADMIN_VM_IP is up."

        # Copy necessary files using SCP
    ssh -o StrictHostKeyChecking=no -i ./.ssh/id_rsa ubuntu@$ADMIN_VM_IP '[ -f /home/ubuntu/id_rsa ] && [ -f /home/ubuntu/id_rsa.pub ]' || {
      echo "Copying files to remote..."
      scp -o StrictHostKeyChecking=no -i ./.ssh/id_rsa ./.ssh/id_rsa.pub ubuntu@$ADMIN_VM_IP:/home/ubuntu/
      scp -o StrictHostKeyChecking=no -i ./.ssh/id_rsa ./.ssh/id_rsa ubuntu@$ADMIN_VM_IP:/home/ubuntu/
      }
        # Break out of the loop once the ping succeeds
        break
    else
        echo "$ADMIN_VM_IP is not responding, retrying..."
        sleep 2  # Wait 2 seconds before trying again
    fi
done

# Step 2D.3: SSH to Admin VM, then download scripts to the admin VM and make them executable
# The rest of our work for the remainder of the project will be done from here.

# Save the IP of the Admin VM as a txt file under ubuntuprox
if [ ! -f ADMIN_VM_IP.txt ]; then echo "$ADMIN_VM_IP" > ADMIN_VM_IP.txt 
fi

# SSH to the Admin VM to get files to it
ssh -i ./.ssh/id_rsa ubuntu@$ADMIN_VM_IP <<EOF

  # Also save the IP of the Admin VM as a txt file under Admin VM
  if [ ! -f ADMIN_VM_IP.txt ]; then echo "$ADMIN_VM_IP" > ADMIN_VM_IP.txt; fi

  # Set permissions for SSH keys
  chmod 600 /home/ubuntu/id_rsa
  chmod 644 /home/ubuntu/id_rsa.pub

  echo "Downloading scripts (if they don't already exist) and making scripts executable..."
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

# Step 2D.4: SSH to Admin VM to continue with the next section and execute scripts
ssh -t -i ./.ssh/id_rsa ubuntu@$ADMIN_VM_IP "ls;bash"