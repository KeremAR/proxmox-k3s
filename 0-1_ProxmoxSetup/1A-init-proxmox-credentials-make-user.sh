#!/bin/bash

# Script to prep Proxmox instance for K3s cluster

# install sudo as root first
apt update
apt install sudo -y

# For better security, create a separate Linux user instead of using root, PASSWORD DEFINED ON STEP 1A.3
# You will also need to define a separate password for your ubuntu VMs on steps in Script 2.

# Note this is a user to the OS host running Proxmox, not the Proxmox UI, therefore you won't see this as an added user in the Proxmox UI

# Step 1A.1 Create the user with the default home directory location and bash shell.
useradd -m -s /bin/bash ubuntuprox

# Step 1A.2 Add them to the sudo group
usermod -aG sudo ubuntuprox

# Step 1A.3 Set a password for new user

# Set the password
PASSWORD="<your-new-password-from-step-1A.3>"

# Check if the password is the default one
if [ "$PASSWORD" = "<your-new-password-from-step-1A.3>" ]; then
  echo "Password is still set to the default. Please edit the password using nano 1A-init-proxmox-credentials-make-user.sh to set a custom password."
  exit 1  # Exit the script with a non-zero status
else
  echo "ubuntuprox:$PASSWORD" | chpasswd
fi

# Step 1A.4 switch user to ubuntuprox and download script 1B
su - ubuntuprox -c "curl -sO https://raw.githubusercontent.com/benspilker/proxmox-k3s/main/0-1_ProxmoxSetup/1B-init-proxmox-credentials-make-ssh-keys.sh; chmod +x 1B-init-proxmox-credentials-make-ssh-keys.sh"

# Step 1A.5 switch user to ubuntuprox and show what is in the home directory
su - ubuntuprox -c "script -q -c 'ls; bash'"