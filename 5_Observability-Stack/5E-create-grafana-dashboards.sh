#!/bin/bash#!/bin/bash



# ==============================================================================# ==============================================================================

# 5E - Create Grafana Dashboard for OTEL Collector# 5F - Create Grafana Dashboards for Todo-App Observability

# ==============================================================================# ==============================================================================

# Purpose: Pre-configured dashboard for OpenTelemetry Collector monitoring# Purpose: Pre-configured dashboards for application monitoring

# Components: OTEL Collector metrics visualization# Components: K8s Dashboard, Application Dashboard, OTEL Dashboard

# ==============================================================================# ==============================================================================



set -eset -e



echo "📈 Creating Grafana Dashboard for OTEL Collector..."echo "📈 Creating Grafana Dashboards..."



# Create ConfigMap for OpenTelemetry Collector Dashboard# Create ConfigMap for Kubernetes Overview Dashboard

echo "📊 Creating OTEL Collector Dashboard..."echo "🎯 Creating Kubernetes Overview Dashboard..."

cat <<'EOF' | kubectl apply -f -cat <<EOF | kubectl apply -f -

apiVersion: v1apiVersion: v1

kind: ConfigMapkind: ConfigMap

metadata:metadata:

  name: otel-collector-dashboard  name: kubernetes-overview-dashboard

  namespace: observability  namespace: observability

  labels:  labels:

    grafana_dashboard: "1"    grafana_dashboard: "1"

data:data:

  otel-collector.json: |-  kubernetes-overview.json: |

    {    {

      "title": "OpenTelemetry Collector Metrics",      "dashboard": {

      "uid": "otel-collector",        "id": null,

      "tags": ["opentelemetry", "otel", "collector"],        "title": "Kubernetes Overview",

      "timezone": "browser",        "tags": ["kubernetes"],

      "refresh": "30s",        "style": "dark",

      "time": {        "timezone": "browser",

        "from": "now-1h",        "panels": [

        "to": "now"          {

      },            "id": 1,

      "panels": [            "title": "Pod Status",

        {            "type": "stat",

          "id": 1,            "targets": [

          "title": "OTEL Spans Sent to Jaeger",              {

          "type": "timeseries",                "expr": "kube_pod_status_phase{namespace=\"production\"}",

          "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},                "legendFormat": "{{phase}}"

          "targets": [              }

            {            ],

              "expr": "otelcol_exporter_sent_spans_total",            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}

              "legendFormat": "Spans Sent to {{exporter}}",          },

              "refId": "A"          {

            }            "id": 2,

          ]            "title": "CPU Usage",

        },            "type": "graph",

        {            "targets": [

          "id": 2,              {

          "title": "Total Spans Sent",                "expr": "rate(container_cpu_usage_seconds_total{namespace=\"production\"}[5m])",

          "type": "stat",                "legendFormat": "{{pod}}"

          "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},              }

          "targets": [            ],

            {            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}

              "expr": "otelcol_exporter_sent_spans_total",          },

              "refId": "A"          {

            }            "id": 3,

          ]            "title": "Memory Usage",

        },            "type": "graph",

        {            "targets": [

          "id": 3,              {

          "title": "Export Queue Size",                "expr": "container_memory_usage_bytes{namespace=\"production\"}",

          "type": "timeseries",                "legendFormat": "{{pod}}"

          "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},              }

          "targets": [            ],

            {            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}

              "expr": "otelcol_exporter_queue_size",          },

              "legendFormat": "Queue: {{exporter}}",          {

              "refId": "A"            "id": 4,

            }            "title": "Network I/O",

          ]            "type": "graph",

        },            "targets": [

        {              {

          "id": 4,                "expr": "rate(container_network_receive_bytes_total{namespace=\"production\"}[5m])",

          "title": "Spans Distribution by Exporter",                "legendFormat": "{{pod}} - RX"

          "type": "piechart",              },

          "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},              {

          "targets": [                "expr": "rate(container_network_transmit_bytes_total{namespace=\"production\"}[5m])",

            {                "legendFormat": "{{pod}} - TX"

              "expr": "sum by (exporter) (otelcol_exporter_sent_spans_total)",              }

              "legendFormat": "{{exporter}}",            ],

              "refId": "A"            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}

            }          }

          ]        ],

        },        "time": {"from": "now-1h", "to": "now"},

        {        "refresh": "30s"

          "id": 5,      }

          "title": "OTEL Collector CPU Usage",    }

          "type": "timeseries",EOF

          "gridPos": {"h": 8, "w": 12, "x": 0, "y": 16},

          "targets": [# Create ConfigMap for Application Performance Dashboard

            {echo "🚀 Creating Application Performance Dashboard..."

              "expr": "rate(container_cpu_usage_seconds_total{pod=~\"otel-collector.*\",namespace=\"observability\"}[5m])",cat <<EOF | kubectl apply -f -

              "legendFormat": "{{pod}}",apiVersion: v1

              "refId": "A"kind: ConfigMap

            }metadata:

          ]  name: todo-app-dashboard

        },  namespace: observability

        {  labels:

          "id": 6,    grafana_dashboard: "1"

          "title": "OTEL Collector Memory Usage",data:

          "type": "timeseries",  todo-app.json: |

          "gridPos": {"h": 8, "w": 12, "x": 12, "y": 16},    {

          "targets": [      "dashboard": {

            {        "id": null,

              "expr": "container_memory_usage_bytes{pod=~\"otel-collector.*\",namespace=\"observability\"}",        "title": "Todo-App Performance",

              "legendFormat": "{{pod}}",        "tags": ["todo-app", "opentelemetry"],

              "refId": "A"        "style": "dark",

            }        "timezone": "browser",

          ]        "panels": [

        }          {

      ]            "id": 1,

    }            "title": "HTTP Request Rate",

EOF            "type": "graph",

            "targets": [

# Restart Grafana to pick up new dashboard              {

echo "🔄 Restarting Grafana to load dashboard..."                "expr": "rate(http_requests_total{job=\"otel-collector\"}[5m])",

kubectl rollout restart deployment/prometheus-grafana -n observability                "legendFormat": "{{method}} {{status_code}}"

kubectl rollout status deployment/prometheus-grafana -n observability --timeout=300s              }

            ],

# Wait for Grafana to fully start            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}

echo "⏳ Waiting for Grafana to be ready..."          },

sleep 30          {

            "id": 2,

echo ""            "title": "HTTP Request Duration",

echo "✅ Grafana Dashboard created successfully!"            "type": "graph",

echo ""            "targets": [

echo "📈 Available Dashboard:"              {

echo "  📊 OpenTelemetry Collector Metrics"                "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job=\"otel-collector\"}[5m]))",

echo "     - Spans sent to Jaeger"                "legendFormat": "95th percentile"

echo "     - Total spans (cumulative)"              },

echo "     - Export queue size"              {

echo "     - Spans distribution"                "expr": "histogram_quantile(0.50, rate(http_request_duration_seconds_bucket{job=\"otel-collector\"}[5m]))",

echo "     - CPU & Memory usage"                "legendFormat": "50th percentile"

echo ""              }

echo "🔗 Access Grafana: http://192.168.0.115:3000"            ],

echo "👤 Login: admin / admin123"            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}

echo "📂 Dashboard: Dashboards → OpenTelemetry Collector Metrics"          },

echo ""          {

echo "🎯 Next Step: Run 5F-test-observability.sh to generate test data and verify setup"            "id": 3,

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