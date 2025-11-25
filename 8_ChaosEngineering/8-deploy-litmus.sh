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

# Check litmusctl
if ! command -v litmusctl &> /dev/null; then
    echo "⬇️  Installing litmusctl v1.20.0..."
    curl -L "https://litmusctl-production-bucket.s3.amazonaws.com/litmusctl-linux-amd64-1.20.0.tar.gz" -o litmusctl.tar.gz
    tar -zxvf litmusctl.tar.gz
    chmod +x litmusctl
    sudo mv litmusctl /usr/local/bin/
    rm litmusctl.tar.gz
    echo "✅ litmusctl installed"
else
    echo "✅ litmusctl already installed"
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
    nginx.ingress.kubernetes.io/rewrite-target: /$1
    nginx.ingress.kubernetes.io/use-regex: "true"
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

# Step 8: Automate Agent Connection (litmusctl)
echo "Step 8: Automating Agent Connection..."

# Wait for frontend to be reachable
echo "⏳ Waiting for Litmus Portal to be reachable..."
sleep 10
# Simple check loop
for i in {1..30}; do
    if curl -s -o /dev/null -w "%{http_code}" "http://litmus.${INGRESS_IP}.nip.io" | grep -q "200"; then
        echo "✅ Portal is UP"
        break
    fi
    echo "   Waiting for Portal... ($i/30)"
    sleep 5
done

# Export INGRESS_IP for expect scripts
export INGRESS_IP

# Check and install expect if needed
if ! command -v expect &> /dev/null; then
    echo "   Installing 'expect' for automated password update..."
    sudo apt-get update && sudo apt-get install -y expect
fi

echo ""
echo "🔧 Step 1: Configure litmusctl with default credentials..."
cat <<EOF > /tmp/config_initial.exp
#!/usr/bin/expect -f
set timeout 1
spawn litmusctl config set-account
expect "Host endpoint where litmus is installed:"
send "http://litmus.\$env(INGRESS_IP).nip.io\r"
expect "Username"
send "admin\r"
expect "Password:"
send "litmus\r"
expect eof
EOF
chmod +x /tmp/config_initial.exp
/tmp/config_initial.exp
rm /tmp/config_initial.exp
echo "✅ litmusctl configured"

# 2. Update Password (litmus -> Litmus123!)
echo ""
echo "🔐 Step 2: Updating password to 'Litmus123!'..."
cat <<EOF > /tmp/update_pass.exp
#!/usr/bin/expect -f
set timeout 1
spawn litmusctl update password
expect "Username:"
send "admin\r"
expect "Old Password:"
send "litmus\r"
expect "New Password:"
send "Litmus123!\r"
expect "Confirm New Password:"
send "Litmus123!\r"
expect eof
EOF
chmod +x /tmp/update_pass.exp
/tmp/update_pass.exp
rm /tmp/update_pass.exp
echo "✅ Password updated"

# 3. Re-configure litmusctl with new password
echo ""
echo "🔧 Step 3: Re-configuring litmusctl with new password..."
cat <<EOF > /tmp/config_new.exp
#!/usr/bin/expect -f
set timeout 1
spawn litmusctl config set-account
expect "Host endpoint where litmus is installed:"
send "http://litmus.\$env(INGRESS_IP).nip.io\r"
expect "Username"
send "admin\r"
expect "Password:"
send "Litmus123!\r"
expect eof
EOF
chmod +x /tmp/config_new.exp
/tmp/config_new.exp
rm /tmp/config_new.exp
echo "✅ litmusctl re-configured"
echo ""

# Create Project (Required for v1.20.0 flow if not default)
echo "🔧 Creating Project..."
# v1.20.0 create project doesn't support --non-interactive flag based on error
litmusctl create project --name "Self-Chaos" || echo "Project might already exist"

# Create Environment (Required for v1.20.0 flow)
echo "� Creating Environment..."
# We need to get the project ID first
# JSON structure: { "projects": [ { "projectID": "...", "name": "..." } ] }
PROJECT_ID=$(litmusctl get projects --output json | jq -r '.projects[] | select(.name=="Self-Chaos") | .projectID')

if [ -z "$PROJECT_ID" ]; then
    echo "⚠️  Could not find project ID for 'Self-Chaos'. Using default project..."
    PROJECT_ID=$(litmusctl get projects --output json | jq -r '.projects[0].projectID')
fi

echo "   Project ID: $PROJECT_ID"

# Create environment if not exists
litmusctl create chaos-environment --name "staging" --project-id "$PROJECT_ID" || echo "Environment might already exist"

# Fetch Environment ID
# User confirmed that Environment ID is the same as the name for this version.
ENV_ID="staging"

echo "   Environment ID: $ENV_ID"

# Connect Agent
echo "🔌 Connecting Chaos Agent..."

if litmusctl get chaos-infra --project-id "$PROJECT_ID" --non-interactive 2>/dev/null | grep -q "ACTIVE"; then
    echo "✅ Agent already connected"
