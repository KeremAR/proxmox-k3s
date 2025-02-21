#!/bin/bash

# Step 2D.1: Switch user to ubuntuprox (if you haven't already)
# su - ubuntuprox

# Step 2D.2: Ping the admin machine. Once reachable, copy SSH creds to it to be used for other VMs.

# Note the IP of the admin machine. Edit if needed.
ADMIN_VM_IP="192.168.100.6"

# Continuously ping the device until it responds
while true; do
    if ping -c 1 $ADMIN_VM_IP &> /dev/null; then
        echo "$ADMIN_VM_IP is up."

        # Copy necessary files using SCP
        scp -i ./.ssh/id_rsa id_rsa.pub ubuntu@$ADMIN_VM_IP:/home/ubuntu/
        scp -i ./.ssh/id_rsa id_rsa ubuntu@$ADMIN_VM_IP:/home/ubuntu/

        # Break out of the loop once the ping succeeds
        break
    else
        echo "$ADMIN_VM_IP is not responding, retrying..."
        sleep 2  # Wait 2 seconds before trying again
    fi
done

# Step 2D.3: SSH to Admin VM, then download scripts to the admin VM and make them executable
# The rest of our work for the remainder of the project will be done from here.

ssh -i ./.ssh/id_rsa ubuntu@$ADMIN_VM_IP << 'EOF'
    # Set permissions for SSH keys
    chmod 600 /home/ubuntu/id_rsa
    chmod 644 /home/ubuntu/id_rsa.pub

    echo "Downloading and making scripts executable..."

    # Download scripts and make them executable
    curl -sO https://raw.githubusercontent.com/benspilker/proxmox-k3s/main/3_Install-K3s/3-install-k3s-from-JimsGarage.sh
    chmod +x 3-install-k3s-from-JimsGarage.sh

    curl -sO https://raw.githubusercontent.com/benspilker/proxmox-k3s/main/4_RancherInstall/4A-install-rancher-ui.sh
    chmod +x 4A-install-rancher-ui.sh

    curl -sO https://raw.githubusercontent.com/benspilker/proxmox-k3s/main/4_RancherInstall/4B-post-rancher-install.sh
    chmod +x 4B-post-rancher-install.sh

    curl -sO https://raw.githubusercontent.com/benspilker/proxmox-k3s/main/5-6_Install-Nextcloud/5-install-nextcloud.sh
    chmod +x 5-install-nextcloud.sh

    curl -sO https://raw.githubusercontent.com/benspilker/proxmox-k3s/main/5-6_Install-Nextcloud/6-nextcloud-persistent-storage.sh
    chmod +x 6-nextcloud-persistent-storage.sh


EOF

# Step 2D.4: SSH to Admin VM to continue with the next section and execute scripts
ssh -t -i ./.ssh/id_rsa ubuntu@$ADMIN_VM_IP "ls;bash"
