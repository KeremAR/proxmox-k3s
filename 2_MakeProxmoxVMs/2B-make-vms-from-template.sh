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

# Step 2B.1 Defining disk space sizing - MODIFIED for 2 VM setup
# Original setup: 9 VMs requiring ~500GB and 42GB RAM
# Modified setup: 2 VMs requiring ~220GB and 10GB RAM (optimized for 12GB total RAM system)

# We need to define how much disk space will be used

# Master VM (k3s-master): 30GB disk, 3GB RAM, 2 CPU cores
# Worker VM (k3s-worker): 185GB disk, 7GB RAM, 6 CPU cores
# Total: ~215GB disk usage (well within 413GB available)

# No Longhorn VMs needed - using local-path-provisioner instead
# No Admin VM needed - managing from Master VM directly

# LONGHORN_DISKSIZE removed - not using Longhorn for this minimal setup


# Step 2B.2 Define local gateway and VM IP's

# NOTE YOU NEED TO SET IPs and Gateway accordingly for all VMs
# You can make them DHCP and make reservations on DHCP server, but note that mac addresses will change with each deployment
# Assigning static IP's in an area outside of dhcp may be a better method (at least it was for me)

# IP of your router - UPDATED for your network
ROUTER_GATEWAY="192.168.0.1"  # Your actual gateway

# Set your VM IPs and make sure they are available IPs on your network
# Make sure they are listed in CIDR format, ie /24 with quotes ""
# MODIFIED: Only 2 VMs instead of 9

# No Admin VM - managing directly from Master VM
# ADMIN_VM_CIDR="192.168.0.90/24"  # Removed

# Only 2 VMs for minimal K3s cluster
TEST_K3S_01_CIDR="192.168.0.101/24"  # Master Node (K3s Server + kubectl management)
TEST_K3S_02_CIDR="192.168.0.102/24"  # Worker Node (All workloads: Rancher, ArgoCD, etc.)

# Removed additional controller VMs (202, 203) - not needed for single master setup
# Removed worker VMs (204, 205) - using single powerful worker instead  
# Removed Longhorn VMs (211-213) - using local-path-provisioner instead


#####################################################################################


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


# Creating individual VMs for the cluster - MODIFIED for 2 VM setup

# Step 2B.4, No Admin VM - managing directly from Master VM
# Original Admin VM (200) removed - kubectl and management tools will be on Master VM

# Step 2B.5, Single K3S Master/Controller (VM 201)
echo "Creating Master VM (201) - K3s Server + Management"
 if ping -c 1 -W 1 "${TEST_K3S_01_CIDR%/*}" &> /dev/null; then
        echo "IP ${TEST_K3S_01_CIDR%/*} is already in use!"
    else
        create_vm 201 "k3s-master" 3072 2 "$TEST_K3S_01_CIDR,gw=$ROUTER_GATEWAY"
        # Resize master VM disk to 30GB total (8GB base + 22GB)
        sudo qm resize 201 scsi0 +22G
    fi

# Step 2B.6, Single K3S Worker (VM 202) - All workloads will run here
echo "Creating Worker VM (202) - All Applications & Services"
 if ping -c 1 -W 1 "${TEST_K3S_02_CIDR%/*}" &> /dev/null; then
        echo "IP ${TEST_K3S_02_CIDR%/*} is already in use!"
    else
        create_vm 202 "k3s-worker" 7168 6 "$TEST_K3S_02_CIDR,gw=$ROUTER_GATEWAY"
        # Resize worker VM disk to 185GB total for all applications (8GB base + 177GB)
        if [[ "$storage" == "LVM-Thick" ]]; then
            sudo qm move_disk 202 scsi0 $storage
            sudo lvremove -y /dev/pve/vm-202-disk-0
            sudo sed -i '/unused0/d' /etc/pve/qemu-server/202.conf
        fi
        sudo qm resize 202 scsi0 +177G
        sudo qm set 202 --scsi0 $storage:vm-202-disk-0,cache=writethrough
    fi

# Removed additional controllers (202, 203) - single master sufficient for homelab


# Step 2B.7, Additional workload VMs - REMOVED for minimal setup
# Original setup had 2 additional worker VMs (204, 205) - not needed
# Single powerful worker VM (202) with 7GB RAM and 6 CPU cores handles all workloads

# Step 2B.8, Longhorn storage VMs - REMOVED for minimal setup  
# Original setup had 3 Longhorn VMs (211-213) for distributed storage
# Using local-path-provisioner instead (built into K3s) for single-node storage
# This saves ~12GB RAM and ~384GB disk space
    
echo ""
echo "=== MINIMAL K3S SETUP COMPLETE ==="
echo "Created 2 VMs optimized for 12GB RAM system:"
echo "  - VM 201 (k3s-master): 3GB RAM, 2 CPU, 30GB disk"  
echo "  - VM 202 (k3s-worker): 7GB RAM, 6 CPU, 185GB disk"
echo ""
echo "Total resource usage:"
echo "  - RAM: 10GB (leaving 2GB for Proxmox host)"
echo "  - Disk: ~215GB (well within 413GB available)"
echo ""
echo "Please review their hardware settings manually then continue to Script 2C."