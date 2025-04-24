#!/bin/bash
sudo -k

# Step 2C.1, Start all the VMs sequentially after creation

# Please manually review the created VM settings before starting them

echo "Please manually review the created VM settings before starting them"

for vm_id in 200 201 202 203 204 205 211 212 213; do
    sudo qm start $vm_id
done

echo ""
echo "VMs were started. Continue to Script 2D."
echo ""

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