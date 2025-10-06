# DevOps Todo Application - Comprehensive Infrastructure Project

![DevOps Pipeline](https://img.shields.io/badge/DevOps-Pipeline-blue)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?logo=kubernetes&logoColor=white)
![Helm](https://img.shields.io/badge/Helm-0F1689?logo=helm&logoColor=white)
![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-FF6B35)
![Jenkins](https://img.shields.io/badge/Jenkins-D33833?logo=jenkins&logoColor=white)

A comprehensive Todo application demonstrating modern DevOps practices. Features microservice architecture, multi-stage deployment, GitOps, CI/CD pipelines, and multiple deployment strategies.

## 📋 Table of Contents

- [Project Overview](#-project-overview)
- [Architecture](#-architecture)
- [Repository Structure](#-repository-structure)
- [Step-by-Step Setup Guide](#-step-by-step-setup-guide)
- [Deployment Strategy Comparison](#-deployment-strategy-comparison)
- [Pipeline Workflow Summary](#-pipeline-workflow-summary)
- [Configuration](#-configuration)
- [Development Workflow](#-development-workflow)
- [Contributing](#-contributing)


## 📋 Technology Summary

This project can progress through 6 different stages:

1. **🐳 Docker Compose** - Development environment
2. **☸️ Kubernetes** - Container orchestration
3. **⛵ Helm** - Package management + multi-environment
4. **🔧 Kustomize** - Helm alternative, overlay pattern
5. **🔄 Jenkins** - CI/CD pipeline
6. **🏃‍♂️ ArgoCD** - GitOps deployment

## 🚀 Project Overview

This project is a comprehensive infrastructure example that simulates real-world DevOps scenarios. It includes the following technologies and methodologies:

### 📱 Application Components
- **Frontend**: React 19 + Vite + TailwindCSS web interface
- **User Service**: FastAPI user management (auth, JWT, bcrypt)
- **Todo Service**: FastAPI todo operations with user authorization
- **Database**: SQLite (persistent volumes in K8s)
- **Container Registry**: GitHub Container Registry (ghcr.io)

### 🛠️ DevOps Tools
- **Container**: Docker & Docker Compose
- **Orchestration**: Kubernetes (Minikube)
- **Package Manager**: Helm Charts
- **Configuration Management**: Kustomize
- **CI/CD**: Jenkins with Shared Libraries
- **GitOps**: ArgoCD (App of Apps pattern)
- **Code Quality**: Pre-commit hooks, Hadolint, SonarQube
- **Security**: Trivy vulnerability scanning

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        LOAD BALANCER                           │
│                      (Ingress/Service)                         │
└─────────────────────┬───────────────────────┬───────────────────┘
                      │                       │
┌─────────────────────┴─────────────────────┐ │
│              FRONTEND                     │ │
│            (React App)                    │ │
│               Port: 3000                  │ │
└─────────────────────┬─────────────────────┘ │
                      │                       │
                      ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                    BACKEND SERVICES                            │
├─────────────────────┬───────────────────────────────────────────┤
│   USER SERVICE      │            TODO SERVICE                   │
│   (FastAPI)         │            (FastAPI)                     │
│   Port: 8001        │            Port: 8002                    │
│   - Authentication  │            - Todo CRUD                   │
│   - User Management │            - User Authorization          │
│   - JWT Tokens      │            - Service Communication       │
└─────────────────────┴───────────────────────────────────────────┘
```

## 📁 Repository Structure

This project consists of three main repositories:

### 🏗️ local_devops_infrastructure/ (Main Application Repository)
```
├── 🐳 docker-compose.yml               # Development environment
├── 🐳 docker-compose.test.yml          # Test environment
├── 📂 frontend2/frontend/              # Frontend (React)
├── 📂 user-service/                    # User service (FastAPI)
├── 📂 todo-service/                    # Todo service (FastAPI)
├── 📂 k8s/                             # Vanilla Kubernetes manifests
├── 📂 helm-charts/                     # Helm chart definitions
├── 📂 kustomize/                       # Kustomize overlays
├── 📄 Jenkinsfile                      # CI/CD pipeline definition
├── 📄 requirements.txt                 # Python dependencies
├── 📄 jenkins-values.yaml              # Jenkins Helm values
└── 📄 .pre-commit-config.yaml          # Code quality hooks
└── 📄 sonarqube-values.yaml            # SonarQube Helm values
```

### 📦 jenkins-shared-library2/ (Jenkins Shared Library Repository)
```
├── 📂 vars/                            # Jenkins Shared Library functions
│   ├── 📄 buildAllServices.groovy     # Parallel service build
│   ├── 📄 runUnitTests.groovy         # Test execution
│   ├── 📄 argoDeployStaging.groovy    # ArgoCD staging deploy
│   ├── 📄 argoDeployProduction.groovy # ArgoCD production deploy
│   └── ... (other shared functions)
├── 📂 src/com/company/jenkins/         # Utils and helper classes
│   └── 📄 Utils.groovy                # Jenkins utility functions
├── 📂 examples/                        # Example pipeline files
    └── 📄 Jenkinsfile-simple          # Simple Jenkinsfile example

```

### 🔄 todo-app-gitops/ (GitOps Repository)
```
└── 📂 argocd-manifests/                # ArgoCD Application definitions
    ├── 📄 root-application.yaml       # App of Apps root
    └── 📂 environments/                # Environment-specific apps
        ├── 📄 staging.yaml            # Staging application
        └── 📄 production.yaml         # Production application
```

## 🚀 Step-by-Step Setup Guide

This section shows how to set up the project step by step with different technologies. Each stage builds upon the previous one and adds new technologies.

### Prerequisites

- Docker & Docker Compose
- Git
- (For later stages) Minikube, kubectl, Helm, ArgoCD CLI

---

## 🐳 Stage 1: Development with Docker Compose

This is the simplest stage. No additional setup required.

### Setup

```bash
# Clone the project
git clone <repo-url>
cd jenkins-shared-library2/local_devops_infrastructure

# Start the application
docker compose up -d

# Follow logs
docker compose logs -f

# Check status
docker compose ps
```

### Test Environment

```bash
# Run test services
docker compose -f docker-compose.test.yml up --build

# Follow tests
docker compose -f docker-compose.test.yml logs -f

# Clean test images
docker compose -f docker-compose.test.yml down --rmi all
```

### Access URLs
- Frontend: http://localhost:3000
- User Service: http://localhost:8001
- Todo Service: http://localhost:8002
- API Docs: http://localhost:8001/docs and http://localhost:8002/docs

### Service Architecture

#### User Service (Port 8001)
- **Endpoints:** `/register`, `/login`, `/users/{id}`, `/admin/users`
- **Features:** JWT authentication, bcrypt password hashing, SQLite database
- **Health Check:** `/health`

#### Todo Service (Port 8002)  
- **Endpoints:** `/todos` (CRUD), `/admin/todos`
- **Features:** JWT validation, user-specific todos, SQLite database
- **Dependencies:** User Service for authentication
- **Health Check:** `/health`

#### Frontend (Port 3000)
- **Technology:** React 19 + Vite + TailwindCSS
- **Features:** Modern UI, responsive design, API integration
- **Build:** Production-optimized with Vite

### Cleanup

```bash
# Stop services
docker compose down

# Clean volumes as well
docker compose down -v

# Remove images too
docker compose down --rmi all
```

## ☸️ Stage 2: Deployment with Kubernetes

In this stage, we'll transition to Kubernetes using Minikube.

### Prerequisites
```bash
# Install Minikube (if not already installed)
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

### 1. Minikube Setup

```bash
# Start Minikube
minikube start

# Enable ingress addon (required for Nginx Ingress Controller)
minikube addons enable ingress

# Point Docker environment to Minikube
# This allows Docker builds to run directly in Minikube
eval $(minikube -p minikube docker-env)
```

### 2. Registry Secret Creation

```bash
# Create secret for GitHub Container Registry
# This secret is required to pull private images
kubectl create secret docker-registry github-registry-secret \
  --docker-server=ghcr.io \
  --docker-username=<GITHUB_USERNAME> \
  --docker-password=<GITHUB_TOKEN> \
  -n todo-app
```

**Note**: Your GitHub Token must have `packages` scope.

### 3. Kubernetes Manifests Deployment

```bash
# Apply all Kubernetes manifests
kubectl apply -f k8s/

# Check pod status
kubectl get pods -n todo-app

# Check service status
kubectl get services -n todo-app
```

**Important Note**: If you're adding new namespaces, you need to add rolebindings for those namespaces in `k8s/jenkins-rbac.yaml`. Otherwise, Jenkins agents cannot access those namespaces.

### 4. Hosts File Configuration

```bash
# Get Minikube IP
MINIKUBE_IP=$(minikube ip)

# Add to hosts file
echo "$MINIKUBE_IP todo-app.local" | sudo tee -a /etc/hosts
```

### 5. Access

Application access: http://todo-app.local

### Troubleshooting

```bash
# Check pod logs
kubectl logs -f deployment/user-service -n todo-app
kubectl logs -f deployment/todo-service -n todo-app
kubectl logs -f deployment/frontend -n todo-app

# Check ingress status
kubectl get ingress -n todo-app
kubectl describe ingress todo-app-ingress -n todo-app
```

---

## ⛵ Stage 3: Package Management with Helm

In this stage, we'll package the deployment using Helm and add multi-environment support.

### 1. Helm Installation

```bash
# Install Helm (if not already installed)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 2. Registry Secrets (For Helm)

Helm values require more complex secret management:

```bash
# Get Docker config in base64 format
cat ~/.docker/config.json | base64 | tr -d '\n'

# Save this value as `github-registry-dockerconfig` credential in Jenkins
```

### 3. Development Environment

```bash
# Basic Helm deployment
helm upgrade --install todo-app helm-charts/helm-todo-app \
  --namespace todo-app \
  --create-namespace \
  --wait
```

### 4. Staging Environment

```bash
# Create secret for staging namespace
kubectl create secret docker-registry github-registry-secret \
  --namespace=staging \
  --docker-server=ghcr.io \
  --docker-username=<GITHUB_USERNAME> \
  --docker-password=<GITHUB_TOKEN>

# Deploy staging environment
helm upgrade --install todo-app-staging helm-charts/helm-todo-app \
  --namespace staging \
  --create-namespace \
  -f helm-charts/helm-todo-app/values-staging.yaml \
  --wait
```

### 5. Production Environment

```bash
# Create secret for production namespace
kubectl create secret docker-registry github-registry-secret \
  --namespace=production \
  --docker-server=ghcr.io \
  --docker-username=<GITHUB_USERNAME> \
  --docker-password=<GITHUB_TOKEN>

# Deploy production environment
helm upgrade --install todo-app-prod helm-charts/helm-todo-app \
  --namespace production \
  --create-namespace \
  -f helm-charts/helm-todo-app/values-prod.yaml \
  --wait

# Add production hosts entry
echo "$(minikube ip) prod.todo-app.local" | sudo tee -a /etc/hosts
```

### 6. Helm Commands

```bash
# List all releases
helm list --all-namespaces

# Check release status
helm status todo-app -n todo-app

# Test template (for debugging)
helm template todo-app helm-charts/helm-todo-app

# Remove release
helm uninstall todo-app -n todo-app
```

---

## 🔧 Stage 4: Configuration Management with Kustomize

Kustomize can be used as an alternative to Helm. It uses base configuration + overlay pattern.

### 1. Kustomize Installation

```bash
# Install Kustomize
sudo snap install kustomize
```

### 2. Base Deployment

```bash
# Deploy base configuration
kubectl apply -k kustomize/base/

# Check resources
kubectl get all -n todo-app
```

### 3. Staging Overlay

```bash
# Deploy staging overlay
kubectl apply -k kustomize/overlays/staging/

# Check staging resources
kubectl get all -n staging
```

### 4. Production Overlay

```bash
# Deploy production overlay
kubectl apply -k kustomize/overlays/production/

# Check production resources
kubectl get all -n production
```

### 5. Kustomize Commands

```bash
# View build output (without applying)
kustomize build kustomize/base/
kustomize build kustomize/overlays/staging/

# Remove staging
kubectl delete -k kustomize/overlays/staging/

# Remove production
kubectl delete -k kustomize/overlays/production/
```

**Note**: When using Kustomize, you need to manually create secrets:

```bash
# Create secret for each namespace
kubectl create secret docker-registry github-registry-secret \
  --namespace=staging \
  --docker-server=ghcr.io \
  --docker-username=<GITHUB_USERNAME> \
  --docker-password=<GITHUB_TOKEN>
```

---

## 🔄 Stage 5: Jenkins CI/CD Pipeline

In this stage, we'll set up automatic CI/CD pipeline with Jenkins.

### 1. Jenkins Installation and Configuration

Install Jenkins with Helm:

```bash
# Create Jenkins namespace
kubectl create namespace jenkins

# Create Jenkins admin secret
kubectl create secret generic jenkins-admin-secret -n jenkins \
  --from-literal=jenkins-admin-user='admin' \
  --from-literal=jenkins-admin-password='YourStrongPassword123!'

# Install Jenkins with Helm
helm repo add jenkins https://charts.jenkins.io
helm repo update
helm install jenkins jenkins/jenkins -f jenkins-values.yaml -n jenkins --create-namespace

# Add JNLP port to Jenkins service (required for agent connection)
kubectl edit svc jenkins -n jenkins
# Add the following port:
#   - name: jnlp       
#     port: 50000
#     protocol: TCP
#     targetPort: 50000
```

### 2. Jenkins Plugins

Install the following plugins in Jenkins:
- **Kubernetes Credentials Provider** (for using Kubernetes secrets)
- **Basic Branch Build Strategies** (required for tag builds)
- **SonarQube Scanner** (for code quality analysis)

### 2.5. SonarQube Setup (Optional)

You can install SonarQube in two ways:

#### Option A: SonarQube with Docker

```bash
# Run SonarQube with Docker
docker pull sonarqube
docker run -d --name sonarqube -p 9000:9000 sonarqube

# Access SonarQube: http://192.168.49.1:9000
# Default: admin/admin
```

**SonarQube Configuration:**

1. Login to SonarQube
2. Create new project:
   - Project key: `Local-DevOps-Infrastructure`
   - Display name: `Local DevOps Infrastructure`
3. Create token: Administration > Security > Users > Tokens
4. Create webhook: Administration > Configuration > Webhooks
   - URL: `http://jenkins.jenkins.svc.cluster.local:8080/sonarqube-webhook/`

#### Option B: SonarQube with Helm

```bash
# Add SonarQube Helm repository
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update

# Install SonarQube
helm install sonarqube sonarqube/sonarqube -f sonarqube-values.yaml -n sonarqube --create-namespace

# Add to hosts file
echo "$(minikube ip) sonarqube.local" | sudo tee -a /etc/hosts

# Access SonarQube: http://sonarqube.local
```

**Jenkins SonarQube Integration:**

1. **Manage Jenkins > Tools > SonarQube Scanner installations:**
   - Name: `SonarQube-Scanner`
   - Install automatically: Yes

2. **Manage Jenkins > Configure System > SonarQube servers:**
   - Name: `sq1`
   - Server URL: `http://sonarqube.local` (Helm) or `http://192.168.49.1:9000` (Docker)
   - Authentication token: Token obtained from SonarQube

3. **Credentials > Global > Add Credential:**
   - Kind: Secret text
   - ID: `sonarqube-token`
   - Secret: SonarQube token value

### 3. Jenkins Credentials

Add the following in Jenkins > Manage Jenkins > Credentials:

```bash
# For GitHub registry (ID: github-registry)
# Username: <GITHUB_USERNAME>
# Password: <GITHUB_TOKEN> (packages scope)

# For GitHub webhook (ID: github-webhook)  
# Username: <GITHUB_USERNAME>
# Password: <GITHUB_TOKEN> (repo, hook scopes)

# For Docker config (ID: github-registry-dockerconfig)
cat ~/.docker/config.json | base64 | tr -d '\n'
# Save this output as "Secret text"
```

### 4. Jenkins Global Configuration

**Manage Jenkins > Configure System:**

```bash
# Global Pipeline Libraries
Name: todo-app-shared-library
Default version: master
Retrieval method: Modern SCM
Source Code Management: Git
Project Repository: <YOUR_SHARED_LIBRARY_REPO>

# Global properties (Environment variables)
ARGOCD_SERVER: argocd.todo-app.local

# SonarQube Servers (if using)
Name: sq1
Server URL: http://sonarqube.local
```

**Manage Jenkins > Tools:**

```bash
# SonarQube Scanner installations
Name: SonarQube-Scanner
Install automatically: Yes
```

### 5. Kubernetes Cloud Configuration

**Manage Jenkins > Clouds > Add Kubernetes:**

```bash
Kubernetes URL: https://kubernetes.default.svc
Kubernetes Namespace: jenkins
Credentials: kubernetes service account
```


```bash
# Create kubeconfig file (if needed)
kubectl config view --raw --minify > kubeconfig.yaml

# Add as "Secret file" in Jenkins
# However, this is not needed with modern Kubernetes plugin
```

### 6. Pipeline Job Creation

Create a Multibranch Pipeline job in Jenkins:

```bash
# Branch Sources
GitHub
Owner: <YOUR_GITHUB_USERNAME>
Repository: local-devops-infrastructure
Credentials: github-webhook

# Build Configuration
Script Path: Jenkinsfile

# Scan Repository Triggers
Periodically if not otherwise run: Yes
Interval: 1 minute

# Build Strategies
Regular branches: Any
Tags: Tags matching a pattern v*
```

---

## 🏃‍♂️ Stage 6: GitOps with ArgoCD

In this final stage, we'll set up GitOps workflow with ArgoCD.

### 1. ArgoCD Installation

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Install ArgoCD ingress
kubectl apply -f k8s/argocd-ingress.yaml

# Add to hosts file
echo "$(minikube ip) argocd.todo-app.local" | sudo tee -a /etc/hosts
```

### 2. ArgoCD Admin Access

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access ArgoCD via web: https://argocd.todo-app.local
# Username: admin
# Password: password obtained above
```

### 3. ArgoCD CLI Installation

```bash
# Download ArgoCD CLI
curl -SL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Login to ArgoCD
argocd login argocd.todo-app.local --insecure --grpc-web

# Create API token (required for Jenkins)
kubectl patch configmap/argocd-cm --type merge -p '{"data":{"accounts.admin":"apiKey"}}' -n argocd
argocd account generate-token
```

### 4. GitOps Repository Secrets

Create secrets for ArgoCD to pull images:

```bash
# For staging
kubectl create secret docker-registry github-registry-secret \
  --namespace=staging \
  --docker-server=ghcr.io \
  --docker-username=<GITHUB_USERNAME> \
  --docker-password=<GITHUB_TOKEN>

# For production
kubectl create secret docker-registry github-registry-secret \
  --namespace=production \
  --docker-server=ghcr.io \
  --docker-username=<GITHUB_USERNAME> \
  --docker-password=<GITHUB_TOKEN>
```

**Important Note**: The imagePullSecret creation feature in your Helm chart should be disabled because ArgoCD doesn't have access to Jenkins credentials. We created the secrets manually.

### 5. Jenkins ArgoCD Credentials

Add credentials for ArgoCD access in Jenkins:

```bash
# Credentials > Global > Add Credential
# ID: argocd-username, Value: admin
# ID: argocd-password, Value: <ARGOCD_ADMIN_PASSWORD>
```

### 6. Root Application Deployment

```bash
# Deploy GitOps root application
kubectl apply -f todo-app-gitops/argocd-manifests/root-application.yaml -n argocd
```

This command starts the App of Apps pattern and automatically creates staging/production applications.

### 7. Pipeline Test

Now you can test the complete GitOps workflow:

```bash
# Create feature branch
git checkout -b feature/test-pipeline
git push origin feature/test-pipeline

# Jenkins will run build + test

# Merge to master
git checkout master
git merge feature/test-pipeline
git push origin master

# Jenkins will deploy to staging

# Create production tag
git tag v1.0.0
git push origin v1.0.0

# Jenkins will deploy to production
```

### 8. ArgoCD Application Cleanup (if needed)

```bash
# Remove finalizers to clean all applications
kubectl patch application staging-todo-app -n argocd -p '{"metadata":{"finalizers":null}}' --type=merge
kubectl patch application production-todo-app -n argocd -p '{"metadata":{"finalizers":null}}' --type=merge
kubectl patch application root-app -n argocd -p '{"metadata":{"finalizers":null}}' --type=merge

# Clean namespaces
kubectl delete all --all -n staging
kubectl delete all --all -n production
```

---



## 🔄 Pipeline Workflow Summary

### Shared Library Functions
- `buildAllServices()` - Parallel service builds
- `runUnitTests()` - Parallel test execution
- `pushToRegistry()` - Docker registry push
- `deployWithHelm()` - Helm deployment
- `argoDeployStaging()` - ArgoCD staging sync
- `argoDeployProduction()` - ArgoCD production sync
- `runHadolint()` - Dockerfile linting
- `runTrivyScan()` - Security scanning

### Pipeline Flow
1. **Feature Branch** → Build + Test + Analysis
2. **Master Branch** → Registry Push + Staging Deploy
3. **Git Tag (v*)** → Production Deploy

### Pipeline Configuration

The pipeline is fully configurable via the `config` map in `Jenkinsfile`:

```groovy
def config = [
    appName: 'todo-app',
    services: [
        [name: 'user-service', dockerfile: 'user-service/Dockerfile'],
        [name: 'todo-service', dockerfile: 'todo-service/Dockerfile'],
        [name: 'frontend', dockerfile: 'frontend2/frontend/Dockerfile', context: 'frontend2/frontend/']
    ],
    // Registry and deployment settings
    registry: 'ghcr.io',
    username: 'keremar',
    // Choose your deployment strategy
    // helmReleaseName: 'todo-app',  // For Helm
    // argoCdStagingAppName: 'staging-todo-app',  // For GitOps
]
```

## 📊 Deployment Strategy Comparison

| Strategy | Best For | Pros | Cons |
|----------|----------|------|------|
| **Docker Compose** | Local development, testing | Quick setup, simple | Not production-ready |
| **K8s Manifests** | Learning, simple deployments | Full control, transparent | Verbose, hard to manage |
| **Helm** | Complex apps, multi-env | Templating, packaging | Learning curve, complexity |
| **Kustomize** | Environment variants | Declarative, patch-based | Limited templating |
| **GitOps/ArgoCD** | Production, compliance | Git-based, audit trail | Complex setup, git dependency |

## 🔧 Configuration

### Pre-commit Hooks
```bash
# Install pre-commit
pip install pre-commit

# Activate hooks
pre-commit install

# Run on all files
pre-commit run --all-files
```

### Jenkins Credentials
You need to define the following credentials in Jenkins:

- `github-registry`: For GitHub Container Registry
- `github-webhook`: For GitHub webhook (repo + hook scopes)
- `argocd-username`: ArgoCD username
- `argocd-password`: ArgoCD password
- `sonarqube-token`: SonarQube token (if using)

### Jenkins Global Properties
Define the following environment variable in Jenkins:
- `ARGOCD_SERVER`: argocd.todo-app.local



## 🔄 Development Workflow

### 🏠 Local Development
```bash
# Start development environment
docker compose up -d

# Make code changes

# Run tests
docker compose -f docker-compose.test.yml run --rm user-service-test
docker compose -f docker-compose.test.yml run --rm todo-service-test

# Check pre-commit hooks
pre-commit run --all-files
```

### 🌿 Feature Branch Workflow
```bash
# Create feature branch
git checkout -b feature/new-feature

# Push and create PR
git push origin feature/new-feature

# Jenkins automatically runs:
# build → test → security scan → staging deploy (on merge to master)
```

### 🚀 Production Release
```bash
# Create release tag
git tag v1.0.0
git push origin v1.0.0

# Jenkins automatically performs production deployment
# (skips build/test stages)
```

### 📋 Prerequisites Check

Before starting, verify:
- ✅ Docker and Docker Compose installed
- ✅ Kubernetes cluster (minikube) running
- ✅ kubectl configured
- ✅ Helm installed (for Helm deployments)
- ✅ Jenkins accessible with required plugins

## 🤝 Contributing

1. Fork this repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Create a Pull Request

## 📝 License

This project is licensed under the MIT License.

## 📞 Contact

Project Owner: Kerem AR
- GitHub: [@KeremAR](https://github.com/KeremAR)

---

**Note**: This project is for educational and demonstration purposes. Review security settings before using in production.