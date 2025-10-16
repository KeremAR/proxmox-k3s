#!/bin/bash

# ==============================================================================
# 5F - Create Grafana Dashboards for Todo-App Observability
# ==============================================================================
# Purpose: Pre-configured dashboards for application monitoring
# Components: K8s Dashboard, Application Dashboard, OTEL Dashboard
# ==============================================================================

set -e

echo "📈 Creating Grafana Dashboards..."

# Create ConfigMap for Kubernetes Overview Dashboard
echo "🎯 Creating Kubernetes Overview Dashboard..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: kubernetes-overview-dashboard
  namespace: observability
  labels:
    grafana_dashboard: "1"
data:
  kubernetes-overview.json: |
    {
      "dashboard": {
        "id": null,
        "title": "Kubernetes Overview",
        "tags": ["kubernetes"],
        "style": "dark",
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Pod Status",
            "type": "stat",
            "targets": [
              {
                "expr": "kube_pod_status_phase{namespace=\"production\"}",
                "legendFormat": "{{phase}}"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
          },
          {
            "id": 2,
            "title": "CPU Usage",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(container_cpu_usage_seconds_total{namespace=\"production\"}[5m])",
                "legendFormat": "{{pod}}"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
          },
          {
            "id": 3,
            "title": "Memory Usage",
            "type": "graph",
            "targets": [
              {
                "expr": "container_memory_usage_bytes{namespace=\"production\"}",
                "legendFormat": "{{pod}}"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
          },
          {
            "id": 4,
            "title": "Network I/O",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(container_network_receive_bytes_total{namespace=\"production\"}[5m])",
                "legendFormat": "{{pod}} - RX"
              },
              {
                "expr": "rate(container_network_transmit_bytes_total{namespace=\"production\"}[5m])",
                "legendFormat": "{{pod}} - TX"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
          }
        ],
        "time": {"from": "now-1h", "to": "now"},
        "refresh": "30s"
      }
    }
EOF

# Create ConfigMap for Application Performance Dashboard
echo "🚀 Creating Application Performance Dashboard..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: todo-app-dashboard
  namespace: observability
  labels:
    grafana_dashboard: "1"
data:
  todo-app.json: |
    {
      "dashboard": {
        "id": null,
        "title": "Todo-App Performance",
        "tags": ["todo-app", "opentelemetry"],
        "style": "dark",
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "HTTP Request Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(http_requests_total{job=\"otel-collector\"}[5m])",
                "legendFormat": "{{method}} {{status_code}}"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
          },
          {
            "id": 2,
            "title": "HTTP Request Duration",
            "type": "graph",
            "targets": [
              {
                "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job=\"otel-collector\"}[5m]))",
                "legendFormat": "95th percentile"
              },
              {
                "expr": "histogram_quantile(0.50, rate(http_request_duration_seconds_bucket{job=\"otel-collector\"}[5m]))",
                "legendFormat": "50th percentile"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
          },
          {
            "id": 3,
            "title": "Database Connections",
            "type": "stat",
            "targets": [
              {
                "expr": "db_connections_active{job=\"otel-collector\"}",
                "legendFormat": "Active Connections"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
          },
          {
            "id": 4,
            "title": "Error Rate",
            "type": "stat",
            "targets": [
              {
                "expr": "rate(http_requests_total{status_code=~\"5..\",job=\"otel-collector\"}[5m]) / rate(http_requests_total{job=\"otel-collector\"}[5m]) * 100",
                "legendFormat": "Error Rate %"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
          }
        ],
        "time": {"from": "now-1h", "to": "now"},
        "refresh": "15s"
      }
    }
EOF

# Create ConfigMap for OpenTelemetry Collector Dashboard
echo "📊 Creating OTEL Collector Dashboard..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector-dashboard
  namespace: observability
  labels:
    grafana_dashboard: "1"
data:
  otel-collector.json: |
    {
      "dashboard": {
        "id": null,
        "title": "OpenTelemetry Collector",
        "tags": ["opentelemetry", "collector"],
        "style": "dark",
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Spans Received",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(otelcol_receiver_accepted_spans_total[5m])",
                "legendFormat": "{{receiver}}"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
          },
          {
            "id": 2,
            "title": "Metrics Received",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(otelcol_receiver_accepted_metric_points_total[5m])",
                "legendFormat": "{{receiver}}"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
          },
          {
            "id": 3,
            "title": "Logs Received",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(otelcol_receiver_accepted_log_records_total[5m])",
                "legendFormat": "{{receiver}}"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
          },
          {
            "id": 4,
            "title": "Export Queue Size",
            "type": "graph",
            "targets": [
              {
                "expr": "otelcol_exporter_queue_size",
                "legendFormat": "{{exporter}}"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
          }
        ],
        "time": {"from": "now-1h", "to": "now"},
        "refresh": "30s"
      }
    }
EOF

# Restart Grafana to pick up new dashboards
echo "🔄 Restarting Grafana to load dashboards..."
kubectl rollout restart deployment/prometheus-grafana -n observability
kubectl rollout status deployment/prometheus-grafana -n observability --timeout=300s

# Wait a bit for Grafana to fully start
sleep 30

echo ""
echo "✅ Grafana Dashboards created successfully!"
echo ""
echo "📈 Available Dashboards:"
echo "  🎯 Kubernetes Overview - Pod status, CPU, Memory, Network"
echo "  🚀 Todo-App Performance - HTTP metrics, Database connections, Error rates"
echo "  📊 OTEL Collector - Telemetry pipeline monitoring"
echo ""
echo "🔗 Access Grafana: http://192.168.0.115:3000"
echo "👤 Login: admin / admin123"
echo "📂 Dashboards are auto-imported and available in the Dashboards section"
echo ""
echo "🎯 Final Step: Run 5G-test-observability.sh to generate test data and verify setup"