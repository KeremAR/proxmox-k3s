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

# 3. first login to litmusctl 
echo "🔧 Re-configuring litmusctl (New Password)..."
cat <<EOF > /tmp/config_new.exp
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
chmod +x /tmp/config_new.exp
/tmp/config_new.exp
rm /tmp/config_new.exp

# 2. Update Password (litmus -> Litmus123!)
echo "🔐 Updating password to satisfy first-login requirement..."
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

# 3. Re-configure litmusctl (New Password)
echo "🔧 Re-configuring litmusctl (New Password)..."
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



# Step 10: Run Test Experiment
echo "Step 10: Running Test Experiment (Pod Delete)..."

# Create a sample experiment manifest
cat > /tmp/pod-delete-experiment.yaml <<EOF
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: pod-delete-test
  namespace: litmus
spec:
  engineState: 'active'
  appinfo:
    appns: 'staging'
    applabel: 'app=todo-service'
    appkind: 'deployment'
  chaosServiceAccount: litmus-admin
  experiments:
  - name: pod-delete
    spec:
      components:
        env:
        - name: TOTAL_CHAOS_DURATION
          value: '30'
        - name: CHAOS_INTERVAL
          value: '10'
        - name: FORCE
          value: 'false'
EOF

# We need to ensure the experiment CRD is installed/available.
# Usually 'litmusctl create chaos-experiment' expects a workflow manifest or a chaos experiment manifest.
# But for simple testing, we can just apply the ChaosEngine if the experiment definition exists.
# However, to be proper with litmusctl:
# litmusctl create chaos-experiment -f ...
# Let's use kubectl for the engine to be sure, as it's direct.
# But user asked for litmusctl workflow.
# Let's try to create a workflow manifest.

# Create a comprehensive Workflow manifest with embedded ChaosExperiment and ChaosEngine
# This structure is required by litmusctl to parse experiment details correctly.
# Create a comprehensive Workflow manifest with embedded ChaosExperiment and ChaosEngine
# This structure is based on the user's working example (deneme2.yml) and includes HTTP Probe.
cat > /tmp/pod-delete-workflow.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: pod_delete_test
  namespace: litmus
  labels:
    subject: "pod-delete-test"
spec:
  entrypoint: custom-chaos
  serviceAccountName: argo-chaos
  securityContext:
    runAsNonRoot: false
    runAsUser: 0
  arguments:
    parameters:
      - name: adminModeNamespace
        value: litmus
  templates:
    - name: custom-chaos
      steps:
        - - name: install-chaos-experiments
            template: install-chaos-experiments
        - - name: run-chaos
            template: run-chaos
        - - name: cleanup-chaos-resources
            template: cleanup-chaos-resources
    - name: install-chaos-experiments
      inputs:
        artifacts:
          - name: pod-delete
            path: /tmp/pod-delete.yaml
            raw:
              data: |
                apiVersion: litmuschaos.io/v1alpha1
                description:
                  message: |
                    Deletes a pod belonging to a deployment
                kind: ChaosExperiment
                metadata:
                  name: pod-delete
                  labels:
                    name: pod-delete
                    app.kubernetes.io/part-of: litmus
                    app.kubernetes.io/component: chaosexperiment
                    app.kubernetes.io/version: 2.14.0
                spec:
                  definition:
                    scope: Namespaced
                    permissions:
                      - apiGroups:
                          - ""
                          - "apps"
                          - "batch"
                          - "litmuschaos.io"
                          - "argoproj.io"
                        resources:
                          - "pods"
                          - "deployments"
                          - "jobs"
                          - "chaosengines"
                          - "chaosexperiments"
                          - "chaosresults"
                          - "rollouts"
                        verbs:
                          - "create"
                          - "list"
                          - "get"
                          - "patch"
                          - "update"
                          - "delete"
                          - "deletecollection"
                    image: litmuschaos/go-runner:latest
                    imagePullPolicy: Always
                    args:
                      - -c
                      - ./experiments -name pod-delete
                    command:
                      - /bin/bash
                    env:
                      - name: TOTAL_CHAOS_DURATION
                        value: "30"
                      - name: CHAOS_INTERVAL
                        value: "10"
                      - name: FORCE
                        value: "false"
    - name: run-chaos
      inputs:
        artifacts:
          - name: pod-delete
            path: /tmp/chaosengine.yaml
            raw:
              data: |
                apiVersion: litmuschaos.io/v1alpha1
                kind: ChaosEngine
                metadata:
                  namespace: "{{workflow.parameters.adminModeNamespace}}"
                  generateName: pod-delete-
                  labels:
                    workflow_run_id: "{{workflow.uid}}"
                spec:
                  appinfo:
                    appns: 'staging'
                    applabel: 'app=todo-service'
                    appkind: 'rollout'
                  engineState: 'active'
                  chaosServiceAccount: litmus-admin
                  experiments:
                    - name: pod-delete
                      spec:
                        components:
                          env:
                            - name: TOTAL_CHAOS_DURATION
                              value: '30'
                            - name: CHAOS_INTERVAL
                              value: '10'
                            - name: FORCE
                              value: 'false'
                        probe:
                          - name: "check-todo-service"
                            type: "httpProbe"
                            httpProbe/inputs:
                              url: "http://todo-service.staging.svc.cluster.local:8080"
                              insecureSkipVerify: false
                              responseTimeout: 5000
                              method:
                                get:
                                  criteria: "=="
                                  responseCode: "200"
                            mode: "Continuous"
                            runProperties:
                              probeTimeout: 5
                              interval: 5
                              retry: 1
      container:
        image: litmuschaos/litmus-checker:latest
        args:
          - -file=/tmp/chaosengine.yaml
          - -saveName=/tmp/engine-name
    - name: cleanup-chaos-resources
      container:
        image: litmuschaos/k8s:latest
        command:
          - sh
          - -c
        args:
          - kubectl delete chaosengine -l workflow_run_id={{workflow.uid}} -n {{workflow.parameters.adminModeNamespace}}
