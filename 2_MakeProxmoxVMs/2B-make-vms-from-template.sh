#!/bin/bash

# Script Part 2B, prep Proxmox instance for K3s cluster with VM creation #
# Switch user to ubuntuprox (if you haven't already) su - ubuntuprox

if [ "$(whoami)" != "ubuntuprox" ]; then
  su - ubuntuprox
else
  echo "Confirmed user is logged in as ubuntuprox."
fi

###################################################
# YOU SHOULD ONLY NEED TO EDIT THIS SECTION BELOW #
###################################################

# Step 2B.1 Defining disk space sizing
# With 9 VMs (plus the template), about 500GB of disk space minimum is required for this setup
# However, if all are thin provisioned, this will only require about 100GB free in local-lvm, but may have a slight perfomance hit.
# This also means about 40GB of RAM is needed as well

# We need to define how much disk space will be used

# Controllers (k3s01-03) and admin VM will be thin provisioned and will take 35-ish GB total
# Workers (k3s04 and k3s05) will be thick provisioned (if applicable) and will take 20GB each, 40GB total

# Longhorn storage VMs (Longhorn01-03) are variable in storage. It depends on how much you plan on storing.
# Most deployments have data replicated across all 3 Longhorn nodes for HA. 
# Data is not striped. They are redunant copies, but each should be of same size to allow for replication.
# Typically 128GB is a good size for each of the 3 Longhorn VMs
# This means the total storage by default is 35 + 40 + 128 + 128 + 128  = 459GB

# Set Longhorn VM disk size, GB is automatically assumed. Only use a number.

LONGHORN_DISKSIZE=128


# Step 2B.2 Define local gateway and VM IP's

# NOTE YOU NEED TO SET IPs and Gateway accordingly for all VMs
# You can make them DHCP and make reservations on DHCP server, but note that mac addresses will change with each deployment
# Assigning static IP's in an area outside of dhcp may be a better method (at least it was for me)

# IP of your router
ROUTER_GATEWAY="192.168.100.253"  # Not in CIDR format

# Set your VM IPs and make sure they are available IPs on your network
# Make sure they are listed in CIDR format, ie /24

ADMIN_VM_CIDR="192.168.100.90/24"

TEST_K3S_01_CIDR="192.168.100.91/24"
TEST_K3S_02_CIDR="192.168.100.92/24"
TEST_K3S_03_CIDR="192.168.100.93/24"

TEST_K3S_04_CIDR="192.168.100.94/24"
TEST_K3S_05_CIDR="192.168.100.95/24"

TEST_LONGHORN01_CIDR="192.168.100.96/24"
TEST_LONGHORN02_CIDR="192.168.100.97/24"
TEST_LONGHORN03_CIDR="192.168.100.98/24"


#############################################


# Step 2B.3 Function to create and configure a VM called create_vm

create_vm() {
    local vm_id=$1
    local vm_name=$2
    local memory=$3
    local cores=$4
    local ip=$5
    local resize_disk=$6
    local extra_configs=$7

    sudo qm clone 5000 $vm_id --name $vm_name --full
    sudo qm set $vm_id --memory $memory --cores $cores --ipconfig0 ip=$ip
    [ -n "$extra_configs" ] && eval "$extra_configs"
}

# Define storage type for where to put larger VM disks (204, 205, 211-213)
# I typically have a volume I create for thick provisioned VMs called LVM-Thick

# Check if the LVM-Thick volume exists, otherwise use local-lvm
if sudo vgs | grep -q "LVM-Thick"; then
    storage="LVM-Thick"
else
    storage="local-lvm"
fi



# Creating individual VMs for the cluster

# Step 2B.4, VM 200 is admin VM where we'll run scripts to configure k3s

 if ping -c 1 -W 1 "${ADMIN_VM_CIDR%/*}" &> /dev/null; then
        echo "IP ${ADMIN_VM_CIDR%/*} is already in use!"
    else
        create_vm 200 "ubuntu-admin-vm" 2048 2 "$ADMIN_VM_CIDR,gw=$ROUTER_GATEWAY"
    fi


# Step 2B.5, VM's 201-203 will be K3S controllers

 if ping -c 1 -W 1 "${TEST_K3S_01_CIDR%/*}" &> /dev/null; then
        echo "IP ${TEST_K3S_01_CIDR%/*} is already in use!"
    else
        create_vm 201 "test-k3s-01" 4096 2 "$TEST_K3S_01_CIDR,gw=$ROUTER_GATEWAY"
    fi

 if ping -c 1 -W 1 "${TEST_K3S_02_CIDR%/*}" &> /dev/null; then
        echo "IP ${TEST_K3S_02_CIDR%/*} is already in use!"
    else
        create_vm 202 "test-k3s-02" 4096 2 "$TEST_K3S_02_CIDR,gw=$ROUTER_GATEWAY"
    fi

 if ping -c 1 -W 1 "${TEST_K3S_03_CIDR%/*}" &> /dev/null; then
        echo "IP ${TEST_K3S_03_CIDR%/*} is already in use!"
    else
        create_vm 203 "test-k3s-03" 4096 2 "$TEST_K3S_03_CIDR,gw=$ROUTER_GATEWAY"
    fi


