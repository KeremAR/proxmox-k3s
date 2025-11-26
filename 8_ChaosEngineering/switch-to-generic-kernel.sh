#!/bin/bash

# Check if we are already on a generic kernel
CURRENT_KERNEL=$(uname -r)
if [[ "$CURRENT_KERNEL" == *"-generic"* ]]; then
  echo "✅ You are already running a generic kernel: $CURRENT_KERNEL"
  echo "You can verify the module with: sudo modprobe sch_netem"
  exit 0
fi

echo "⚠️  Current kernel is $CURRENT_KERNEL (likely KVM optimized)."
echo "🔄 Switching to generic kernel to support 'sch_netem' module..."

# Update and install generic kernel meta-packages
# linux-generic is the top-level meta-package that pulls the full kernel stack
sudo apt-get update
sudo apt-get install -y linux-generic

echo "✅ Generic kernel installed."
echo "🧹 Removing old KVM kernels to ensure we boot into the new one..."
# We remove the KVM specific packages so GRUB has no choice but to pick the generic one
sudo apt-get remove -y --purge linux-image-*-kvm linux-headers-*-kvm

echo "🔄 Updating GRUB..."
sudo update-grub

echo "✅ Switch complete."
echo "⚠️  A REBOOT IS REQUIRED."
echo "👉 Run 'sudo reboot' now."

