### Proxmox K3s (Kubernetes) Shortcut Script ###
# Open the shell, copy and paste this into the shell

clear

echo "###############################"
echo "Welcome to the shortcut script!"
echo ""

echo "This lets the user choose between starting at Script 0 or Script 1A."
echo "Script 0 is designed for fresh Proxmox installs."
echo ""
read -p "Do you want to start with the optional Script 0? No will start Script 1A. (yes/no): " user_input

user_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')

# Check if the user entered 'yes' or 'y'
if [[ "$user_input" == "yes" || "$user_input" == "y" ]]; then
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