# Step 2B.6, VM's 204 and 205 will be workload VMs

 if ping -c 1 -W 1 "${TEST_K3S_04_CIDR%/*}" &> /dev/null; then
        echo "IP ${TEST_K3S_04_CIDR%/*} is already in use!"
    else
        create_vm 204 "test-k3s-04" 6144 4 "$TEST_K3S_04_CIDR,gw=$ROUTER_GATEWAY"
        if [[ "$storage" == "LVM-Thick" ]]; then
            sudo qm move_disk 204 scsi0 $storage
            sudo lvremove -y /dev/pve/vm-204-disk-0
            sudo sed -i '/unused0/d' /etc/pve/qemu-server/204.conf
        fi
        sudo qm resize 204 scsi0 +12G
        sudo qm set 204 --scsi0 $storage:vm-204-disk-0,cache=writethrough
    fi

 if ping -c 1 -W 1 "${TEST_K3S_05_CIDR%/*}" &> /dev/null; then
        echo "IP ${TEST_K3S_05_CIDR%/*} is already in use!"
    else
        create_vm 205 "test-k3s-05" 6144 4 "$TEST_K3S_05_CIDR,gw=$ROUTER_GATEWAY"
        if [[ "$storage" == "LVM-Thick" ]]; then
            sudo qm move_disk 205 scsi0 $storage
            sudo lvremove -y /dev/pve/vm-205-disk-0
            sudo sed -i '/unused0/d' /etc/pve/qemu-server/205.conf
        fi
        sudo qm resize 205 scsi0 +12G
        sudo qm set 205 --scsi0 $storage:vm-205-disk-0,cache=writethrough
    fi

# Step 2B.7, VM's 211-213 will be storage workload VMs

 if ping -c 1 -W 1 "${TEST_LONGHORN01_CIDR%/*}" &> /dev/null; then
        echo "IP ${TEST_LONGHORN01_CIDR%/*} is already in use!"
    else
        create_vm 211 "test-longhorn01" 4096 2 "$TEST_LONGHORN01_CIDR,gw=$ROUTER_GATEWAY"
        if [[ "$storage" == "LVM-Thick" ]]; then
            sudo qm move_disk 211 scsi0 $storage
            sudo lvremove -y /dev/pve/vm-211-disk-0
            sudo sed -i '/unused0/d' /etc/pve/qemu-server/211.conf
        fi
        LONGHORN_DISK_INCREASE=$((LONGHORN_DISKSIZE - 8))
        sudo qm resize 211 scsi0 +"$LONGHORN_DISK_INCREASE"G
        sudo qm set 211 --scsi0 $storage:vm-211-disk-0,cache=writethrough
    fi

 if ping -c 1 -W 1 "${TEST_LONGHORN02_CIDR%/*}" &> /dev/null; then
        echo "IP ${TEST_LONGHORN02_CIDR%/*} is already in use!"
    else
        create_vm 212 "test-longhorn02" 4096 2 "$TEST_LONGHORN02_CIDR,gw=$ROUTER_GATEWAY"
        if [[ "$storage" == "LVM-Thick" ]]; then
            sudo qm move_disk 212 scsi0 $storage
            sudo lvremove -y /dev/pve/vm-212-disk-0
            sudo sed -i '/unused0/d' /etc/pve/qemu-server/212.conf
        fi
        sudo qm resize 212 scsi0 +"$LONGHORN_DISK_INCREASE"G
        sudo qm set 212 --scsi0 $storage:vm-212-disk-0,cache=writethrough
    fi

 if ping -c 1 -W 1 "${TEST_LONGHORN03_CIDR%/*}" &> /dev/null; then
        echo "IP ${TEST_LONGHORN03_CIDR%/*} is already in use!"
    else
        create_vm 213 "test-longhorn03" 4096 2 "$TEST_LONGHORN03_CIDR,gw=$ROUTER_GATEWAY"
        if [[ "$storage" == "LVM-Thick" ]]; then
            sudo qm move_disk 213 scsi0 $storage
            sudo lvremove -y /dev/pve/vm-213-disk-0
            sudo sed -i '/unused0/d' /etc/pve/qemu-server/213.conf
        fi
        sudo qm resize 213 scsi0 +"$LONGHORN_DISK_INCREASE"G
        sudo qm set 213 --scsi0 $storage:vm-213-disk-0,cache=writethrough
    fi
    
echo ""	
echo "VMs are created. Please review their hardware settings manually."