#!/bin/bash

# Script to prep Proxmox instance for K3s cluster, creating a VM template #
# You must define your ubuntuprox password in step 2A.1

# Step 2A.1, define credentials that were made in script step 1A.3

###############################################
# Re-enter that password here

PASSWORD="<your-new-password-for-step-1A.3>"

###############################################

# Check if the password is the default one
if [ "$PASSWORD" = "<your-new-password-for-step-1A.3>" ]; then
  echo ""
  echo "Password is still set to default. Please edit using nano 2A-make-vm-template.sh to set a custom password, then run script again."
  exit 1  # Exit the script with a non-zero status
fi

# Also we should set a cloudinit password for our template
# Alternatively, the default is to keep it the same as the above password
CIPASS="$PASSWORD"

# Step 2A.2, Switch user to ubuntuprox (if you haven't already) su - ubuntuprox

if [ "$(whoami)" != "ubuntuprox" ]; then
  su - ubuntuprox
else
  echo "Confirmed user is logged in as ubuntuprox."
fi

# Step 2A.3, download Ubuntu Jammy img to the default iso folder

# URL of the file to download
FILE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64-disk-kvm.img"

# Directory to save the file
ISO_DIR="/var/lib/vz/template/iso"

# Filename to be saved
FILE_NAME="jammy-server-cloudimg-amd64-disk-kvm.img"

# Full path to the file
FILE_PATH="$ISO_DIR/$FILE_NAME"

# Check if the file already exists
if [ -f "$FILE_PATH" ]; then
    echo "File '$FILE_NAME' already exists in $ISO_DIR. Skipping download."
else
    # Download the file and save it in the specified directory
    echo "$PASSWORD" | sudo -S wget -O "$FILE_PATH" "$FILE_URL"

    # Check if the download was successful
    if [[ $? -eq 0 ]]; then
        echo "File downloaded successfully to $FILE_PATH"
    else
        echo "Failed to download the file"
    fi
fi


# Step 2A.4 Create VM template, make sure to define your cloud init user password on 4B

echo "$PASSWORD" | sudo -S qm create 5000 --memory 4096 --cores 2 --name ubuntu-template --net0 virtio,bridge=vmbr0 --cpu host
sudo qm importdisk 5000 $FILE_PATH local-lvm
sudo qm set 5000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-5000-disk-0
sudo qm set 5000 --ide2 local-lvm:cloudinit

# Step 2A.5, Set cloud init password 
sudo qm set 5000 --ciuser ubuntu --cipassword $CIPASS

# Step 2A.6 Note the ssh public key is set here which is the public key of the current user
# In this case ubuntuprox (user switched from root to ubuntuprox at step 2A.1)

sudo qm set 5000 --sshkey ~/.ssh/id_rsa.pub

sudo qm set 5000 --serial0 socket --vga serial0
sudo qm resize 5000 scsi0 +6G 
sudo qm set 5000 -boot order=scsi0
sudo qm set 5000 --ipconfig0 ip=dhcp
sudo qm template 5000 > /dev/null 2>&1

echo ""
echo "A VM template is now created!"
echo ""
echo "Please run nano 2B-make-vms-from-template.sh to review script 2B parameters to deploy VMs based on template."
echo ""