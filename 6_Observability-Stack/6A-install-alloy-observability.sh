#!/bin/bash

echo "=== Installing Grafana Alloy Observability Stack ==="
echo ""

# Step 0: Install Helm if not already installed
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

# Step 1: Create observability namespace
echo "Step 1: Creating observability namespace..."
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

# Step 2: Install Loki (WITHOUT Promtail)
echo ""
echo "Step 2: Installing Loki..."
echo "Note: Grafana Alloy will handle log collection, Promtail disabled."

cat <<EOF > /tmp/loki-values.yaml
loki:
  enabled: true
  persistence:
    enabled: true
    size: 10Gi
  storageClassName: local-path

  nodeSelector:
    kubernetes.io/hostname: k3s-worker
  
  securityContext:
    fsGroup: 10001
    runAsGroup: 10001
    runAsUser: 10001

# Alloy handles log collection
promtail:
  enabled: false

grafana:
  enabled: false
  datasources:
    enabled: false
EOF

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install loki grafana/loki-stack \
  --namespace observability \
  --values /tmp/loki-values.yaml \
  --wait

echo "Loki installed!"

# Step 3: Install Prometheus (kube-prometheus-stack)
echo ""
echo "Step 3: Installing Prometheus + Grafana..."

cat <<EOF > /tmp/prometheus-values.yaml
# Grafana configuration
grafana:
  enabled: true
  adminPassword: admin123
  service:
    type: ClusterIP
  
  nodeSelector:
    kubernetes.io/hostname: k3s-worker

  securityContext:
    fsGroup: 472
    runAsGroup: 472
    runAsUser: 472
  

  defaultDatasource:
    enabled: false

  additionalDataSources: []

# Disable default dashboards
  defaultDashboards:
    enabled: false

# Prometheus configuration
prometheus:
  enabled: true
  service:
    type: ClusterIP
  prometheusSpec:
    retention: 7d
    enableRemoteWriteReceiver: true
    scrapeInterval: ""
    scrapeTimeout: ""
    additionalScrapeConfigs: []
    scrapeConfigs: []
    scrape: false
    ruleSelectorNilUsesHelmValues: false
    nodeSelector:
      kubernetes.io/hostname: k3s-worker

    securityContext:
      fsGroup: 65534
      runAsGroup: 65534
      runAsUser: 65534

    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: local-path
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi

# DISABLE metric collectors (Alloy will provide these)
kubeStateMetrics:
  enabled: false

nodeExporter:
  enabled: false

# Alertmanager (optional)
alertmanager:
  enabled: true
EOF

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --values /tmp/prometheus-values.yaml \
  --wait

echo "Prometheus + Grafana installed!"

# Step 4: Install Grafana Alloy
echo ""
echo "Step 4: Installing Grafana Alloy (log + metric collector)..."

cat <<EOF > /tmp/alloy-values.yaml
cluster:
  name: k3s-cluster

# === REQUIRED: Externalservices (where to send data) ===
externalServices:
  prometheus:
    host: http://prometheus-kube-prometheus-prometheus.observability.svc.cluster.local:9090
    writeEndpoint: /api/v1/write
    basicAuth:
      username: ""
      password: ""
  
  loki:
    host: http://loki.observability.svc.cluster.local:3100
    basicAuth:
      username: ""
      password: ""

alloy:
  controller:
    nodeSelector:
      kubernetes.io/hostname: k3s-worker


  

opencost:
  enabled: false

# === FEATURE: Cluster Metrics ===
clusterMetrics:
  enabled: true

# === FEATURE: Node Logs ===
logs:
  cluster_events:
    enabled: true

  pod_logs:
    enabled: true

dashboards:
  enabled: true

# === Disable features we don't need ===
traces:
  enabled: false

profiles:
  enabled: false

receivers:
  grpc:
    enabled: false
  http:
    enabled: false


# === fix CRDs ===
prometheus-operator-crds:
  enabled: false
EOF

helm upgrade --install k8s-monitoring grafana/k8s-monitoring \
  --namespace observability \
  --values /tmp/alloy-values.yaml \
  --wait \
  --version "^1"

kubectl rollout restart deployment/prometheus-grafana -n observability
kubectl rollout status deployment/prometheus-grafana -n observability --timeout=120s

echo "Grafana Alloy installed!"

# Step 5: Create Ingress Routes
echo ""
echo "Step 5: Creating Ingress routes..."

# Get Nginx Ingress LoadBalancer IP
INGRESS_IP=$(kubectl get service nginx-ingress-loadbalancer -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$INGRESS_IP" ]; then
    echo "⚠️  Warning: Nginx Ingress LoadBalancer not found"
    echo "   Skipping Ingress creation. Services accessible via ClusterIP only."
else
    echo "✅ Found LoadBalancer IP: $INGRESS_IP"
    
    # Create Grafana Ingress
    echo "📝 Creating Grafana Ingress..."
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: observability
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: grafana.${INGRESS_IP}.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-grafana
            port:
              number: 80
EOF

    # Create Prometheus Ingress
    echo "📝 Creating Prometheus Ingress..."
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus-ingress
  namespace: observability
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: prometheus.${INGRESS_IP}.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-kube-prometheus-prometheus
            port:
              number: 9090
EOF
    
    echo "✅ Ingress routes created!"
fi

# Step 6: Verification
echo ""
echo "=== Verification ==="
echo ""

echo "Pods in observability namespace:"
kubectl get pods -n observability
echo ""

echo "Services in observability namespace:"
kubectl get svc -n observability
echo ""

echo "=== Installation Complete ==="
echo ""
if [ -z "$INGRESS_IP" ]; then
    echo "⚠️  Services accessible via ClusterIP (Nginx Ingress not found)"
    echo ""
    echo "Internal Access:"
    echo "  - Grafana:    prometheus-grafana.observability.svc.cluster.local:80"
    echo "  - Prometheus: prometheus-kube-prometheus-prometheus.observability.svc.cluster.local:9090"
else
    echo "🔗 Access URLs:"
    echo "  - Grafana:    http://grafana.${INGRESS_IP}.nip.io (admin / admin123)"
    echo "  - Prometheus: http://prometheus.${INGRESS_IP}.nip.io"
    echo ""
    echo "⚠️  Note: nip.io automatically resolves <name>.<IP>.nip.io → <IP>"
    echo "   No /etc/hosts editing needed!"
fi
echo ""
echo "Next Steps:"
echo "1. Access Grafana and go to Explore"
echo "2. Select 'Loki' datasource and query: {namespace=\"kube-system\"}"
echo "3. Select 'Prometheus' datasource and query: node_cpu_seconds_total"
echo ""
echo "Components:"
echo "  - Loki: Log storage"
echo "  - Prometheus: Metric storage"
echo "  - Grafana Alloy: Log + Metric collector (DaemonSet)"
echo "  - Grafana: Visualization"
