#!/bin/bash

# ==============================================================================
# 8 - Install Litmus Chaos Engineering Platform
# ==============================================================================
# Purpose: Install Litmus Chaos for chaos engineering experiments on K3s
# Access: litmus.<NGINX_LB_IP>.nip.io (e.g., litmus.192.168.0.111.nip.io)
# ==============================================================================

set -e

echo "🔥 Installing Litmus Chaos Engineering Platform..."
echo ""

# Check if Litmus is already installed
if helm list -n litmus 2>/dev/null | grep -q "litmus"; then
    echo "⚠️  Litmus is already installed!"
    echo ""
    read -p "Do you want to uninstall and reinstall? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Uninstalling existing Litmus installation..."
        helm uninstall litmus -n litmus
        echo "⏳ Waiting for resources to be cleaned up..."
        sleep 10
        
        echo "🗑️  Deleting PVCs..."
        kubectl delete pvc -n litmus --all --wait=true
        
        echo "🗑️  Deleting namespace..."
        kubectl delete namespace litmus --wait=true
        
        echo "✅ Cleanup complete!"
        echo ""
        sleep 5
    else
        echo "❌ Installation cancelled. Exiting..."
        exit 0
    fi
fi

# Step 0: Check Helm installation
echo "Step 0: Checking Helm installation..."
if ! command -v helm &> /dev/null; then
    echo "Helm not found. Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo "✅ Helm installed successfully"
else
    HELM_VERSION=$(helm version --short)
    echo "✅ Helm already installed: $HELM_VERSION"
fi
echo ""

# Step 1: Add Litmus Helm repository
echo "Step 1: Adding Litmus Helm repository..."
helm repo add litmuschaos https://litmuschaos.github.io/litmus-helm/
helm repo update
echo "✅ Litmus Helm repository added"
echo ""

# Step 2: Create litmus namespace
echo "Step 2: Creating litmus namespace..."
kubectl create namespace litmus --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespace created"
echo ""

# Step 3: Create Litmus values file
echo "Step 3: Creating Litmus values configuration..."

cat > /tmp/litmus-values.yaml <<EOF
# Litmus Chaos Engineering Platform - K3s Optimized Configuration
# Chart: litmuschaos/litmus

# Portal (Frontend)
portal:
  server:
    graphqlServer:
      imageTag: "3.10.0"
      
    service:
      type: ClusterIP
      port: 9002
      targetPort: 8080
    
    resources:
      requests:
        cpu: 125m
        memory: 150Mi
      limits:
        cpu: 225m
        memory: 512Mi
    
    # Deploy on worker node
    nodeSelector:
      kubernetes.io/hostname: k3s-worker

  frontend:
    imageTag: "3.10.0"
    
    service:
      type: ClusterIP
      port: 9091
      targetPort: 8185
    
    resources:
      requests:
        cpu: 125m
        memory: 150Mi
      limits:
        cpu: 225m
        memory: 512Mi
    
    # Deploy on worker node
    nodeSelector:
      kubernetes.io/hostname: k3s-worker

    # GraphQL Server Resources
    graphqlServer:
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          cpu: 100m
          memory: 256Mi

    # Auth Server Configuration (Nested under portal.server)
    authServer:
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          cpu: 100m
          memory: 256Mi

# MongoDB Database (Bitnami subchart configuration)
mongodb:
  enabled: true
  
  image:
    registry: docker.io
    repository: bitnamilegacy/mongodb
    tag: 8.0.13-debian-12-r0
  
  # Authentication
  auth:
    enabled: true
    rootUser: "root"
    rootPassword: "1234"
  
  # Use replicaSet mode with 1 replica (Litmus requires replica set)
  # Note: Litmus init containers check for rs.status(), doesn't work with standalone
  architecture: replicaset
  replicaCount: 1
  
  # Disable arbiter for minimal setup (only 1 replica node)
  arbiter:
    enabled: false
  
  # Persistence
  persistence:
    enabled: true
    size: 10Gi
    storageClass: local-path
  
  volumePermissions:
    enabled: true
  
  # Resource limits
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 250m
      memory: 700Mi
  
  # Deploy on worker node
  nodeSelector:
    kubernetes.io/hostname: k3s-worker
  
  # Probes timeout (MongoDB can be slow to start)
  livenessProbe:
    timeoutSeconds: 20
  readinessProbe:
    timeoutSeconds: 20

# Ingress Configuration (disabled - we'll create manually)
ingress:
  enabled: false

# Admin Configuration
adminConfig:
  DBUSER: "admin"
  DBPASSWORD: "1234"
  JWTSecret: "litmus-portal-secret"
  VERSION: "3.10.0"
  
# Skip SSL verification (for local development)
customLabels: {}
EOF

echo "✅ Litmus values file created"
echo ""

# Step 4: Install Litmus using Helm
echo "Step 4: Installing Litmus Chaos Platform..."

helm upgrade --install litmus litmuschaos/litmus \
  --namespace litmus \
  --values /tmp/litmus-values.yaml \
  --timeout 10m \
  --wait

echo "✅ Litmus installed successfully"
echo ""

# Step 5: Wait for Litmus pods to be ready
echo "Step 5: Waiting for Litmus pods to be ready..."
kubectl wait --for=condition=ready pod --all -n litmus --timeout=300s
echo "✅ All Litmus pods are ready"
echo ""

# Step 6: Get Nginx Ingress LoadBalancer IP
echo "Step 6: Getting Nginx Ingress LoadBalancer IP..."

INGRESS_IP=$(kubectl get service nginx-ingress-loadbalancer -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$INGRESS_IP" ]; then
    echo "❌ Error: Nginx Ingress LoadBalancer not found"
    echo "   Install Nginx Ingress first with 4A-install-nginx-ingress.sh"
    exit 1
fi

echo "✅ Found LoadBalancer IP: $INGRESS_IP"
echo ""

# Step 7: Create Ingress for Litmus
echo "Step 7: Creating Litmus Ingress..."

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: litmus-ingress
  namespace: litmus
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: litmus.${INGRESS_IP}.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: litmus-frontend-service
            port:
              number: 9091
EOF

echo "✅ Litmus Ingress created"
echo ""

# Step 8: Verification
echo "=== Verification ==="
echo ""
echo "📦 Pods:"
kubectl get pods -n litmus
echo ""
echo "🔌 Services:"
kubectl get svc -n litmus
echo ""
echo "🌐 Ingress:"
kubectl get ingress -n litmus
echo ""
echo "💾 PersistentVolumeClaims:"
kubectl get pvc -n litmus
echo ""

# Step 9: Installation Summary
echo "=== Litmus Chaos Engineering Platform - Installation Complete ==="
echo ""
echo "🔗 Access URL: http://litmus.${INGRESS_IP}.nip.io"
echo ""
echo "📋 Default Credentials:"
echo "   Username: admin"
echo "   Password: litmus"
echo ""
echo "⚠️  Next Steps:"
echo "   1. Login to Litmus Portal"
echo "   2. Change the default password"
echo "   3. Connect your K3s cluster as a Chaos Target"
echo "   4. Create your first Chaos Experiment"
echo ""
echo "📚 Documentation:"
echo "   - Litmus Docs: https://docs.litmuschaos.io"
echo "   - Chaos Experiments: https://hub.litmuschaos.io"
echo ""
echo "💡 nip.io automatically resolves litmus.${INGRESS_IP}.nip.io to ${INGRESS_IP}"
echo "   No /etc/hosts editing needed!"
echo ""
echo "🎯 Tip: Start with pod-delete or node-cpu-hog experiments to test your system's resilience"
echo ""

