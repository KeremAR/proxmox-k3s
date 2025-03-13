#!/bin/bash

# STEP 0 is OPTIONAL Initial Proxmox Setup Script to make a thick lvm and upgrade proxmox to the latest 8.x version
echo ""
echo "Script 0 is designed mainly for fresh installs of Proxmox where you want to set initial settings and update to the latest version of 8.x" 
echo ""

echo "Next this script will create a thick provisioned LVM but requires unallocated disk space."
echo "The existing default thin provisioned local-lvm will be preserved." 
echo ""

read -p "Do you want to create a new LVM? (yes/no): " user_input

# Convert the input to lowercase for easier comparison
user_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')

# Check if the user entered 'yes' or 'y'
if [[ "$user_input" == "yes" || "$user_input" == "y" ]]; then
    echo "You chose to continue."

	# NOTE ONLY RUN THIS IF YOU FIRST INSTALLED PROXMOX AND LEFT UNALLOCATED SPACE

	# Step 0.1 (Assuming Proxmox v8.x was already installed)
	# create usable thick provisioned proxmox logical volume (LVM)

	# The disk to work with (e.g., /dev/sda)
	DISK="/dev/sda"
	PARTITION="${DISK}4"
	VOLUME_GROUP="LVM-Thick"  # Volume Group name
	LV_NAME="lv"             # Logical Volume name

	# Step 0.1A: Create a new partition (using unallocated space) on the disk
	echo -e "n\n\n\n\n\nw" | fdisk $DISK

	# Step 0.1B: Change the partition type to Linux LVM (type 43)
	echo -e "t\n4\n43\nw" | fdisk $DISK

	if fdisk -l /dev/sda | grep -q "^/dev/sda4.*Linux"; then
    		echo "Partition /dev/sda4 exists and is of type Linux LVM. Proceeding with further commands."
    		# Step 0.1C: Create a Volume Group (VG) with the new partition
    		vgcreate $VOLUME_GROUP $PARTITION

    		# Step 0.1D: Verify the volume group creation
    		vgs

    		# Step 0.1E: Backup the storage.cfg before making changes
    		STORAGE_CFG="/etc/pve/storage.cfg"
    		cp $STORAGE_CFG $STORAGE_CFG.bak

    		# Step 0.1F: Add the LVM storage configuration entry to the storage.cfg
    		echo -e "\nlvm: $VOLUME_GROUP\n    vgname $VOLUME_GROUP\n    content images,rootdir\n    disable 0" >> $STORAGE_CFG

    		# Step 0.1G: Check the storage.cfg file to ensure proper formatting
    		cat $STORAGE_CFG | grep -A 5 $VOLUME_GROUP

    		# Step 0.1H: Reload the storage configuration to ensure Proxmox picks it up
    		pvesh get /nodes/$(hostname)/storage

    		# Step 0.1I: Confirm if LVM is now listed as a storage option
    		pvesh get /nodes/$(hostname)/storage | grep $VOLUME_GROUP

	else
    		echo "Partition /dev/sda4 does not exist or is not of type Linux LVM."
	fi   
else
    echo "Skipping LVM creation and continuing on with script."
fi


# Step 0.2 Downloading Script 1A and making it executable 

echo ""
echo "Downloading Script 1A and making it executable"
echo ""

curl -sO https://raw.githubusercontent.com/benspilker/proxmox-k3s/main/0-1_ProxmoxSetup/1A-init-proxmox-credentials-make-user.sh
chmod +x 1A-init-proxmox-credentials-make-user.sh


# Step 0.3, Additionally we can add the non-subscription repository and update

echo "Next we can add the non-subscription repository and update"
echo ""

read -p "Do you want to add the non-subscription repository? This is required to update free PVE instances (yes/no): " user_input

# Convert the input to lowercase for easier comparison
user_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')

# Check if the user entered 'yes' or 'y'
if [[ "$user_input" == "yes" || "$user_input" == "y" ]]; then
    echo "You chose to continue."

	# Get Proxmox version
	version=$(pveversion | grep -oP '\d+\.\d+')

	# Check if the version is 8.x
	if [[ "$version" == "8."* ]]; then
        echo "Proxmox version is 8.x"
        # New content to write to the file
        cat <<EOF > /etc/apt/sources.list
deb http://ftp.us.debian.org/debian bookworm main contrib

deb http://ftp.us.debian.org/debian bookworm-updates main contrib

deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription

# security updates
deb http://security.debian.org bookworm-security main contrib
EOF

        echo "File /etc/apt/sources.list has been updated with the new content."
    else
        echo "Proxmox version is not 8.x. It is version $version. Skipping repository operation."
    fi

    # Updating Proxmox host
    echo ""
    echo "Checking for updates..."
    echo ""

    apt-get update
    apt-get dist-upgrade -y

    echo ""
    echo "Update command was ran and likely updates were applied. Please reboot host..."
    echo "Script run complete. Host can also be rebooted by simply typing reboot"
    echo "" 
    echo "Additionally, script 1A was downloaded."
    ls
    echo ""
    echo "You can run it by typing ./1A-init-proxmox-credentials-make-user.sh"

else
    echo "Skipping repository addition and continuing with script."
fi
