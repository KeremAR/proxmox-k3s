#!/bin/bash

echo "=== Installing SonarQube ==="
echo ""

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

# Step 1: Add SonarQube Helm repository
echo "Step 1: Adding SonarQube Helm repository..."
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update
echo ""

# Step 2: Install SonarQube with ClusterIP
echo "Step 2: Installing SonarQube..."

# Create sonarqube-values.yaml
cat > /tmp/sonarqube-values.yaml <<EOF
# SonarQube Helm Values - K3s optimized
# Chart: sonarqube/sonarqube

# Community Edition
community:
  enabled: true

replicaCount: 1

image:
  repository: sonarqube
  tag: "10.3-community"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 9000
  targetPort: 9000

ingress:
  enabled: false

# Resource limits
resources:
  limits:
    cpu: 1000m
    memory: 2Gi
  requests:
    cpu: 250m
    memory: 1Gi

# Persistence
persistence:
  enabled: true
  size: 3Gi

# PostgreSQL database
postgresql:
  enabled: true
  postgresqlUsername: sonarqube
  postgresqlDatabase: sonarqube
  postgresqlPassword: sonarqube123
  persistence:
    enabled: true
    size: 2Gi

# System settings
initSysctl:
  enabled: true


# Monitoring passcode
monitoringPasscode: "define_it"

# Probes - optimized for slow startup
probes:
  liveness:
    initialDelaySeconds: 300
    periodSeconds: 30
    timeoutSeconds: 5
    failureThreshold: 10
  readiness:
    initialDelaySeconds: 120
    periodSeconds: 15
    timeoutSeconds: 5
    failureThreshold: 10
  startup:
    initialDelaySeconds: 60
    failureThreshold: 30
    periodSeconds: 10

nodeSelector: {}
tolerations: []
affinity: {}
EOF

helm upgrade --install sonarqube sonarqube/sonarqube \
  --namespace sonarqube \
  --create-namespace \
  --values /tmp/sonarqube-values.yaml \
  --timeout 15m \
  --wait

echo "✅ SonarQube installed"
echo ""

# Step 3: Create Ingress for SonarQube
echo "Step 3: Creating SonarQube Ingress..."

# Get Nginx Ingress LoadBalancer IP
INGRESS_IP=$(kubectl get service nginx-ingress-loadbalancer -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$INGRESS_IP" ]; then
    echo "❌ Error: Nginx Ingress LoadBalancer not found"
    echo "   Install Nginx Ingress first with 4A-install-nginx-ingress.sh"
    exit 1
fi

echo "✅ Found LoadBalancer IP: $INGRESS_IP"

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sonarqube-ingress
  namespace: sonarqube
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: sonarqube.${INGRESS_IP}.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: sonarqube-sonarqube
            port:
              number: 9000
EOF

echo "✅ Ingress created"
echo ""

# Step 4: Verification
echo "=== Verification ==="
echo ""
kubectl get pods -n sonarqube
echo ""
kubectl get svc -n sonarqube
echo ""

echo "=== SonarQube Installation Complete ==="
echo ""
echo "🔗 Access URL: http://sonarqube.${INGRESS_IP}.nip.io"
echo ""
echo "📋 Default temporary Credentials:"
echo "   Username: admin"
echo "   Password: admin"
echo ""
echo "⚠️  Next Steps:"
echo "   1. Login to SonarQube"
echo "   2. Go to: My Account > Security > Generate Token"
echo "   3. Copy the token for Jenkins configuration (7B-jenkins.sh)"
echo ""
echo "   4. Create a new webhook for Jenkins:"
echo "   5. Go to: Administration  -> Configuration  -> Webhooks -> Create Webhook"
echo "   6. URL: <JENKINS_URL>/sonarqube-webhook/"



