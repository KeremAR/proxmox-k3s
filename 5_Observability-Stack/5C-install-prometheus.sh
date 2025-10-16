#!/bin/bash

# ==============================================================================
# 5C - Install Prometheus + Alertmanager
# ==============================================================================
# Purpose: Metrics collection, storage and alerting
# Components: Prometheus Server, ServiceMonitor for OTEL Collector
# ==============================================================================

set -e

echo "📊 Installing Prometheus..."

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo "📦 Helm not found, installing Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Install Prometheus using kube-prometheus-stack (includes Grafana)
echo "📦 Adding Prometheus Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus Stack
echo "🚀 Installing Prometheus Stack..."
cat <<EOF > /tmp/prometheus-values.yaml
prometheus:
  service:
    type: LoadBalancer
    loadBalancerIP: 192.168.0.114
  prometheusSpec:
    retention: 7d
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi
    additionalScrapeConfigs:
      - job_name: 'otel-collector'
        static_configs:
          - targets: ['otel-collector.observability.svc.cluster.local:8889']
        scrape_interval: 15s
        metrics_path: /metrics

alertmanager:
  enabled: true
  service:
    type: ClusterIP

grafana:
  enabled: true
  service:
    type: LoadBalancer
    loadBalancerIP: 192.168.0.115
  adminPassword: admin123
  persistence:
    enabled: true
    size: 2Gi
  datasources:
    datasources.yaml:
      apiVersion: 1
      datasources:
        - name: Prometheus
          type: prometheus
          url: http://prometheus-kube-prometheus-prometheus.observability.svc.cluster.local:9090
          access: proxy
        - name: Jaeger
          type: jaeger
          url: http://jaeger-query.observability.svc.cluster.local:16686
          access: proxy
          isDefault: false
        - name: Loki
          type: loki
          url: http://loki.observability.svc.cluster.local:3100
          access: proxy
          isDefault: false

nodeExporter:
  enabled: true

kubeStateMetrics:
  enabled: true

defaultRules:
  create: true
  rules:
    alertmanager: true
    etcd: false
    configReloaders: true
    general: true
    k8s: true
    kubeApiserverAvailability: true
    kubeApiserverBurnrate: true
    kubeApiserverHistogram: true
    kubeApiserverSlos: true
    kubelet: true
    kubeProxy: false
    kubePrometheusGeneral: true
    kubePrometheusNodeRecording: true
    kubernetesApps: true
    kubernetesResources: true
    kubernetesStorage: true
    kubernetesSystem: true
    network: true
    node: true
    nodeExporterAlerting: true
    nodeExporterRecording: true
    prometheus: true
    prometheusOperator: true
EOF

helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --create-namespace \
  --install \
  --values /tmp/prometheus-values.yaml \
  --wait --timeout=600s

# Create ServiceMonitor for OTEL Collector
echo "🎯 Creating ServiceMonitor for OTEL Collector..."
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: otel-collector
  namespace: observability
  labels:
    app: otel-collector
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: otel-collector
  endpoints:
  - port: metrics
    interval: 15s
    path: /metrics
EOF

# Wait for Prometheus
echo "⏳ Waiting for Prometheus to be ready..."
kubectl wait --for=condition=available deployment/prometheus-kube-prometheus-operator -n observability --timeout=300s

echo ""
echo "✅ Prometheus installation completed!"
echo "📊 Prometheus UI: http://192.168.0.114:9090"
echo "📈 Grafana UI: http://192.168.0.115:3000 (admin/admin123)"
echo "🎯 OTEL Collector metrics: http://192.168.0.114:9090/targets"
echo ""
echo "🎯 Next Step: Run 5D-install-loki.sh to install Loki logging"