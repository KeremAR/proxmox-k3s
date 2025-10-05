#!/bin/bash
sudo -k

# Step 2C.1, Start VMs sequentially after creation - MODIFIED for 2 VM setup

# Please manually review the created VM settings before starting them

echo "Please manually review the created VM settings before starting them"
echo "Starting minimal K3s cluster VMs..."
echo ""

# Only start the 2 VMs we created (201: Master, 202: Worker)
for vm_id in 201 202; do
    echo "Starting VM $vm_id..."
    sudo qm start $vm_id
    sleep 5  # Wait 5 seconds between starts to avoid overload
done

echo ""
echo "=== MINIMAL K3S VMs STARTED ==="
echo "Started VMs:"
echo "  - VM 201 (k3s-master): 192.168.0.101"
echo "  - VM 202 (k3s-worker): 192.168.0.102"
echo ""
echo "Wait 1-2 minutes for VMs to fully boot, then continue to Script 2D."
echo ""

# Note these additional commands all need to be executed from Proxmox Shell (root or ubuntuprox), they won't work from the admin vm

# Note auto-start is not set on these VMs because they are for testing, but you may want to consider doing so

# Optional: Set auto-start order for the 2 VMs (uncomment if needed)
# order=1
# for vmid in 201 202; do
#    sudo qm set "$vmid" --onboot 1 --startup "order=$order"
#    ((order++))  # Increment the order for the next VM
# done

# Utility commands for managing the 2 VM setup:

# Gracefully shutdown both VMs if needed:
# for vm_id in 201 202; do
#     sudo qm shutdown $vm_id
# done

# Hard stop both VMs if needed:
# for vm_id in 201 202; do
#     sudo qm stop $vm_id
# done

# Delete both VMs if needed (CAUTION!):
# for vm_id in 201 202; do
#     sudo qm destroy $vm_id
# done