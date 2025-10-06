#!/bin/bash

# ==============================================================================
# 4A - Install Nginx Ingress Controller with LoadBalancer
# ==============================================================================
# Purpose: Install and configure Nginx Ingress Controller for HTTP/HTTPS routing
# IP Assignment: 192.168.0.111 (via MetalLB LoadBalancer)
# ==============================================================================

set -e

echo "🚀 Installing Nginx Ingress Controller..."

# Create namespace
echo "📁 Creating ingress-nginx namespace..."
kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -

# Install Nginx Ingress Controller
echo "📦 Installing Nginx Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/baremetal/deploy.yaml

# Wait for ingress controller to be ready
echo "⏳ Waiting for Nginx Ingress Controller pods to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

# Create LoadBalancer service
echo "🌐 Creating LoadBalancer service..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: nginx-ingress-loadbalancer
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
spec:
  type: LoadBalancer
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: 80
  - name: https
    port: 443
    protocol: TCP
    targetPort: 443
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/component: controller
EOF

# Wait for LoadBalancer IP assignment
echo "⏳ Waiting for LoadBalancer IP assignment..."
sleep 30

# Get assigned IP
INGRESS_IP=$(kubectl get service nginx-ingress-loadbalancer -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo ""
echo "✅ Nginx Ingress Controller installation completed!"
echo "🌐 Access URL: http://$INGRESS_IP"
echo "🔒 HTTPS URL: https://$INGRESS_IP"
echo ""
echo "📋 Service Details:"
kubectl get service nginx-ingress-loadbalancer -n ingress-nginx
echo ""
echo "🎯 Next Step: Run 4B-install-argocd.sh to install ArgoCD"