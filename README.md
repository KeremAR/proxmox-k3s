# Minimal Cloud-Native Homelab on K3s

This guide outlines the steps to configure a **minimal Cloud-Native homelab** on a single laptop using [Proxmox](https://www.proxmox.com) and [K3s](https://k3s.io). This setup focuses on resource efficiency and practical DevOps learning with only **2 VMs** instead of the original 9 VMs.

## 💻 Resource Requirements

**Minimal Setup (Optimized for Laptops):**
- **Proxmox Host**: Intel i5-8550u or equivalent
- **RAM**: 12GB total (3GB master + 7GB worker + 2GB hypervisor)
- **Storage**: 230GB total (30GB master + 185GB worker + hypervisor)
- **Network**: Single subnet (192.168.0.x/24)

**Original vs Minimal Comparison:**
| Resource | Original (9 VMs) | Minimal (2 VMs) | Savings |
|----------|------------------|------------------|---------|
| RAM      | 42GB            | 10GB            | **76%** |
| Storage  | 500GB+          | 230GB           | **54%** |
| VMs      | 9 VMs           | 2 VMs           | **78%** |

## 📋 Table of Contents

0. [Step 0: Optional Initial Proxmox Setup](#step-0-optional-initial-proxmox-setup)
1. [Step 1: Prepare Proxmox Credentials for K3s](#step-1-prepare-proxmox-credentials-for-k3s)
2. [Step 2: Create Minimal VM Infrastructure](#step-2-create-minimal-vm-infrastructure)
3. [Step 3: Deploy K3s Kubernetes Cluster](#step-3-deploy-k3s-kubernetes-cluster)

## 🚀 Quick Start

**For experienced users - one-liner setup:**
```bash
# Download and run setup scripts
curl -sO https://raw.githubusercontent.com/KeremAR/proxmox-k3s/main/0-1_ProxmoxSetup/0-1-Shortcut.sh && chmod +x 0-1-Shortcut.sh && ./0-1-Shortcut.sh
```

---

## Step 0: Optional Initial Proxmox Setup

This step is optional and assumes Proxmox is already installed. It involves setting up LVM for storage management and upgrading Proxmox.

1. **Create LVM**: Set up a partition on `/dev/sda` and create a volume group `LVM-Thick`.
2. **Backup Proxmox Configuration**: Back up the Proxmox storage configuration to `/etc/pve/storage.cfg.bak`.
3. **Add LVM Storage**: Modify `/etc/pve/storage.cfg` to include the new LVM storage.
4. **Upgrade Proxmox**: Update Proxmox to the latest version.

---

## Step 1: Prepare Proxmox Credentials for K3s

1. **Create a New User**: 1A. Add a `ubuntuprox` user with `sudo` privileges.
2. **Set Up SSH**: 1B. Generate SSH keys for `ubuntuprox` then download Scripts 2A-2D and make them executable.

---

## Step 2: Create Minimal VM Infrastructure

**🎯 Goal**: Create a 2-VM K3s cluster optimized for resource constraints.

### VM Architecture:
- **k3s-master** (192.168.0.101): 3GB RAM, 2 CPU, 30GB storage
- **k3s-worker** (192.168.0.102): 7GB RAM, 6 CPU, 185GB storage

### Scripts:
1. **2A**: Create Ubuntu VM template with cloud-init
2. **2B**: Create 2 VMs from template (modified for minimal setup)
3. **2C**: Start VMs and verify connectivity
4. **2D**: Copy SSH keys and prepare master VM for cluster setup

**Key Modifications from Original:**
- Reduced from 9 VMs to 2 VMs
- Eliminated Admin VM (master serves dual role)
- Removed Longhorn storage VMs (using local-path-provisioner)
- Single network subnet (192.168.0.x/24)

---

## Step 3: Deploy K3s Kubernetes Cluster

**🎯 Goal**: Install production-grade K3s cluster with LoadBalancer capabilities.

### Components Installed:
- **K3s v1.26.10+k3s2** (Kubernetes distribution)
- **MetalLB** (LoadBalancer for bare-metal)
- **Traefik** disabled (using Istio later)
- **Flannel CNI** (Container networking)

### Features:
- Single master node (no HA for resource efficiency)
- Worker node for all workloads
- MetalLB IP pool: 192.168.0.110-115
- Built-in storage: local-path-provisioner


---

## Step 4: Deploy Cloud-Native Infrastructure Services

**🎯 Goal**: Install essential infrastructure services for a production-ready Cloud-Native environment.

Navigate to the `4_CloudNative-Infrastructure/` directory and run the installation scripts:

### 4A. Install Nginx Ingress Controller
```bash
cd 4_CloudNative-Infrastructure/
./4A-install-nginx-ingress.sh
```
**Result**: Nginx Ingress Controller with LoadBalancer IP `192.168.0.111`

### 4B. Install ArgoCD GitOps Platform  
```bash
./4B-install-argocd.sh
```
**Result**: ArgoCD UI available at `http://192.168.0.112` with admin credentials


### Service Access Summary

| Service | IP Address | Access | Purpose |
|---------|------------|--------|---------|
| Nginx Ingress | 192.168.0.111 | HTTP/HTTPS | Application routing |
| ArgoCD | 192.168.0.112 | HTTP | GitOps platform |
| Available | 192.168.0.113-115 | - | Future services |

---

## 🔗 Next Steps

After completing this setup, you'll have:

- **Production-ready K3s cluster** with 2 nodes
- **HTTP/HTTPS ingress** for web applications  
- **GitOps platform** for declarative deployments
- **LoadBalancer services** with dedicated IPs
- **Foundation** for advanced Cloud-Native tools

**Learning Path:**
1. Deploy sample applications with ArgoCD
2. Set up monitoring with Prometheus + Grafana
3. Install Istio service mesh
4. Practice GitOps workflows
5. Explore advanced Kubernetes features

---

## 🤝 Contributing

This project is based on [benspilker/proxmox-k3s](https://github.com/benspilker/proxmox-k3s) but optimized for minimal resource usage and Cloud-Native DevOps learning.

**Original Credits:**
- [Ben Spilker](https://github.com/benspilker) - Original Proxmox K3s scripts
- [James Turland](https://github.com/JamesTurland) - K3s installation methodology

**Minimal Homelab Modifications:**
- [KeremAR](https://github.com/KeremAR) - Resource optimization and Cloud-Native stack

---

## 📜 License

This project is open source and available under the [MIT License](LICENSE).