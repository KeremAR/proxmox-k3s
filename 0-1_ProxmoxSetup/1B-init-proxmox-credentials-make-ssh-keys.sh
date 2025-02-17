#!/bin/bash

# Step 1B.1 Make sure you switched user to ubuntuprox. su - ubuntuprox

# Step 1B.2 Download scripts 2A-2C to later be execulted
curl -sO https://raw.githubusercontent.com/benspilker/proxmox-k3s/main/2_MakeProxmoxVMs/2A-make-vm-template.sh
chmod +x 2A-make-vm-template.sh

curl -sO https://raw.githubusercontent.com/benspilker/proxmox-k3s/main/2_MakeProxmoxVMs/2B-make-vms-from-template.sh
chmod +x 2B-make-vms-from-template.sh

curl -sO https://raw.githubusercontent.com/benspilker/proxmox-k3s/main/2_MakeProxmoxVMs/2C-copy-ssh_creds.sh
chmod +x 2C-copy-ssh_creds.sh

# Step 1B.3 Create ssh key for the new user
ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ""

# Step 1B.4 Show and save your public key
echo ""
echo "Copy the public key to your own computer. We will refer back to this this later."
echo ""

cat ./.ssh/id_rsa.pub

# Step 1B.5 Customize Scripts 2A, 2B, and 2C
# Showing the new scripts that were copied
echo ""
echo "Next, Customize and review Scripts 2A, 2B, and 2C"
echo "Use nano to edit."
echo ""
ls