#!/bin/bash

# ==============================================================================
# 4B - Install ArgoCD with LoadBalancer  
# ==============================================================================
# Purpose: Install ArgoCD GitOps platform with dedicated LoadBalancer
# IP Assignment: 192.168.0.112 (via MetalLB LoadBalancer) 
# ==============================================================================

set -e

echo "🚀 Installing ArgoCD GitOps Platform..."

# Create namespace
echo "📁 Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
echo "📦 Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD pods to be ready
echo "⏳ Waiting for ArgoCD pods to be ready..."
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s

# Create LoadBalancer service with static IP
echo "🌐 Creating ArgoCD LoadBalancer service..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: argocd-loadbalancer
  namespace: argocd
  labels:
    app.kubernetes.io/component: server
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
spec:
  type: LoadBalancer
  loadBalancerIP: 192.168.0.112
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: 8080
  - name: https
    port: 443
    protocol: TCP
    targetPort: 8080
  selector:
    app.kubernetes.io/name: argocd-server
EOF

# Configure ArgoCD for HTTP access (insecure mode)
echo "🔧 Configuring ArgoCD for HTTP access..."
kubectl patch deployment argocd-server -n argocd -p='{"spec":{"template":{"spec":{"containers":[{"name":"argocd-server","args":["argocd-server","--insecure"]}]}}}}'

# Wait for ArgoCD server to restart
echo "⏳ Waiting for ArgoCD server to restart..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=120s

# Wait for LoadBalancer IP assignment
echo "⏳ Waiting for LoadBalancer IP assignment..."
sleep 5

# Get admin password
echo "🔑 Retrieving ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Get assigned IP
ARGOCD_IP=$(kubectl get service argocd-loadbalancer -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo ""
echo "✅ ArgoCD installation completed!"
echo "🌐 ArgoCD UI: http://$ARGOCD_IP"
echo "👤 Username: admin"
echo "🔑 Password: $ARGOCD_PASSWORD"
echo ""
echo "📋 Service Details:"
kubectl get service argocd-loadbalancer -n argocd
echo ""
echo "🎯 Access ArgoCD at: http://$ARGOCD_IP"
echo "💡 Use the credentials above to login"
echo ""
