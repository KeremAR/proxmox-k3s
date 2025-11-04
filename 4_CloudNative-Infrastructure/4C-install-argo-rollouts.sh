#!/bin/bash

# ==============================================================================
# 4C - Install Argo Rollouts with RBAC
# ==============================================================================
# Purpose: Install Argo Rollouts for canary deployments with automatic rollback
# Features: Progressive delivery, traffic routing, health checks, rollback
# ==============================================================================

set -e

echo "🚀 Installing Argo Rollouts..."

# ==============================================================================
# STEP 1: Install Argo Rollouts Controller
# ==============================================================================
echo ""
echo "📦 Step 1: Installing Argo Rollouts controller..."

# Create namespace
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -

# Install Argo Rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Wait for controller to be ready
echo "⏳ Waiting for Argo Rollouts controller to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argo-rollouts -n argo-rollouts --timeout=120s

echo "✅ Argo Rollouts controller installed"

# ==============================================================================
# STEP 2: Install kubectl-argo-rollouts Plugin
# ==============================================================================
echo ""
echo "🔌 Step 2: Installing kubectl-argo-rollouts plugin..."

# Download plugin
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64

# Make executable
chmod +x ./kubectl-argo-rollouts-linux-amd64

# Move to system path
sudo mv ./kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts

# Verify installation
echo "✅ kubectl-argo-rollouts plugin installed"
kubectl argo rollouts version

# ==============================================================================
# STEP 3: Configure RBAC for Staging Namespace
# ==============================================================================
echo ""
echo "🔐 Step 3: Configuring RBAC for staging namespace..."

# Ensure staging namespace exists
kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -

# Create Role and RoleBinding for Ingress management
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: argo-rollouts-nginx-role
  namespace: staging
rules:
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: argo-rollouts-nginx-binding
  namespace: staging
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: argo-rollouts-nginx-role
subjects:
- kind: ServiceAccount
  name: argo-rollouts
  namespace: argo-rollouts
EOF

echo "✅ RBAC configured for staging namespace"

# ==============================================================================
# STEP 4: Configure RBAC for Production Namespace (Optional)
# ==============================================================================
echo ""
echo "🔐 Step 4: Configuring RBAC for production namespace..."

# Ensure production namespace exists
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -

# Create Role and RoleBinding for production
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: argo-rollouts-nginx-role
  namespace: production
rules:
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: argo-rollouts-nginx-binding
  namespace: production
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: argo-rollouts-nginx-role
subjects:
- kind: ServiceAccount
  name: argo-rollouts
  namespace: argo-rollouts
EOF

echo "✅ RBAC configured for production namespace"

# ==============================================================================
# Summary
# ==============================================================================
echo ""
echo "======================================================================"
echo "✅ Argo Rollouts Installation Complete!"
echo "======================================================================"
echo ""
echo "📦 Installed Components:"
kubectl get pods -n argo-rollouts
echo ""
echo "🔌 kubectl-argo-rollouts plugin version:"
kubectl argo rollouts version
echo ""
echo "🔐 RBAC Permissions:"
echo "   ✅ staging namespace: Ingress management enabled"
echo "   ✅ production namespace: Ingress management enabled"
echo ""
echo "📝 AnalysisTemplates:"
echo "   ℹ️  AnalysisTemplates are managed by Helm (in helm-charts/todo-app/templates/)"
echo "   ℹ️  They will be deployed via ArgoCD GitOps workflow"
echo ""
echo "🎯 Next Steps:"
echo "   1. Deploy app with Rollout resources (via ArgoCD)"
echo "   2. Monitor rollouts: kubectl argo rollouts get rollout <name> -n <namespace> --watch"
echo "   3. Trigger rollback: kubectl argo rollouts undo <name> -n <namespace>"
echo ""
echo "💡 Useful Commands:"
echo "   - Open Argo Rollouts dashboard in browser: kubectl argo rollouts dashboard"
echo "   - Watch rollout: kubectl argo rollouts get rollout <name> -n staging --watch"
echo "   - List rollouts: kubectl argo rollouts list rollouts -n staging"
echo "   - Get history: kubectl argo rollouts history <name> -n staging"
echo "   - Manual promote: kubectl argo rollouts promote <name> -n staging"
echo "   - Manual abort: kubectl argo rollouts abort <name> -n staging"
echo ""
