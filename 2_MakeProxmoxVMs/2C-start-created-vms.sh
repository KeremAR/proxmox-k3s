#!/bin/bash
sudo -k

# Step 2C.1, Start all the VMs sequentially after creation

# Please manually review the created VM settings before starting them

echo "Please manually review the created VM settings before starting them"

for vm_id in 200 201 202 203 204 205 211 212 213; do
    sudo qm start $vm_id
done

# Get a list of IP Addresses for all 9 VM's

extract_ip() {
  local var_name=$1
  local cidr=$(grep -oP "${var_name}=\"\K[0-9.]+/[0-9]+" 2B-make-vms-from-template.sh)
  local ip=${cidr%/24}
  echo "$cidr" "$ip"
}

read ADMIN_VM_CIDR ADMIN_VM_IP < <(extract_ip "ADMIN_VM_CIDR")
read TEST_K3S_01_CIDR TEST_K3S_01_IP < <(extract_ip "TEST_K3S_01_CIDR")
read TEST_K3S_02_CIDR TEST_K3S_02_IP < <(extract_ip "TEST_K3S_02_CIDR")
read TEST_K3S_03_CIDR TEST_K3S_03_IP < <(extract_ip "TEST_K3S_03_CIDR")
read TEST_K3S_04_CIDR TEST_K3S_04_IP < <(extract_ip "TEST_K3S_04_CIDR")
read TEST_K3S_05_CIDR TEST_K3S_05_IP < <(extract_ip "TEST_K3S_05_CIDR")
read TEST_LONGHORN01_CIDR TEST_LONGHORN01_IP < <(extract_ip "TEST_LONGHORN01_CIDR")
read TEST_LONGHORN02_CIDR TEST_LONGHORN02_IP < <(extract_ip "TEST_LONGHORN02_CIDR")
read TEST_LONGHORN03_CIDR TEST_LONGHORN03_IP < <(extract_ip "TEST_LONGHORN03_CIDR")

# Run a for each loop to apply updates to all VM's

for vm_ip in $ADMIN_VM_IP $TEST_K3S_01_IP $TEST_K3S_02_IP $TEST_K3S_03_IP $TEST_K3S_04_IP $TEST_K3S_05_IP $TEST_LONGHORN01_IP $TEST_LONGHORN02_IP $TEST_LONGHORN03_IP; do
    while true; do
        if ping -c 1 "$vm_ip" &> /dev/null; then
            echo "$vm_ip is up."
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -t -i ./.ssh/id_rsa ubuntu@"$vm_ip" \
            "sudo apt update && sudo apt full-upgrade -y [ -f /var/run/reboot-required ] && sudo reboot"
            break
        else
            echo "$vm_ip is not responding, retrying..."
            sleep 2
        fi
    done
done

# Note these additional commands all need to be executed from Proxmox Shell (root or ubuntuprox), they won't work from the admin vm

# Note auto-start is not set on these VMs because they are for testing, but you may want to consider doing so

# Loop through each VMID and set the startup order

# order=1
# for vmid in 200 201 202 203 204 205 211 212 213; do
#    sudo qm set "$vmid" --onboot 1 --startup "order=$order"
#    ((order++))  # Increment the order for the next VM
# done

# Commented out, but for reference, a step to gracefully shutdown all script created VMs if needed
# for vm_id in 200 201 202 203 204 205 211 212 213; do
#     sudo qm shutdown $vm_id
#done

# Commented out, but for reference, a step to hard stop all script created VMs if needed
# for vm_id in 200 201 202 203 204 205 211 212 213; do
#     sudo qm stop $vm_id
#done

# Commented out, but for reference, a step to delete all script created VMs if needed
# for vm_id in 200 201 202 203 204 205 211 212 213; do
#     sudo qm destroy $vm_id
#done