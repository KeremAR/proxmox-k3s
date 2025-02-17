#!/bin/bash

# Step 2D.1 switch user to ubuntuprox (if you haven't already) su - ubuntuprox

# Step 2D.2 SSH into admin machine. The rest of our work for the remainer of the project will be done from here.

# Note the IP of the admin machine. Edit if needed.
ADMIN_VM_IP="192.168.100.6"

ssh -i id_rsa ubuntu@$ADMIN_VM_IP

# Step 2D.3 We need to copy our private ( id_rsa ) and public ( id_rsa.pub ) keys to the home directory of the admin vm amd set permissions

scp -i ./.ssh/id_rsa id_rsa.pub ubuntu@$ADMIN_VM_IP:/home/ubuntu/
scp -i ./.ssh/id_rsa id_rsa ubuntu@$ADMIN_VM_IP:/home/ubuntu/

chmod 600 /home/ubuntu/id_rsa
chmod 644 /home/ubuntu/id_rsa.pub


# Step 2D.4 Download scripts to admin pc and make them executable

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

