#!/bin/bash

# Step 2D.0: Switch user to ubuntuprox (if you haven't already)

if [ "$(whoami)" != "ubuntuprox" ]; then
  su - ubuntuprox
else
  echo "Confirmed user is logged in as ubuntuprox."
  echo ""
fi

# Step 2D.1 Update all 9 VMs

read -p "Do you want to check for VM updates, apply them, and reboot VMs? (y/n): " confirm
if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    
 # Get a list of IP Addresses for all 9 VM's that were defined in Script 2B
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
      echo ""
  else
      echo "Skipping VM updates."
fi

echo ""

# Step 2D.2: Ping the admin machine. Once reachable, copy SSH creds to it to be used for other VMs.

# Wait for ping to respond
while true; do
    if ping -c 1 $ADMIN_VM_IP &> /dev/null; then
        echo "$ADMIN_VM_IP is up"

        # Retry SSH and copy logic
        while true; do
            # Check if the key files exist on the remote machine
            ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$ADMIN_VM_IP \
                "ls /home/ubuntu/id_rsa /home/ubuntu/id_rsa.pub" &> /dev/null

            if [ $? -eq 0 ]; then
                echo "Key files found on remote host. Exiting loop."
                break
            else
                # SSH succeeded, but files are missing. Copy the keys
                echo "Key files missing, copying files..."
                scp -o StrictHostKeyChecking=no \
                    /home/ubuntuprox/.ssh/id_rsa \
                    /home/ubuntuprox/.ssh/id_rsa.pub \
                    ubuntu@$ADMIN_VM_IP:/home/ubuntu/

                break  # Exit the loop after copying the keys
            fi

            echo "SSH not ready, waiting 5 seconds before retrying..."
            sleep 5
        done

        echo "SSH successful, required files are present."
        break
    else
        echo "$ADMIN_VM_IP is not responding, retrying..."
        sleep 2  # Wait 2 seconds before retrying ping
    fi
done

# Step 2D.3: SSH to Admin VM, then download scripts to the admin VM and make them executable
# The rest of our work for the remainder of the project will be done from here.

# SSH to the Admin VM to get files to it
ssh -i ./.ssh/id_rsa ubuntu@$ADMIN_VM_IP <<EOF

  # Save the IP of the VMs as a txt file under Admin VM for Script 3 to reference
  if [ ! -f VM_IPs.txt ]; then 
    echo "ADMIN_VM_IP = $ADMIN_VM_IP" > VM_IPs.txt
    echo "TEST_K3S_01_IP = $TEST_K3S_01_IP" >> VM_IPs.txt
    echo "TEST_K3S_02_IP = $TEST_K3S_02_IP" >> VM_IPs.txt
    echo "TEST_K3S_03_IP = $TEST_K3S_03_IP" >> VM_IPs.txt
    echo "TEST_K3S_04_IP = $TEST_K3S_04_IP" >> VM_IPs.txt
    echo "TEST_K3S_05_IP = $TEST_K3S_05_IP" >> VM_IPs.txt
    echo "TEST_LONGHORN01_IP = $TEST_LONGHORN01_IP" >> VM_IPs.txt
    echo "TEST_LONGHORN02_IP = $TEST_LONGHORN02_IP" >> VM_IPs.txt
    echo "TEST_LONGHORN03_IP = $TEST_LONGHORN03_IP" >> VM_IPs.txt
  fi

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

# Step 2D.4: SSH to Admin VM to continue with the next section and execute scripts. This last line also lets us ssh back to the Admin VM if we exited out of the Proxmox shell.
ssh -t -i ./.ssh/id_rsa ubuntu@$ADMIN_VM_IP "ls;bash"