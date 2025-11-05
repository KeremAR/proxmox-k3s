# Minimal Cloud-Native Homelab on K3s

This repository provides a streamlined set of scripts and instructions to set up a minimal Kubernetes (K3s) cluster on Proxmox VE, optimized for users with limited hardware resources. The setup focuses on deploying a lightweight yet functional Cloud-Native environment suitable for learning and experimentation.

---

## 🚀 Core Components

This project demonstrates a complete end-to-end, microservices-based application with a full CI/CD and observability stack.

### 🎯 Todo Application

A simple task management application built on a microservices architecture.

*   **`user-service` (FastAPI)**: Handles user authentication with JWT tokens.
    *   *Storage*: PostgreSQL
    *   *Security*: `bcrypt` for password hashing.
*   **`todo-service` (FastAPI)**: Manages CRUD operations for tasks.
    *   *Storage*: PostgreSQL
    *   *Security*: Validates user identity via JWT tokens passed from the frontend.
*   **`frontend` (React 18 + Vite)**: A modern single-page application.
    *   *Styling*: TailwindCSS
    *   *Auth*: JWT-based authentication with tokens stored in `localStorage`.
*   **Decentralized JWT Verification**: Each backend service independently validates JWTs using a shared secret key. This eliminates the need for a central authentication service, reducing latency and removing a single point of failure.
*   **Local Development**: Run the entire stack locally with `docker-compose up`.

### 🔭 Observability Stack

A lightweight but powerful stack for monitoring and logging.

*   **Grafana Alloy (DaemonSet)**: A unified collection agent that replaces the need for Promtail, Node Exporter, and kube-state-metrics. It scrapes logs and metrics from all nodes in the cluster.
*   **Loki**: Aggregates and stores logs, indexing them with Kubernetes labels for efficient querying.
*   **Prometheus**: Stores time-series metrics (CPU, memory, etc.) with a 7-day retention period.
*   **Grafana**: Provides a unified visualization layer. Includes a pre-built "Production Application Health" dashboard to monitor pod status, resource usage, and live log streams.

### 🔄 CI/CD Pipeline

A robust pipeline built with Jenkins, SonarQube, and ArgoCD, following GitOps principles.

*   **Jenkins Configuration as Code (JCasC)**: Jenkins is automatically configured with plugins, credentials, and a multibranch pipeline job.
*   **Dynamic Kubernetes Agents**: Pipeline jobs run in ephemeral pods, each containing the necessary tools (`jnlp`, `docker-dind`, `argo`, etc.). Persistent caches are used to speed up builds.
*   **Pipeline Flows**:
    1.  **Validation (Pull Requests & Feature Branches)**:
        *   Linting (`flake8`, `black`, `hadolint`)
        *   Security Scans (`Trivy` for secrets, IaC, and dependencies)
        *   Unit Tests & SonarQube Quality Gate
        *   Build & Scan Container Images (`Trivy`)
        *   Integration Tests (`docker-compose`)
    2.  **Staging (on merge to `main`)**:
        *   All validation steps are executed.
        *   Images are pushed to GitHub Container Registry (GHCR).
        *   Deployment to the `staging` environment is triggered via GitOps.
        *   E2E tests and a non-blocking OWASP ZAP DAST scan are run against the staging environment.
    3.  **Production (on `v*` tags)**:
        *   The staging image is promoted to production by updating the GitOps repository.
        *   ArgoCD syncs the changes to the `production` environment.
*   **Shift-Left Security**: Security is integrated at every step, including Trivy scans (secrets, IaC, dependencies, images), SonarQube quality gates, and OWASP ZAP scans.
*   **Shared Library**: Over 20 custom, reusable Groovy functions power the pipeline, keeping the `Jenkinsfile` clean and declarative.

### 🤖 GitOps with ArgoCD

Deployments are managed declaratively using the GitOps model.

*   **App-of-Apps Pattern**: A `root-application.yaml` in ArgoCD monitors the `environments/` directory in the GitOps repo. It automatically creates child applications (`staging.yaml`, `production.yaml`) for each environment.
*   **Automated Sync**: Any merge to the GitOps repository's main branch triggers an immediate reconciliation in the corresponding cluster environment.
*   **Separate GitOps Repo**: Application code and deployment manifests are kept in separate repositories for better separation of concerns.

###  canary Progressive Delivery with Argo Rollouts

Advanced deployment strategies are used to minimize risk.

*   **Rollout Resources**: Standard `Deployment` objects are replaced with Argo `Rollout` custom resources.
*   **Canary Strategy**: A multi-step canary release process gradually shifts traffic to the new version (e.g., 20% → 40% → 60% → 100%).
*   **Automated Analysis**: Between steps, `AnalysisTemplate` resources run automated health checks. If a check fails, the rollout is automatically aborted and rolled back.
*   **Manual Promotion**: The rollout pauses for manual verification before proceeding with further traffic shifting, giving you full control over the release.

### ☸️ Kubernetes & Helm Configuration

The entire application stack is packaged as a single, configurable Helm chart located in `helm-charts/todo-app`.

*   **Core Components Deployed by Helm**:
    *   **Application Services**: The `frontend`, `user-service`, and `todo-service` are deployed as Argo `Rollout` resources.
    *   **Databases**: Two PostgreSQL instances (`user-db` and `todo-db`) are deployed as `StatefulSet`s to ensure persistent data and stable network identities.
    *   **Networking**: Each component gets a `ClusterIP` service for internal communication, and an `Ingress` resource exposes the application externally.
    *   **Configuration**: A `ConfigMap` is used to manage the `Caddyfile` for the frontend's internal reverse proxy.

