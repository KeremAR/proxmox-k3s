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
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector-dashboard
  namespace: observability
  labels:
    grafana_dashboard: "1"
data:
  otel-collector.json: |-
    {
      "annotations": {
        "list": []
      },
      "editable": true,
      "fiscalYearStartMonth": 0,
      "graphTooltip": 0,
      "id": null,
      "links": [],
      "panels": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "barWidthFactor": 0.6,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "tooltip": false,
                  "viz": false,
                  "legend": false
                },
                "insertNulls": false,
                "lineInterpolation": "linear",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "short"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 0,
            "y": 0
          },
          "id": 1,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "mode": "multi",
              "sort": "none"
            }
          },
          "pluginVersion": "11.4.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "expr": "otelcol_exporter_sent_spans_total",
              "legendFormat": "Spans Sent to {{exporter}}",
              "refId": "A"
            }
          ],
          "title": "OTEL Spans Sent to Jaeger",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "yellow",
                    "value": 1000
                  },
                  {
                    "color": "red",
                    "value": 5000
                  }
                ]
              },
              "unit": "short"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 12,
            "y": 0
          },
          "id": 2,
          "options": {
            "colorMode": "value",
            "graphMode": "area",
            "justifyMode": "auto",
            "orientation": "auto",
            "percentChangeColorMode": "standard",
            "reduceOptions": {
              "calcs": [
                "lastNotNull"
              ],
              "fields": "",
              "values": false
            },
            "showPercentChange": false,
            "textMode": "auto",
            "wideLayout": true
          },
          "pluginVersion": "11.4.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "expr": "otelcol_exporter_sent_spans_total",
              "refId": "A"
            }
          ],
          "title": "Total Spans Sent",
          "type": "stat"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "barWidthFactor": 0.6,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "tooltip": false,
                  "viz": false,
                  "legend": false
                },
                "insertNulls": false,
                "lineInterpolation": "linear",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "short"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 0,
            "y": 8
          },
          "id": 3,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "mode": "multi",
              "sort": "none"
            }
          },
          "pluginVersion": "11.4.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "expr": "otelcol_exporter_queue_size",
              "legendFormat": "Queue: {{exporter}}",
              "refId": "A"
            }
          ],
          "title": "Export Queue Size",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "hideFrom": {
                  "tooltip": false,
                  "viz": false,
                  "legend": false
                }
              },
              "mappings": []
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 12,
            "y": 8
          },
          "id": 4,
          "options": {
            "legend": {
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "pieType": "pie",
            "tooltip": {
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "expr": "sum by (exporter) (otelcol_exporter_sent_spans_total)",
              "legendFormat": "{{exporter}}",
              "refId": "A"
            }
          ],
          "title": "Spans Distribution by Exporter",
          "type": "piechart"
        }
      ],
      "refresh": "30s",
      "schemaVersion": 39,
      "tags": ["opentelemetry", "otel", "collector"],
      "templating": {
        "list": []
      },
      "time": {
        "from": "now-1h",
        "to": "now"
      },
      "timepicker": {},
      "timezone": "browser",
      "title": "OpenTelemetry Collector Metrics",
      "uid": "otel-collector",
      "version": 1,
      "weekStart": ""
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