# Proxmox K3s Setup Guide

This guide outlines the steps to configure a Proxmox server for running a K3s Kubernetes cluster. It covers setting up Proxmox, preparing VMs, installing K3s, deploying Rancher, Installation of Nextcloud, and setting up Nextcloud with persistent storage.

Here is a visual representation of how K3s works:

<img src="https://k3s.io/img/how-it-works-k3s-revised.svg" width="800" />

K3s is a lightweight, simplified distribution of Kubernetes (K8s) designed for resource-constrained environments and edge computing, while K8s is a full-featured container orchestration platform optimized for large-scale, complex deployments. 
This makes K3s perfect for testing in a homelab.

---
## Prerequisite
 **A Proxmox Instance (preferably a fresh install)**: It’s best if your Proxmox instance has about 500 GB or more free, or 300GB minimum. You’ll also need about 42GB of RAM to allocate because we’ll have 9 VMs running. My proxmox instance has 48GB of RAM so we’ll have 42GB to allocate. You want to leave some for your hypervisior host.

## Table of Contents
[Proxmox K3s Setup Guide](#proxmox-k3s-setup-guide)

0. [Step 0: Optional Initial Proxmox Setup](#step-0-optional-initial-proxmox-setup)
1. [Step 1: Prepare Proxmox Credentials for K3s](#step-1-prepare-proxmox-credentials-for-k3s)
2. [Step 2: Prepare Proxmox VMs for K3s Cluster](#step-2-prepare-proxmox-vms-for-k3s-cluster)
3. [Step 3: Installing K3s on Nodes](#step-3-installing-k3s-on-nodes)
4. [Step 4: Install Rancher UI and Tools](#step-4-install-rancher-ui-and-tools)
5. [Step 5: DNS Setup and Test Nextcloud Install](#step-5-dns-setup-and-test-nextcloud-install)
6. [Step 6: Nextcloud Install with MySQL and Persistent Storage](#step-6-nextcloud-install-with-mysql-and-persistent-storage)

---
##
Code to copy for shortcut script:
   ```bash
   curl -sO https://raw.githubusercontent.com/benspilker/proxmox-k3s/main/0-1_ProxmoxSetup/0-1-Shortcut.sh && chmod +x 0-1-Shortcut.sh && ./0-1-Shortcut.sh
   ```
## Shortcut Added in 0-1 Folder
This shortcut script prompts the user to start with either the optional Script 0 or 1A.

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

## Step 2: Prepare Proxmox VMs for K3s Cluster

1. **Create VM Template**: Create an Ubuntu-based VM template with necessary resources (e.g., 4GB RAM, 2 CPU cores, SSH key setup).
2. **Create VMs for K3s Cluster**: Create multiple VMs to serve as K3s nodes.
3. **Start Created VMs**: Manually review them before starting
4. **Copy SSH Keys and Additional Scripts**: Check for VM updates, apply them, and reboot VMs? Copy SSH key to Admin VM, download Scripts 3-6 and make them executable.

Note all scripts from this point forward will be executed on the Admin VM
---

## Step 3: Installing K3s on Nodes

1. **Define Cluster Variables**: Set up the necessary variables, such as K3s and Kube-VIP versions, and define node IPs.
2. **Prepare Admin Machine**: Ensure SSH keys are configured and required tools (`k3sup`, `kubectl`) are installed.
3. **Bootstrap First K3s Node**: Use `k3sup` to install K3s on the first master node.
4. **Install Kube-VIP for High Availability**: Deploy Kube-VIP for high availability and configure a virtual IP (VIP) for the K3s API.
5. **Join Additional Nodes**: Add more master and worker nodes to the cluster as needed.
6. **Install MetalLB**: Set up MetalLB to manage LoadBalancer services for K3s.

---

## Step 4: Install Rancher UI and Tools

1. **Install Helm**: Ensure Helm is installed on the admin VM.
2. **Add Rancher Helm Repo**: Add the Rancher Helm chart repository.
3. **Install Cert Manager**: Set up Cert Manager to handle SSL/TLS certificates.
4. **Install Rancher and Traefik**: Install Rancher using Helm, install Traefik for ingress management, and expose Rancher via a LoadBalancer for UI access
5. **Install Longhorn**: Manually login to Rancher WebUI and install Longhorn for persistent storage

---

## Step 5: DNS Setup and Test Nextcloud Install

1. **Setup DNS and Resolve Domain**: (5A) Setup of DNS Server and ensure the Nextcloud domain is correctly resolved to the soon to be Ingress IP.
2. **Failsafe Longhorn Script Install**: (5A) If Longhorn was not manually installed After Script 4, Script 5A will automatically install it.
3. **Test Nextcloud Install**: (5B) Deploy Nextcloud using Helm in its own Kubernetes namespace.
4. **Test Self-Signed Certificate Creation**: (5B) Generate a self-signed certificate for HTTPS access to Nextcloud.
5. **Test Ingress**: (5B) Create and apply an Ingress resource to expose Nextcloud via HTTPS.
6. **Test Login** (5B) Test at https://nextcloud.yourexampledomain.com (or whatever you define as your domain name)
---

## Step 6: Nextcloud Install with MySQL and Persistent Storage

0. **Delete Current Nextcloud Deployment**: (6.0) Remove any existing Nextcloud deployment. Delete and recreate nextcloud namespace to prepare for new database and persistent storage.
1. **Create Nextcloud init pod**: (6.1) Install Nextcloud as init instance to get config file template
2. **Install MariaDB using Helm**: (6.2A-B) Create MariaDB MySQL instance with new database called nextcloud and user nextcloud
3. **Persistent Storage for Config and Data** (6.3) Create and Deploy Persistent Volume Claims with temp pod
4. **Config file template Copy** (6.4A-B) Copy config from init pod to Admin VM, then copy to temp pod PVC, then delete temp pod
5. **Nextcloud Re-Install**: (6.5A-B) Get init deployment in YAML, then create a new YAML deployment file with customized persistent volume settings, delete current nextcloud deployment and reapply with persistent storage containing config file
6. **Modification of default database to use MySQL**: (6.6) Removal of default deployment sqlite3 database and connection to MariaDB MySQL
7. **Self-Signed Certificate Creation**: (6.7) Generate a self-signed certificate for HTTPS access to Nextcloud.
8. **Define Ingress**: (6.8) Create and apply an Ingress resource to expose Nextcloud via HTTPS.
9. **Adjust Config**: (6.9) Modify Nextcloud config file to correct trusted domain issue.
10. **Backup Configuration and Deployment**: (6.10) Copy config directory and deployment yaml to local folder**
11. **Finally Login** Login to https://nextcloud.yourexampledomain.com  (or whatever you define as your domain name)
---

This completes the setup for Nextcloud with persistent storage and a fully functioning K3s cluster in a Proxmox environment.