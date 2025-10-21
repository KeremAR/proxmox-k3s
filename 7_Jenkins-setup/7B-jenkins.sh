#!/bin/bash

# ============================================
# Jenkins Installation Script
# ============================================
# BEFORE RUNNING: Edit the credentials below
# ============================================

echo "=== Installing Jenkins with JCasC ==="
echo ""

# ============================================
# CONFIGURATION - EDIT THESE VALUES
# ============================================

# GitHub Credentials
GITHUB_USERNAME="KeremAR"

GITHUB_TOKEN="ghp_YOUR_GITHUB_TOKEN_HERE"  # Needs: repo, packages scopes

# SonarQube Token (generate from SonarQube UI after 7A-sonarqube.sh)
SONAR_TOKEN="squ_YOUR_SONARQUBE_TOKEN_HERE"

# Docker Config JSON (base64 encoded ~/.docker/config.json)
# GitHub Container Registry login command:
# echo "YOUR_GITHUB_TOKEN" | docker login ghcr.io -u KeremAR --password-stdin
# Get with: cat ~/.docker/config.json | base64 -w 0
DOCKER_CONFIG_JSON="YOUR_BASE64_DOCKER_CONFIG_HERE"

# ArgoCD Credentials
ARGOCD_USER="admin"
# Get ArgoCD password with:
# kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
ARGOCD_PASS="YOUR_ARGOCD_PASSWORD_HERE"

# ============================================
# INSTALLATION STARTS HERE
# ============================================

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

# Step 1: Get SonarQube URL
echo "Step 1: Getting SonarQube URL..."

