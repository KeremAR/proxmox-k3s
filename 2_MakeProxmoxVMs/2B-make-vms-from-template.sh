#!/bin/bash

# Script Part 2B, prep Proxmox instance for K3s cluster with VM creation #
# Switch user to ubuntuprox (if you haven't already) su - ubuntuprox


#############################################
# YOU SHOULD ONLY NEED TO EDIT THIS SECTION #
#############################################

# Step 2B.1 Defining disk space sizing
# With 9 VMs (plus the template), it is recommended to have about 500GB of free disk space for this setup
# If all are thin provisioned, this will take much less but may have a perfomance hit
# This also means about 40GB of RAM is needed as well

# We need to define how much disk space will be used

# Controllers (k3s01-03) and admin VM will be thin provisioned and will take 35-ish GB total
# Workers (k3s04 and k3s05) will be thick provisioned (if applicable) and will take 32GB each, 64GB total

# Longhorn storage VMs (Longhorn01-03) are variable in storage. It depends on how much you plan on storing.
# Most deployments have data replicated across all 3 Longhorn nodes for HA. Data is not striped, but each should be of same size to allow for replication.
# Typically 128GB is a good size for each of the 3 Longhorn VMs
# This means the total storage by default is 35 + 64 + 128 + 128 + 128  = 480GB

# Set Longhorn VM disk size, GB is automatically assumed. Only use a number.

LONGHORN_DISKSIZE=64


# Step 2B.2 Define local gateway and VM IP's

# NOTE YOU NEED TO SET IPs and Gateway accordingly for all VMs
# You can make them DHCP and make reservations on DHCP server, but note that mac addresses will change with each deployment
# Assigning static IP's in an area outside of dhcp may be a better method (at least it was for me)

# IP of your router
ROUTER_GATEWAY="192.168.100.253"


ADMIN_VM_CIDR="192.168.100.6/24"

TEST_K3S_01_CIDR="192.168.100.76/24"
TEST_K3S_02_CIDR="192.168.100.92/24"
TEST_K3S_03_CIDR="192.168.100.93/24"

TEST_K3S_04_CIDR="192.168.100.94/24"
TEST_K3S_05_CIDR="192.168.100.95/24"

TEST_LONGHORN01_CIDR="192.168.100.3/24"
TEST_LONGHORN02_CIDR="192.168.100.4/24"
TEST_LONGHORN03_CIDR="192.168.100.5/24"


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

# Define storage type for where to put larger VM disks (304, 305, 311-313)
# I typically have a volume I create for thick provisioned VMs called LVM-Thick

# Check if the LVM-Thick volume exists, otherwise use local-lvm
if sudo vgs | grep -q "LVM-Thick"; then
    storage="LVM-Thick"
else
    storage="local-lvm"
fi



# Creating individual VMs for the cluster

# Step 2B.4, VM 300 is admin VM where we'll run scripts to configure k3s

 if ping -c 1 -W 1 "${ADMIN_VM_CIDR%/*}" &> /dev/null; then
        echo "IP ${ADMIN_VM_CIDR%/*} is already in use!"
    else
        create_vm 300 "ubuntu-admin-vm" 2048 2 "$ADMIN_VM_CIDR,gw=$ROUTER_GATEWAY"
    fi


# Step 2B.5, VM's 301-303 will be K3S controllers

 if ping -c 1 -W 1 "${TEST_K3S_01_CIDR%/*}" &> /dev/null; then
        echo "IP ${TEST_K3S_01_CIDR%/*} is already in use!"
    else
        create_vm 301 "test-k3s-01" 4096 2 "$TEST_K3S_01_CIDR,gw=$ROUTER_GATEWAY"
    fi

 if ping -c 1 -W 1 "${TEST_K3S_02_CIDR%/*}" &> /dev/null; then
        echo "IP ${TEST_K3S_02_CIDR%/*} is already in use!"
    else
        create_vm 302 "test-k3s-02" 4096 2 "$TEST_K3S_02_CIDR,gw=$ROUTER_GATEWAY"
    fi

 if ping -c 1 -W 1 "${TEST_K3S_03_CIDR%/*}" &> /dev/null; then
        echo "IP ${TEST_K3S_03_CIDR%/*} is already in use!"
    else
        create_vm 303 "test-k3s-03" 4096 2 "$TEST_K3S_03_CIDR,gw=$ROUTER_GATEWAY"
    fi


