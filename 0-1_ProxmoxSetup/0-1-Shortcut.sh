### Proxmox K3s (Kubernetes) Shortcut Script ###
# Open the shell, copy and paste this into the shell

clear

echo "########################################################"
echo "Welcome to the Proxmox K3s (Kubernetes) Shortcut script!"
echo ""
sleep 1
echo "This script is the beginning of a series of scripts to setup Kubernetes and deploy a workload"
echo ""
sleep 1

cat <<EOF
Shortcut Added in 0-1 Folder <----- You are here
Prompts the user to start with either the optional Script 0 or 1A.

Step 0: Optional Initial Proxmox Setup
This step is optional and assumes Proxmox is already installed. It involves setting up LVM for storage management and upgrading Proxmox.

Create LVM: Set up a partition on /dev/sda and create a volume group LVM-Thick.
Backup Proxmox Configuration: Back up the Proxmox storage configuration to /etc/pve/storage.cfg.bak.
Add LVM Storage: Modify /etc/pve/storage.cfg to include the new LVM storage.
Upgrade Proxmox: Update Proxmox to the latest version.

Step 1: Prepare Proxmox Credentials for K3s
1A. Create a New User: Add a ubuntuprox user with sudo privileges.
1B. Set Up SSH: Generate SSH keys for ubuntuprox then download Scripts 2A-2D and make them executable.

Step 2: Prepare Proxmox VMs for K3s Cluster

Step 3: Installing K3s on Nodes

Step 4: Install Rancher UI and Tools

Step 5: DNS Setup and Test Nextcloud Install

Step 6: Nextcloud Install with MySQL and Persistent Storage
EOF

sleep 5
echo ""
echo ""
echo "This lets the user choose between starting at Script 0 or Script 1A."
echo "Script 0 is designed for fresh Proxmox installs."
echo ""
read -p "Do you want to start with the optional Script 0 to initialize Proxmox? No will start Script 1A. (yes/no): " user_input

user_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')

# Check if the user entered 'yes' or 'y'
if [[ "$user_input" == "yes" || "$user_input" == "y" ]]; then
	clear
    echo "You chose Script 0."

	curl -sO https://raw.githubusercontent.com/benspilker/proxmox-k3s/main/0-1_ProxmoxSetup/0-Optional-proxmox-initial-setup.sh
	chmod +x 0-Optional-proxmox-initial-setup.sh
	./0-Optional-proxmox-initial-setup.sh
else
    echo "Skipping Script 0. Continuing to Script 1A."
	curl -sO https://raw.githubusercontent.com/benspilker/proxmox-k3s/main/0-1_ProxmoxSetup/1A-init-proxmox-credentials-make-user.sh
	chmod +x 1A-init-proxmox-credentials-make-user.sh
	./1A-init-proxmox-credentials-make-user.sh
fi