# Minimal Cloud-Native Homelab on K3s
This repository provides a streamlined set of scripts and instructions to set up a minimal Kubernetes (K3s) cluster on Proxmox VE, optimized for users with limited hardware resources. The setup focuses on deploying a lightweight yet functional Cloud-Native environment suitable for learning and experimentation.

## 🎯 Application Overview

**Todo App**: A microservices-based task management application demonstrating Cloud-Native architecture patterns.

**Architecture**:
- **user-service** (FastAPI): User authentication with JWT tokens, PostgreSQL storage, bcrypt password hashing
- **todo-service** (FastAPI): Todo CRUD operations with user verification, PostgreSQL storage, service-to-service validation
- **frontend** (React 18 + Vite): SPA with TailwindCSS, JWT-based auth, localStorage token management

**Decentralized JWT Verification**: Each service independently validates tokens using shared SECRET_KEY, eliminating single point of failure and reducing latency (no central auth service calls).

**Observability Stack**: 
- **Grafana Alloy** (DaemonSet): Unified collection agent replacing Promtail + Node Exporter + kube-state-metrics - scrapes pod/node logs and cluster metrics from all nodes
- **Loki**: Time-series log aggregation and storage - indexes logs by labels (namespace, pod) for fast querying
- **Prometheus**: Metrics storage and querying - stores time-series data (CPU, memory, network) with 7-day retention
- **Grafana**: Unified visualization - "Production Application Health" dashboard shows pod status (desired vs available replicas), CPU/memory usage graphs, and live log streams for all microservices

**Local Development**: `docker-compose up` (3 services + 2 databases on ports 8001, 8002, 3000)

## 📋 Table of Contents

0. [Step 0: Optional Initial Proxmox Setup](#step-0-optional-initial-proxmox-setup)
1. [Step 1: Prepare Proxmox Credentials for K3s](#step-1-prepare-proxmox-credentials-for-k3s)
2. [Step 2: Create Minimal VM Infrastructure](#step-2-create-minimal-vm-infrastructure)
3. [Step 3: Deploy K3s Kubernetes Cluster](#step-3-deploy-k3s-kubernetes-cluster)

## 📝 Setup Scripts

```bash
# Download and run setup scripts
curl -sO https://raw.githubusercontent.com/KeremAR/proxmox-k3s/main/0-1_ProxmoxSetup/0-1-Shortcut.sh && chmod +x 0-1-Shortcut.sh && ./0-1-Shortcut.sh
```
---

### 0. Optional Initial Proxmox Setup
- **0-Optional**: Setup LVM storage on `/dev/sda`, backup `/etc/pve/storage.cfg`, upgrade Proxmox

### 1. Prepare Proxmox Credentials
- **1A**: Add `ubuntuprox` user with sudo privileges
- **1B**: Generate SSH keys for `ubuntuprox`, download scripts 2A-2D

### 2. Create VM Infrastructure (k3s-master: 192.168.0.101, k3s-worker: 192.168.0.102)
- **2A**: Create Ubuntu VM template with cloud-init
- **2B**: Create 2 VMs from template (modified for minimal setup)
- **2C**: Start VMs and verify connectivity
- **2D**: Copy SSH keys and prepare master VM for cluster setup

**Key Modifications from Original:**
- Reduced from 9 VMs to 2 VMs
- Eliminated Admin VM (master serves dual role)
- Removed Longhorn storage VMs (using local-path-provisioner)
- Single network subnet (192.168.0.x/24)

### 3. Deploy K3s Cluster
- **3**: Install K3s v1.26.10 on master+worker, deploy MetalLB (192.168.0.110-115), verify with Nginx test app

### 4. Cloud-Native Infrastructure
- **4A**: Install Nginx Ingress Controller with LoadBalancer (192.168.0.111)
- **4B**: Install ArgoCD GitOps platform (argocd.192.168.0.111.nip.io)
- **4C**: Install Argo Rollouts for canary deployments (optional)

### 5. Deploy Application
- **5**: Deploy todo-app using Helm charts and ArgoCD Apps-of-Apps pattern (requires GitHub PAT)

### 6. Observability Stack (Optional)
- **6A**: Install Loki, Prometheus, Grafana, and Grafana Alloy (log + metric collector DaemonSet)
- **6B**: Create production health dashboard with CPU/memory metrics and live logs

### 7. CI/CD Pipeline
- **7A**: Install SonarQube with PostgreSQL for code quality scanning (admin/admin - generate token for Jenkins)
- **7B**: Install Jenkins with JCasC, multibranch pipeline, GitHub integration (requires GitHub PAT, SonarQube token, ArgoCD password)

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
