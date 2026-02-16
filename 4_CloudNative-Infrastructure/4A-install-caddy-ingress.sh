#!/bin/bash

# ==============================================================================
# 4A - Install Caddy Ingress Controller with LoadBalancer
# ==============================================================================
# Purpose: Install and configure Caddy Ingress Controller for HTTP/HTTPS routing
# TLS Mode: Internal/LAN using Caddy local CA for non-public hostnames
# ==============================================================================

set -e

echo "Installing Caddy Ingress Controller..."

# Step 0: Check Helm installation
echo "Checking Helm installation..."
if ! command -v helm >/dev/null 2>&1; then
    echo "Helm not found. Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Create namespace
echo "Creating caddy-system namespace..."
kubectl create namespace caddy-system --dry-run=client -o yaml | kubectl apply -f -

# Install Caddy Ingress Controller
echo "Installing Caddy Ingress Controller via Helm..."
helm upgrade --install mycaddy caddy-ingress-controller \
  --repo https://caddyserver.github.io/ingress/ \
  --namespace caddy-system \
  --set ingressController.className=caddy \
  --set ingressController.classNameRequired=true \
  --set loadBalancer.enabled=true \
  --wait

echo "Waiting for Caddy pods to be ready..."
kubectl wait --namespace caddy-system \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=caddy-ingress-controller \
  --timeout=300s

# Wait for LoadBalancer IP assignment
echo "Waiting for LoadBalancer IP assignment..."
sleep 20

INGRESS_IP=$(kubectl get svc mycaddy-caddy-ingress-controller -n caddy-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo ""
echo "Caddy Ingress Controller installation completed."
echo "Service: mycaddy-caddy-ingress-controller (namespace: caddy-system)"
echo "HTTP URL: http://$INGRESS_IP"
echo "HTTPS URL: https://$INGRESS_IP"
echo ""
echo "Internal TLS note:"
echo "- For LAN/internal hostnames, Caddy can issue local certs automatically."
echo "- You must trust Caddy's root CA on client machines."
echo ""
echo "IngressClass details:"
kubectl get ingressclass
echo ""
echo "LoadBalancer details:"
kubectl get svc mycaddy-caddy-ingress-controller -n caddy-system
echo ""
echo "Next step: run 4B-install-argocd.sh"
