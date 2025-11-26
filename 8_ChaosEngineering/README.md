# LitmusChaos Network Latency Experiment Setup

This directory contains the setup for running Network Latency chaos experiments on a K3s cluster running on Proxmox/Ubuntu.

## ⚠️ Critical Prerequisite: Kernel Compatibility

The standard Ubuntu Cloud images for KVM (`linux-image-kvm`) are optimized for size and **do not** include the `sch_netem` kernel module, which is required for network emulation (latency, packet loss, etc.).

If you try to run the experiment on a KVM kernel, you will see this error:
> `HELPER_ERROR: failed to create tc rules: Error: Specified qdisc kind is unknown.`

### Solution: Switch to Generic Kernel

We must switch both the **Master** and **Worker** nodes to the standard Ubuntu `generic` kernel.

**Automated Script:**
Run the included script on **ALL** nodes (Master and Workers):

```bash
chmod +x switch-to-generic-kernel.sh
./switch-to-generic-kernel.sh
```

**What this script does:**
1. Installs `linux-generic` (complete kernel stack).
2. Removes conflicting `linux-image-*-kvm` packages to force GRUB to use the new kernel.
3. Updates GRUB.

**After running the script, you MUST reboot:**
```bash
sudo reboot
```

**Verification:**
After reboot, check the kernel version:
```bash
uname -r
# Output should end with "-generic", e.g., "5.15.0-161-generic"
```
Check if the module can be loaded:
```bash
sudo modprobe sch_netem
# Should return no error
```

## Experiment Configuration

The `pod-network-latency-workflow.yaml` has been configured with the following essential settings for K3s:

*   **Socket Path:** `/run/k3s/containerd/containerd.sock` (Required for K3s)
*   **Container Runtime:** `containerd`
*   **Privileged Mode:** `true` (Required for network manipulation)
*   **Capabilities:** `NET_ADMIN`, `SYS_ADMIN`
*   **TC Image:** `gaiadocker/iproute2` (Provides the `tc` command)

## Running the Experiment

Once the kernel is updated on all nodes, run the experiment using the setup script:

```bash
./8B-setup-experiment.sh pod-network-latency-workflow.yaml
```
