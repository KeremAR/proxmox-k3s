# Proxmox K3s Setup Guide

This guide outlines the steps to configure a Proxmox server for running a K3s Kubernetes cluster. It covers setting up Proxmox, preparing VMs, installing K3s, deploying Rancher, Installation of Nextcloud, and setting up Nextcloud with persistent storage.

Here is a visual representation of how K3s works:

<img src="https://k3s.io/img/how-it-works-k3s-revised.svg" width="800" />

K3s is a lightweight, simplified distribution of Kubernetes (K8s) designed for resource-constrained environments and edge computing, while K8s is a full-featured container orchestration platform optimized for large-scale, complex deployments. 
This makes K3s perfect for testing in a homelab.

---

## Table of Contents
[Proxmox K3s Setup Guide](#proxmox-k3s-setup-guide)

0. [Step 0: Optional Initial Proxmox Setup](#step-0-optional-initial-proxmox-setup)
1. [Step 1: Prepare Proxmox Credentials for K3s](#step-1-prepare-proxmox-credentials-for-k3s)
2. [Step 2: Prepare Proxmox VMs for K3s Cluster](#step-2-prepare-proxmox-vms-for-k3s-cluster)
3. [Step 3: Installing K3s on Nodes](#step-3-installing-k3s-on-nodes)
4. [Step 4: Install Rancher UI and Tools](#step-4-install-rancher-ui-and-tools)
5. [Step 5: Install Nextcloud Instance](#step-5-install-nextcloud-instance)
6. [Step 6: Persistent Volume Storage for Nextcloud](#step-6-persistent-volume-storage-for-nextcloud)

---
## Shortcut Added in 0-1 Folder
This is a shortcut script you can copy and paste into the Proxmox shell.
It prompts the user to start with either the optional Script 0 or 1A.

## Step 0: Optional Initial Proxmox Setup

This step is optional and assumes Proxmox is already installed. It involves setting up LVM for storage management and upgrading Proxmox.

1. **Create LVM**: Set up a partition on `/dev/sda` and create a volume group `LVM-Thick`.
2. **Backup Proxmox Configuration**: Back up the Proxmox storage configuration to `/etc/pve/storage.cfg.bak`.
3. **Add LVM Storage**: Modify `/etc/pve/storage.cfg` to include the new LVM storage.
4. **Upgrade Proxmox**: Update Proxmox to the latest version.

---

## Step 1: Prepare Proxmox Credentials for K3s

1. **Create a New User**: Add a `ubuntuprox` user with `sudo` privileges.
2. **Set Up SSH**: Generate SSH keys for `ubuntuprox` and copy them to the admin VM for access.

---

## Step 2: Prepare Proxmox VMs for K3s Cluster

1. **Create VM Template**: Create an Ubuntu-based VM template with necessary resources (e.g., 4GB RAM, 2 CPU cores, SSH key setup).
2. **Create VMs for K3s Cluster**: Create multiple VMs to serve as K3s nodes.
3. **Start Created VMs**: Manually review them before starting
4. **Copy SSH Keys and Additional Scripts**: Ensure SSH keys are copied to Admin VM and Scripts 3-6 are copied and executable.

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

## Step 5: Install Nextcloud Instance

1. **Setup DNS and Resolve Domain**: Setup of DNS Server and ensure the Nextcloud domain is correctly resolved to the soon to be Ingress IP.
2. **Install Nextcloud**: Deploy Nextcloud using Helm in its own Kubernetes namespace.
3. **Create Self-Signed Certificate**: Generate a self-signed certificate for HTTPS access to Nextcloud.
4. **Define Ingress**: Create and apply an Ingress resource to expose Nextcloud via HTTPS.

---

## Step 6: Persistent Volume Storage for Nextcloud

1. **Delete Current Nextcloud Deployment**: Remove any existing Nextcloud deployment to prepare for persistent storage.
2. **Create Persistent Volume Claims**: Define and apply Persistent Volume Claims for Nextcloud's data.
3. **Copy Configuration to Persistent Volume**: Transfer the Nextcloud configuration to the persistent storage.
4. **Deploy Nextcloud with Persistent Storage**: Apply the new Nextcloud deployment configuration with persistent storage.
5. **Set Permissions**: Adjust the permissions on Nextcloud's configuration and data folders.

---

This completes the setup for Nextcloud with persistent storage and a fully functioning K3s cluster on Proxmox.