*   **Environment-Specific Configuration**:
    *   The chart uses a layered approach for configuration. The base `values.yaml` provides defaults.
    *   `values-staging.yaml` and `values-prod.yaml` override the defaults for specific environments, allowing for different resource limits, replica counts, and ingress hostnames.
    *   Image tags are intentionally not defined in these files. They are passed in by the ArgoCD `Application` manifests, following GitOps best practices.

*   **Frontend Internal Reverse Proxy**:
    *   The `frontend` pod runs a Caddy webserver that does more than just serve static files. It also acts as an internal reverse proxy, routing API calls from the web UI to the correct backend services (`user-service` or `todo-service`). This simplifies Ingress configuration and keeps routing logic coupled with the frontend.

---

## 📖 Table of Contents

> *   [Step 0: Optional Initial Proxmox Setup](#-step-0-optional-initial-proxmox-setup)
> *   [Step 1: Prepare Proxmox Credentials](#-step-1-prepare-proxmox-credentials)
> *   [Step 2: Create Minimal VM Infrastructure](#-step-2-create-vm-infrastructure)
> *   [Step 3: Deploy K3s Kubernetes Cluster](#-step-3-deploy-k3s-cluster)
> *   [Step 4: Deploy Cloud-Native Infrastructure](#-step-4-cloud-native-infrastructure)
> *   [Step 5: Deploy The Application](#-step-5-deploy-application)
> *   [Step 6: Install The Observability Stack](#-step-6-observability-stack-optional)
> *   [Step 7: Set Up The CI/CD Pipeline](#-step-7-cicd-pipeline)

---

## ⚡ Quick Start

To download and run all setup scripts in one go, use the shortcut script:

```bash
# Download and execute the setup shortcut
curl -sO https://raw.githubusercontent.com/KeremAR/proxmox-k3s/main/0-1_ProxmoxSetup/0-1-Shortcut.sh
chmod +x 0-1-Shortcut.sh
./0-1-Shortcut.sh
```

---

## 🛠️ Step-by-Step Guide

### 0. Optional Initial Proxmox Setup
*   **`0-Optional-proxmox-initial-setup.sh`**: Configures LVM storage, backs up storage configuration, and upgrades Proxmox.

### 1. Prepare Proxmox Credentials
*   **`1A-init-proxmox-credentials-make-user.sh`**: Adds a `ubuntuprox` user with `sudo` privileges.
*   **`1B-init-proxmox-credentials-make-ssh-keys.sh`**: Generates SSH keys for the new user and prepares for the next steps.

### 2. Create VM Infrastructure
*   **`2A-make-vm-template.sh`**: Creates a minimal Ubuntu VM template with `cloud-init`.
*   **`2B-make-vms-from-template.sh`**: Clones two VMs from the template:
    *   `k3s-master` (`192.168.0.101`)
    *   `k3s-worker` (`192.168.0.102`)
*   **`2C-start-created-vms.sh`**: Starts the VMs.
*   **`2D-copy-ssh_creds.sh`**: Copies SSH keys to the master VM.

> **Note**: This setup is heavily optimized, reducing the original 9 VMs to just 2 and using `local-path-provisioner` instead of Longhorn for storage.

### 3. Deploy K3s Cluster
*   **`3-install-k3s-from-JimsGarage.sh`**: Installs K3s (`v1.26.10`) on both nodes and deploys MetalLB for BareMetal LoadBalancing (IP Range: `192.168.0.110-115`).

### 4. Cloud-Native Infrastructure
*   **`4A-install-nginx-ingress.sh`**: Installs NGINX Ingress Controller with a `LoadBalancer` service.
*   **`4B-install-argocd.sh`**: Installs the ArgoCD GitOps platform.
*   **`4C-install-argo-rollouts.sh`**: Installs Argo Rollouts for progressive delivery.

### 5. Deploy Application
*   **`5-deploy-app.sh`**: Deploys the `todo-app` using the ArgoCD App-of-Apps pattern.

### 6. Observability Stack (Optional)
*   **`6A-install-alloy-observability.sh`**: Installs Loki, Prometheus, Grafana, and Grafana Alloy.
*   **`6B-create-production-dashboard.sh`**: Creates the production health dashboard in Grafana.

### 7. CI/CD Pipeline
*   **`7A-sonarqube.sh`**: Installs SonarQube with a PostgreSQL database.
*   **`7B-jenkins.sh`**: Installs Jenkins using JCasC and creates the multibranch pipeline.

---

## 🤝 Contributing & Credits

This project is based on the work of [benspilker/proxmox-k3s](https://github.com/benspilker/proxmox-k3s) but has been significantly modified for resource optimization and to serve as a learning platform for Cloud-Native technologies.

*   **Original Proxmox K3s Scripts**: [Ben Spilker](https://github.com/benspilker)
*   **K3s Installation Methodology**: [James Turland](https://github.com/JamesTurland)
*   **Minimal Homelab & Cloud-Native Stack**: [KeremAR](https://github.com/KeremAR)

---

## 📜 License

This project is open source and available under the [MIT License](LICENSE).