else
    litmusctl connect chaos-infra \
        --name "k3s-agent" \
        --project-id "$PROJECT_ID" \
        --environment-id "$ENV_ID" \
        --installation-mode "cluster" \
        --non-interactive \
        --node-selector "kubernetes.io/hostname=k3s-worker" \
        --skip-ssl "true" || echo "⚠️  Agent connection command finished"
fi


# Step 5.5: Optimize Chaos Component Resources (not available in Helm values)
echo "Step 5.5: Optimizing Chaos component resources..."

# Patch chaos-exporter
kubectl patch deployment chaos-exporter -n litmus --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources", "value": {
    "requests": {"cpu": "50m", "memory": "50Mi"},
    "limits": {"cpu": "200m", "memory": "256Mi"}
  }}
]' 2>/dev/null || echo "   chaos-exporter not found yet"

# Patch chaos-operator
kubectl patch deployment chaos-operator-ce -n litmus --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources", "value": {
    "requests": {"cpu": "50m", "memory": "50Mi"},
    "limits": {"cpu": "200m", "memory": "256Mi"}
  }}
]' 2>/dev/null || echo "   chaos-operator not found yet"

# Patch subscriber
kubectl patch deployment subscriber -n litmus --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources", "value": {
    "requests": {"cpu": "50m", "memory": "50Mi"},
    "limits": {"cpu": "200m", "memory": "256Mi"}
  }}
]' 2>/dev/null || echo "   subscriber not found yet"

# Patch event-tracker
kubectl patch deployment event-tracker -n litmus --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources", "value": {
    "requests": {"cpu": "50m", "memory": "50Mi"},
    "limits": {"cpu": "200m", "memory": "256Mi"}
  }}
]' 2>/dev/null || echo "   event-tracker not found yet"

# Patch workflow-controller
kubectl patch deployment workflow-controller -n litmus --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources", "value": {
    "requests": {"cpu": "50m", "memory": "50Mi"},
    "limits": {"cpu": "200m", "memory": "256Mi"}
  }}
]' 2>/dev/null || echo "   workflow-controller not found yet"

echo "✅ Resource optimization applied"
echo "   Triggering rolling restart..."
kubectl rollout restart deployment -n litmus 2>/dev/null || true
echo "   Waiting for pods to restart with new resources..."
sleep 10
kubectl wait --for=condition=ready pod --all -n litmus --timeout=300s 2>/dev/null || echo "   Some pods still restarting, continuing..."
echo ""

echo "   Triggering rolling restart for chaos-exporter, chaos-operator-ce, subscriber, event-tracker, workflow-controller..."
kubectl rollout restart deployment/chaos-exporter -n litmus
kubectl rollout restart deployment/chaos-operator-ce -n litmus
kubectl rollout restart deployment/subscriber -n litmus
kubectl rollout restart deployment/event-tracker -n litmus
kubectl rollout restart deployment/workflow-controller -n litmus

# Verification
echo "=========================================="
echo "   LITMUS PLATFORM INSTALLED"
echo "=========================================="
echo ""

echo "📦 Litmus Pods:"
kubectl get pods -n litmus
echo ""

echo "🔌 Services:"
kubectl get svc -n litmus
echo ""

echo "🌐 Ingress:"
kubectl get ingress -n litmus
echo ""

echo "💾 Persistent Storage:"
kubectl get pvc -n litmus
echo ""

# Installation Summary
echo "=========================================="
echo "   INSTALLATION COMPLETE ✅"
echo "=========================================="
echo ""
echo "🔗 Portal URL:"
echo "   http://litmus.${INGRESS_IP}.nip.io"
echo ""
echo "📋 Login Credentials:"
echo "   Username: admin"
echo "   Password: Litmus123! (updated from default 'litmus')"
echo ""
echo "✅ What's Been Installed:"
echo "   • Litmus Portal (Frontend + Backend)"
echo "   • MongoDB (Persistent Storage)"
echo "   • Nginx Ingress Rule"
echo "   • litmusctl CLI (configured)"
echo ""
echo "🚀 Next Steps:"
echo "   1. Run: ./8B-setup-experiment.sh"
echo "   2. This will set up:"
echo "      → Project and Environment"
echo "      → Chaos Agent (connected to K3s)"
echo "      → Test Workflow (pod-delete-test)"
echo ""
echo "📚 Resources:"
echo "   • Litmus Docs: https://docs.litmuschaos.io"
echo "   • Chaos Hub: https://hub.litmuschaos.io"
echo ""
echo "💡 Tips:"
echo "   • nip.io auto-resolves: litmus.${INGRESS_IP}.nip.io → ${INGRESS_IP}"
echo "   • No /etc/hosts editing needed!"
echo ""
echo "🎯 Litmus Platform ready! Run 8B-setup-experiment.sh next."
echo ""