# Step 2B.6, VM's 304 and 305 will be workload VMs

 if ping -c 1 -W 1 "${TEST_K3S_04_CIDR%/*}" &> /dev/null; then
        echo "IP ${TEST_K3S_04_CIDR%/*} is already in use!"
    else
        create_vm 304 "test-k3s-04" 6144 4 "$TEST_K3S_04_CIDR,gw=$ROUTER_GATEWAY"
        if [[ "$storage" == "LVM-Thick" ]]; then
            sudo qm move_disk 304 scsi0 $storage
            sudo lvremove -y /dev/pve/vm-304-disk-0
            sudo sed -i '/unused0/d' /etc/pve/qemu-server/304.conf
        fi
        sudo qm resize 304 scsi0 +24G
        sudo qm set 304 --scsi0 $storage:vm-304-disk-0,cache=writethrough
    fi

 if ping -c 1 -W 1 "${TEST_K3S_05_CIDR%/*}" &> /dev/null; then
        echo "IP ${TEST_K3S_05_CIDR%/*} is already in use!"
    else
        create_vm 305 "test-k3s-05" 6144 4 "$TEST_K3S_05_CIDR,gw=$ROUTER_GATEWAY"
        if [[ "$storage" == "LVM-Thick" ]]; then
            sudo qm move_disk 305 scsi0 $storage
            sudo lvremove -y /dev/pve/vm-305-disk-0
            sudo sed -i '/unused0/d' /etc/pve/qemu-server/305.conf
        fi
        sudo qm resize 305 scsi0 +24G
        sudo qm set 305 --scsi0 $storage:vm-305-disk-0,cache=writethrough
    fi

# Step 2B.7, VM's 311-313 will be storage workload VMs

 if ping -c 1 -W 1 "${TEST_LONGHORN01_CIDR%/*}" &> /dev/null; then
        echo "IP ${TEST_LONGHORN01_CIDR%/*} is already in use!"
    else
        create_vm 311 "test-longhorn01" 4096 2 "$TEST_LONGHORN01_CIDR,gw=$ROUTER_GATEWAY"
        if [[ "$storage" == "LVM-Thick" ]]; then
            sudo qm move_disk 311 scsi0 $storage
            sudo lvremove -y /dev/pve/vm-311-disk-0
            sudo sed -i '/unused0/d' /etc/pve/qemu-server/311.conf
        fi
        LONGHORN_DISK_INCREASE=$((LONGHORN_DISKSIZE - 8))
        sudo qm resize 311 scsi0 +"$LONGHORN_DISK_INCREASE"G
        sudo qm set 311 --scsi0 $storage:vm-311-disk-0,cache=writethrough
    fi

 if ping -c 1 -W 1 "${TEST_LONGHORN02_CIDR%/*}" &> /dev/null; then
        echo "IP ${TEST_LONGHORN02_CIDR%/*} is already in use!"
    else
        create_vm 312 "test-longhorn02" 4096 2 "$TEST_LONGHORN02_CIDR,gw=$ROUTER_GATEWAY"
        if [[ "$storage" == "LVM-Thick" ]]; then
            sudo qm move_disk 312 scsi0 $storage
            sudo lvremove -y /dev/pve/vm-312-disk-0
            sudo sed -i '/unused0/d' /etc/pve/qemu-server/312.conf
        fi
        sudo qm resize 312 scsi0 +"$LONGHORN_DISK_INCREASE"G
        sudo qm set 312 --scsi0 $storage:vm-312-disk-0,cache=writethrough
    fi

 if ping -c 1 -W 1 "${TEST_LONGHORN03_CIDR%/*}" &> /dev/null; then
        echo "IP ${TEST_LONGHORN03_CIDR%/*} is already in use!"
    else
        create_vm 313 "test-longhorn03" 4096 2 "$TEST_LONGHORN03_CIDR,gw=$ROUTER_GATEWAY"
        if [[ "$storage" == "LVM-Thick" ]]; then
            sudo qm move_disk 313 scsi0 $storage
            sudo lvremove -y /dev/pve/vm-313-disk-0
            sudo sed -i '/unused0/d' /etc/pve/qemu-server/313.conf
        fi
        sudo qm resize 313 scsi0 +"$LONGHORN_DISK_INCREASE"G
        sudo qm set 313 --scsi0 $storage:vm-313-disk-0,cache=writethrough
    fi

    echo "VMs are created. Please review their hardware settings manually."