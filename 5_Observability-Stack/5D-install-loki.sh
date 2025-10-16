#!/bin/bash

# ==============================================================================
# 5D - Install Loki Logging Stack
# ==============================================================================
# Purpose: Log aggregation and querying system
# Components: Loki, Promtail for log collection
# ==============================================================================

set -e

echo "📝 Installing Loki Logging Stack..."

# Add Grafana Helm repository  
echo "📦 Adding Grafana Helm repository..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Loki Stack
echo "🚀 Installing Loki..."
cat <<EOF > /tmp/loki-values.yaml
loki:
  commonConfig:
    replication_factor: 1
  storage:
    type: 'filesystem'
  schemaConfig:
    configs:
      - from: 2020-10-24
        store: boltdb-shipper
        object_store: filesystem
        schema: v11
        index:
          prefix: index_
          period: 24h
  
  # Single binary mode for simple deployment
  deploymentMode: SingleBinary
  
  singleBinary:
    replicas: 1
    persistence:
      enabled: true
      size: 10Gi
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 100m
        memory: 128Mi

# Install Promtail for log collection
promtail:
  enabled: true
  config:
    serverPort: 3101
    positions:
      filename: /tmp/positions.yaml
    clients:
      - url: http://loki:3100/loki/api/v1/push
    scrapeConfigs:
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels:
              - __meta_kubernetes_pod_controller_name
            regex: ([0-9a-z-.]+?)(-[0-9a-f]{8,10})?
            target_label: __tmp_controller_name
          - source_labels:
              - __meta_kubernetes_pod_label_app_kubernetes_io_name
              - __meta_kubernetes_pod_label_app
              - __tmp_controller_name
              - __meta_kubernetes_pod_name
            regex: ^;*([^;]+)(;.*)?$
            target_label: app
            replacement: \$1
          - source_labels:
              - __meta_kubernetes_pod_label_app_kubernetes_io_instance
              - __meta_kubernetes_pod_label_release
            regex: ^;*([^;]+)(;.*)?$
            target_label: instance
            replacement: \$1
          - source_labels:
              - __meta_kubernetes_pod_label_app_kubernetes_io_component
              - __meta_kubernetes_pod_label_component
            regex: ^;*([^;]+)(;.*)?$
            target_label: component
            replacement: \$1
          - action: replace
            source_labels:
            - __meta_kubernetes_pod_node_name
            target_label: node_name
          - action: replace
            source_labels:
            - __meta_kubernetes_namespace
            target_label: namespace
          - action: replace
            replacement: /var/log/pods/*\$1/*.log
            separator: /
            source_labels:
            - __meta_kubernetes_pod_uid
            - __meta_kubernetes_pod_container_name
            target_label: __path__

# Gateway for external access
gateway:
  enabled: true
  service:
    type: ClusterIP

# Service configuration
service:
  type: ClusterIP
  port: 3100

# Ingress disabled - using internal access
ingress:
  enabled: false

# Enable ServiceMonitor for Prometheus scraping
serviceMonitor:
  enabled: true
  labels:
    app: loki
EOF

helm install loki grafana/loki \
  --namespace observability \
  --create-namespace \
  --values /tmp/loki-values.yaml \
  --wait --timeout=600s

# Wait for Loki to be ready
echo "⏳ Waiting for Loki to be ready..."
kubectl wait --for=condition=available statefulset/loki -n observability --timeout=300s

# Verify Loki is accessible
echo "🔍 Verifying Loki installation..."
kubectl exec -n observability deployment/prometheus-kube-prometheus-operator -- \
  wget -qO- http://loki.observability.svc.cluster.local:3100/ready && echo "✅ Loki is ready!"

echo ""
echo "✅ Loki installation completed!"
echo "📝 Loki endpoint: http://loki.observability.svc.cluster.local:3100"
echo "📊 Promtail collecting logs from all pods"
echo "🎯 Check logs in Grafana: http://192.168.0.115:3000"
echo ""
echo "🎯 Next Step: Run 5E-enable-auto-instrumentation.sh to enable auto-instrumentation for todo-app"