INGRESS_IP=$(kubectl get service nginx-ingress-loadbalancer -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$INGRESS_IP" ]; then
    echo "❌ Error: Nginx Ingress LoadBalancer not found"
    exit 1
fi

SONARQUBE_URL="http://sonarqube.${INGRESS_IP}.nip.io"
echo "✅ SonarQube URL: $SONARQUBE_URL"
echo ""

# Step 2: Get ArgoCD Server IP
echo "Step 2: Getting ArgoCD Server..."

ARGOCD_IP=$(kubectl get service nginx-ingress-loadbalancer -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
ARGOCD_SERVER="argocd.${ARGOCD_IP}.nip.io"

echo "✅ ArgoCD Server: $ARGOCD_SERVER"
echo ""

# Step 3: Create Jenkins namespace and secrets
echo "Step 3: Creating Jenkins namespace and secrets..."

kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -

# Create Jenkins application secrets
kubectl create secret generic jenkins-app-secrets \
  --from-literal=sonar-token="$SONAR_TOKEN" \
  --from-literal=github-username="$GITHUB_USERNAME" \
  --from-literal=github-token="$GITHUB_TOKEN" \
  --from-literal=docker-config-json="$DOCKER_CONFIG_JSON" \
  --from-literal=argocd-user="$ARGOCD_USER" \
  --from-literal=argocd-pass="$ARGOCD_PASS" \
  --namespace jenkins \
  --dry-run=client -o yaml | kubectl apply -f -

# Create Jenkins admin secret
kubectl create secret generic jenkins-admin-secret \
  --from-literal=jenkins-admin-user=admin \
  --from-literal=jenkins-admin-password=admin123 \
  --namespace jenkins \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secrets created"
echo ""

# Step 4: Create ServiceAccount first (before RBAC)
echo "Step 4: Creating Jenkins ServiceAccount..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
  namespace: jenkins
EOF

echo "✅ ServiceAccount created"
echo ""

# Step 5: Create Jenkins RBAC (ClusterAdmin permissions)
echo "Step 5: Creating Jenkins RBAC..."

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins-cluster-admin-binding
subjects:
- kind: ServiceAccount
  name: jenkins
  namespace: jenkins
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

echo "✅ RBAC created (ClusterAdmin permissions)"
echo "   Jenkins can now access all namespaces (production, argocd, etc.)"
echo ""

# Step 6: Create jenkins-values.yaml with dynamic values
echo "Step 6: Creating jenkins-values.yaml..."

cat > /tmp/jenkins-values.yaml <<EOF
controller:
  admin:
    existingSecret: "jenkins-admin-secret"
    userKey: "jenkins-admin-user"
    passwordKey: "jenkins-admin-password"

  installPlugins:
    - credentials
    - plain-credentials
    - kubernetes
    - workflow-aggregator
    - git
    - github
    - docker-workflow
    - pipeline-stage-view
    - kubernetes-cli
    - configuration-as-code
    - basic-branch-build-strategies
    - sonar

  envs:
    - name: SONAR_TOKEN
      valueFrom:
        secretKeyRef:
          name: jenkins-app-secrets
          key: sonar-token
    - name: GITHUB_USERNAME
      valueFrom:
        secretKeyRef:
          name: jenkins-app-secrets
          key: github-username
    - name: GITHUB_TOKEN
      valueFrom:
        secretKeyRef:
          name: jenkins-app-secrets
          key: github-token
    - name: DOCKER_CONFIG_JSON
      valueFrom:
        secretKeyRef:
          name: jenkins-app-secrets
          key: docker-config-json
    - name: ARGOCD_USER
      valueFrom:
        secretKeyRef:
          name: jenkins-app-secrets
          key: argocd-user
    - name: ARGOCD_PASS
      valueFrom:
        secretKeyRef:
          name: jenkins-app-secrets
          key: argocd-pass

  JCasC:
    configScripts:
      tools: |
        tools:
          - sonarScanner:
              installations:
                - name: "SonarQube-Scanner"
                  properties:
                    - installSource:
                        installers:
                          - latestSupported: true

      sonarqube: |
        unclassified:
          sonarGlobalConfiguration:
            installations:
              - name: "sq1"
                serverUrl: "$SONARQUBE_URL"
                credentialsId: "sonarqube-token"
      
      global-settings: |
        jenkins:
          globalNodeProperties:
            - "envVars":
                "env":
                  - "key": "ARGOCD_SERVER"
                    "value": "$ARGOCD_SERVER"
        unclassified:
          globallibraries:
            libraries:
              - name: "todo-app-shared-library"
                defaultVersion: "master"
                retriever:
                  modernSCM:
                    scm:
                      git:
                        remote: "https://github.com/KeremAR/jenkins-shared-library2"
                        
      kubernetes-cloud: |
        clouds:
          - kubernetes:
              name: "kubernetes"
              serverUrl: "https://kubernetes.default.svc"
              namespace: "jenkins"
              
      credentials: |
        credentials:
          system:
            domainCredentials:
              - credentials:
                  - string:
                      scope: GLOBAL
                      id: "sonarqube-token"
                      secret: "\${SONAR_TOKEN}"
                      description: "SonarQube Access Token"
                  
                  - usernamePassword:
                      scope: GLOBAL
                      id: "github-registry"
                      username: "\${GITHUB_USERNAME}"
                      password: "\${GITHUB_TOKEN}"
                      description: "GitHub Registry (packages scope)"
                      
                  - usernamePassword:
                      scope: GLOBAL
                      id: "github-webhook"
                      username: "\${GITHUB_USERNAME}"
                      password: "\${GITHUB_TOKEN}"
                      description: "GitHub Webhook (repo, hook scopes)"

                  - string:
                      scope: GLOBAL
                      id: "github-registry-dockerconfig"
                      secret: "\${DOCKER_CONFIG_JSON}"
                      description: "Base64 encoded Docker config.json"

                  - string:
                      scope: GLOBAL
                      id: "argocd-username"
                      secret: "\${ARGOCD_USER}"
                      description: "ArgoCD Username"
                      
                  - string:
                      scope: GLOBAL
                      id: "argocd-password"
                      secret: "\${ARGOCD_PASS}"
                      description: "ArgoCD Password"

  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "2"
      memory: "4Gi"

  serviceType: ClusterIP

persistence:
  enabled: true
  size: 8Gi

serviceAccount:
  create: false  # Already created manually
  name: jenkins
EOF

echo "✅ jenkins-values.yaml created"
echo ""

# Step 7: Install Jenkins
echo "Step 7: Installing Jenkins..."

helm repo add jenkins https://charts.jenkins.io
helm repo update

helm upgrade --install jenkins jenkins/jenkins \
  --namespace jenkins \
  --values /tmp/jenkins-values.yaml \
  --timeout 10m \
  --wait

echo "✅ Jenkins installed"
echo ""

# Step 8: Create Jenkins Ingress
echo "Step 8: Creating Jenkins Ingress..."

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: jenkins-ingress
  namespace: jenkins
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: jenkins.${INGRESS_IP}.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: jenkins
            port:
              number: 8080
EOF

echo "✅ Ingress created"
echo ""

# Step 9: Verification
echo "=== Verification ==="
echo ""
kubectl get pods -n jenkins
echo ""
kubectl get svc -n jenkins
echo ""

echo "=== Jenkins Installation Complete ==="
echo ""
echo "🔗 Access URL: http://jenkins.${INGRESS_IP}.nip.io"
echo ""
echo "📋 Credentials:"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "⚠️  Jenkins is configured with:"
echo "   - SonarQube: $SONARQUBE_URL"
echo "   - ArgoCD: $ARGOCD_SERVER"
echo "   - GitHub: $GITHUB_USERNAME"
echo "   - All credentials configured via JCasC"
echo ""