EOF

# Fetch Project ID
echo "🔍 Fetching Project ID..."
# We use jq to parse the JSON output robustly.
PROJECT_ID=$(litmusctl get projects --output json | jq -r '.projects[] | select(.name=="Self-Chaos") | .projectID')
echo "   Project ID: $PROJECT_ID"

if [ -z "$PROJECT_ID" ]; then
    echo "❌ Error: Could not fetch Project ID. Exiting."
    exit 1
fi
export PROJECT_ID

# Fetch Chaos Infra ID for the experiment
echo " Fetching Chaos Infra ID..."
# Output format: ID NAME STATUS ...
INFRA_ID=$(litmusctl get chaos-infra --project-id "$PROJECT_ID" | awk 'NR==2 {print $1}')
echo "   Infra ID: $INFRA_ID"

# Fetch Experiment ID
# User confirmed that Experiment ID is the same as the workflow name.
EXPERIMENT_ID="pod_delete_test"
echo "   Experiment ID: $EXPERIMENT_ID"

echo "🚀 Creating/Saving Chaos Experiment..."
# Try to create first
if litmusctl create chaos-experiment \
    -f /tmp/pod-delete-workflow.yaml \
    --project-id "$PROJECT_ID" \
    --chaos-infra-id "$INFRA_ID" \
    --description "Automated pod delete test"; then
    echo "✅ Experiment created successfully."
else
    echo "⚠️  Create failed (likely exists), attempting to SAVE (update)..."
    litmusctl save chaos-experiment \
        -f /tmp/pod-delete-workflow.yaml \
        --project-id "$PROJECT_ID" \
        --chaos-infra-id "$INFRA_ID" \
        --description "Automated pod delete test" || echo "⚠️  Save failed (check duplicate key error if unchanged)"
fi

if [ -n "$EXPERIMENT_ID" ]; then
    echo "🚀 Triggering Chaos Experiment Run..."
    echo "DEBUG: Project ID: $PROJECT_ID"
    echo "DEBUG: Experiment ID: $EXPERIMENT_ID"
    litmusctl run chaos-experiment --project-id "$PROJECT_ID" --experiment-id "$EXPERIMENT_ID" || echo "⚠️  Run trigger failed"
fi

echo "📋 Listing Chaos Experiment Runs..."
litmusctl get chaos-experiment-runs --project-id "$PROJECT_ID" || true

# Let's add the wait logic for ANY workflow.
echo "⏳ Waiting for any Chaos Workflow to start..."
sleep 10

# Wait loop
echo "👀 Watching for workflows..."
# We use the user's logic:
# until ./kubectl get workflow ...
# But we need to be careful about the jsonpath.

kubectl get workflow -n litmus || echo "No workflows found yet."

echo "✅ Setup Complete. You can now create experiments in the portal or via CLI."
echo ""

# Step 11: Verification
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

# Step 11: Installation Summary
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

