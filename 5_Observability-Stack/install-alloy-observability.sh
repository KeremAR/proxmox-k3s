#!/bin/bash

echo "=== Installing Grafana Alloy Observability Stack ==="
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

# Alloy handles log collection
promtail:
  enabled: false

grafana:
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
    type: LoadBalancer
    loadBalancerIP: 192.168.0.115
  
  # Loki datasource embedded in Grafana config
  additionalDataSources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki.observability.svc.cluster.local:3100
    isDefault: false
    editable: true
    jsonData:
      maxLines: 1000


# Disable default dashboards
  defaultDashboards:
    enabled: false

# Prometheus configuration
prometheus:
  enabled: true
  service:
    type: LoadBalancer
    loadBalancerIP: 192.168.0.114
  prometheusSpec:
    retention: 7d
    enableRemoteWriteReceiver: true
    storageSpec:
      volumeClaimTemplate:
        spec:
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
echo "Access URLs:"
echo "  - Grafana:    http://192.168.0.115:3000 (admin / admin123)"
echo "  - Prometheus: http://192.168.0.114:9090"
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
