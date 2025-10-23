#!/bin/bash

# ==============================================================================
# 4B - Install ArgoCD with Ingress  
# ==============================================================================
# Purpose: Install ArgoCD GitOps platform accessible via Nginx Ingress
# Access: argocd.<NGINX_LB_IP>.nip.io (e.g., argocd.192.168.0.111.nip.io)
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

# Configure ArgoCD for HTTP access (insecure mode for Ingress)
echo "🔧 Configuring ArgoCD for Ingress access..."
kubectl patch deployment argocd-server -n argocd -p='{"spec":{"template":{"spec":{"containers":[{"name":"argocd-server","args":["argocd-server","--insecure"]}]}}}}'

# Wait for ArgoCD server to restart
echo "⏳ Waiting for ArgoCD server to restart..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=120s

# Get Nginx Ingress LoadBalancer IP
INGRESS_IP=$(kubectl get service nginx-ingress-loadbalancer -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$INGRESS_IP" ]; then
    echo "❌ Error: Nginx Ingress LoadBalancer not found"
    echo "   Run 4A-install-nginx-ingress.sh first"
    exit 1
fi

# Create Ingress for ArgoCD
echo "🌐 Creating ArgoCD Ingress..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-ingress
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: argocd.${INGRESS_IP}.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
EOF

echo "✅ ArgoCD Ingress created"
echo ""
# Get admin password
echo "🔑 Retrieving ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
ARGOCD_USERNAME="admin"

curl -SL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

echo "logging in to argocd"
# Login to ArgoCD
argocd login argocd.${INGRESS_IP}.nip.io \
  --username "${ARGOCD_USERNAME}" \
  --password "${ARGOCD_PASSWORD}" \
  --insecure \
  --grpc-web

argocd account get-user-info

FILE="5-deploy-app.sh"
[ -f "$FILE" ] || curl -sO "https://raw.githubusercontent.com/KeremAR/proxmox-k3s/main/5_Deploy-app/$FILE" && chmod +x "$FILE"


echo ""
echo "✅ ArgoCD installation completed!"
echo "🌐 ArgoCD UI: http://argocd.${INGRESS_IP}.nip.io"
echo "👤 Username: admin"
echo "🔑 Password: $ARGOCD_PASSWORD"
echo ""
echo "📋 Ingress Details:"
kubectl get ingress -n argocd
echo ""
echo "💡 nip.io automatically resolves argocd.${INGRESS_IP}.nip.io to ${INGRESS_IP}"
echo "   No /etc/hosts editing needed!"
echo ""
echo "🎯 Next Step: Configure ArgoCD applications"
echo ""
