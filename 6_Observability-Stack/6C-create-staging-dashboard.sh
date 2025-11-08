#!/bin/bash

echo "=== Creating Staging Application Health Dashboard (Argo Rollouts) ==="
echo ""

# Get datasource UIDs from Grafana
echo "Getting datasource UIDs from Grafana..."
GRAFANA_POD=$(kubectl get pod -n observability -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')

# Wait for Grafana to be ready
kubectl wait --for=condition=ready pod/$GRAFANA_POD -n observability --timeout=60s

# Get Loki UID via Grafana API
LOKI_UID=$(kubectl exec -n observability $GRAFANA_POD -- curl -s -u admin:admin123 http://localhost:3000/api/datasources/name/Loki | grep -o '"uid":"[^"]*"' | cut -d'"' -f4)
PROMETHEUS_UID=$(kubectl exec -n observability $GRAFANA_POD -- curl -s -u admin:admin123 http://localhost:3000/api/datasources/name/Prometheus | grep -o '"uid":"[^"]*"' | cut -d'"' -f4)

if [ -z "$LOKI_UID" ]; then
    echo "⚠️  Warning: Could not get Loki UID, dashboard logs may not work"
    LOKI_UID="LOKI_UID_NOT_FOUND"
else
    echo "✅ Found Loki UID: $LOKI_UID"
fi

if [ -z "$PROMETHEUS_UID" ]; then
    echo "⚠️  Warning: Could not get Prometheus UID, using default"
    PROMETHEUS_UID="PROMETHEUS_UID_NOT_FOUND"
else
    echo "✅ Found Prometheus UID: $PROMETHEUS_UID"
fi
echo ""

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: staging-health-dashboard
  namespace: observability
  labels:
    grafana_dashboard: "1"
data:
  staging-health.json: |
    {
      "title": "Staging Environment - Elite Troubleshooting Dashboard",
      "uid": "staging-health",
      "tags": ["staging", "health", "argo-rollouts", "troubleshooting"],
      "timezone": "browser",
      "schemaVersion": 38,
      "version": 2,
      "refresh": "30s",
      "panels": [
        {
          "id": 1,
          "title": "🔥 Overall Error Rate (5xx)",
          "type": "stat",
          "gridPos": {"h": 4, "w": 8, "x": 0, "y": 0},
          "targets": [
            {
              "expr": "sum(rate(http_requests_total{namespace=\"staging\", status=~\"5xx\"}[5m]))",
              "refId": "A"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": null, "color": "green"},
                  {"value": 0.1, "color": "yellow"},
                  {"value": 1, "color": "red"}
                ]
              },
              "unit": "reqps"
            }
          }
        },
        {
          "id": 2,
          "title": "📊 Total Request Rate",
          "type": "stat",
          "gridPos": {"h": 4, "w": 8, "x": 8, "y": 0},
          "targets": [
            {
              "expr": "sum(rate(http_requests_total{namespace=\"staging\"}[5m]))",
              "refId": "A"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": null, "color": "blue"}
                ]
              },
              "unit": "reqps"
            }
          }
        },
        {
          "id": 3,
          "title": "⏱️ Worst Latency (p99)",
          "type": "stat",
          "gridPos": {"h": 4, "w": 8, "x": 16, "y": 0},
          "targets": [
            {
              "expr": "max(histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{namespace=\"staging\"}[5m])) by (le, pod)))",
              "refId": "A"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": null, "color": "green"},
                  {"value": 0.5, "color": "yellow"},
                  {"value": 1, "color": "red"}
                ]
              },
              "unit": "s"
            }
          }
        },
        {
          "id": 4,
          "title": "🔄 Pod Restart Rate (Last 5m)",
          "type": "timeseries",
          "gridPos": {"h": 6, "w": 12, "x": 0, "y": 4},
          "targets": [
            {
              "expr": "rate(kube_pod_container_status_restarts_total{namespace=\"staging\"}[5m]) > 0",
              "refId": "A",
              "legendFormat": "{{pod}} - {{container}}"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "short",
              "custom": {"drawStyle": "bars", "lineInterpolation": "linear", "fillOpacity": 50},
              "color": {"mode": "palette-classic"},
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": null, "color": "green"},
                  {"value": 0.01, "color": "red"}
                ]
              }
            }
          }
        },
        {
          "id": 5,
          "title": "⚠️ Pod Status Events (OOMKilled, CrashLoop, ImagePull)",
          "type": "table",
          "gridPos": {"h": 6, "w": 12, "x": 12, "y": 4},
          "targets": [
            {
              "expr": "kube_pod_status_reason{namespace=\"staging\", reason=~\"OOMKilled|CrashLoopBackOff|ImagePullBackOff|Evicted|FailedScheduling\"} > 0",
              "refId": "A",
              "instant": true,
              "format": "table"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "transformations": [
            {
              "id": "organize",
              "options": {
                "excludeByName": {
                  "Time": true,
                  "__name__": true,
                  "job": true,
                  "instance": true,
                  "container": true,
                  "endpoint": true,
                  "service": true
                },
                "indexByName": {
                  "pod": 0,
                  "reason": 1,
                  "Value": 2
                },
                "renameByName": {
                  "pod": "Pod",
                  "reason": "Event Reason",
                  "Value": "Status"
                }
              }
            }
          ],
          "fieldConfig": {
            "defaults": {
              "custom": {
                "align": "left",
                "displayMode": "color-background"
              },
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": null, "color": "green"},
                  {"value": 1, "color": "red"}
                ]
              }
            },
            "overrides": [
              {
                "matcher": {"id": "byName", "options": "Event Reason"},
                "properties": [
                  {
                    "id": "custom.displayMode",
                    "value": "color-text"
                  },
                  {
                    "id": "mappings",
                    "value": [
                      {
                        "type": "value",
                        "options": {
                          "OOMKilled": {"color": "dark-red", "text": "🔴 OOMKilled (Memory Limit)"}
                        }
                      },
                      {
                        "type": "value",
                        "options": {
                          "CrashLoopBackOff": {"color": "dark-orange", "text": "🟠 CrashLoopBackOff"}
                        }
                      },
                      {
                        "type": "value",
                        "options": {
                          "ImagePullBackOff": {"color": "dark-yellow", "text": "🟡 ImagePullBackOff"}
                        }
                      },
                      {
                        "type": "value",
                        "options": {
                          "Evicted": {"color": "dark-purple", "text": "🟣 Evicted (Node Pressure)"}
                        }
                      },
                      {
                        "type": "value",
                        "options": {
                          "FailedScheduling": {"color": "dark-blue", "text": "🔵 FailedScheduling"}
                        }
                      }
                    ]
                  }
                ]
              }
            ]
          },
          "options": {
            "showHeader": true,
            "sortBy": []
          }
        },
        {
          "id": 10,
          "title": "📱 FRONTEND - Rollout Status",
          "type": "stat",
          "gridPos": {"h": 3, "w": 4, "x": 0, "y": 10},
          "targets": [
            {
              "expr": "rollout_info_replicas_available{namespace=\"staging\", name=\"frontend\"}",
              "refId": "A",
              "legendFormat": "Available"
            },
            {
              "expr": "rollout_info_replicas_desired{namespace=\"staging\", name=\"frontend\"}",
              "refId": "B",
              "legendFormat": "Desired"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": null, "color": "red"},
                  {"value": 1, "color": "green"}
                ]
              }
            }
          }
        },
        {
          "id": 11,
          "title": "📱 FRONTEND - CPU & Memory",
          "type": "timeseries",
          "gridPos": {"h": 6, "w": 10, "x": 4, "y": 10},
          "targets": [
            {
              "expr": "sum(rate(container_cpu_usage_seconds_total{namespace=\"staging\", pod=~\"frontend-.*\", container!=\"\", container!=\"POD\"}[5m]))",
              "refId": "A",
              "legendFormat": "CPU (cores)"
            },
            {
              "expr": "sum(container_memory_working_set_bytes{namespace=\"staging\", pod=~\"frontend-.*\", container!=\"\", container!=\"POD\"}) / 1024 / 1024",
              "refId": "B",
              "legendFormat": "Memory (MB)"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "custom": {"drawStyle": "line", "lineInterpolation": "linear", "fillOpacity": 10},
              "unit": "short"
            },
            "overrides": [
              {"matcher": {"id": "byName", "options": "CPU (cores)"}, "properties": [{"id": "unit", "value": "cores"}]},
              {"matcher": {"id": "byName", "options": "Memory (MB)"}, "properties": [{"id": "unit", "value": "decmbytes"}]}
            ]
          }
        },
        {
          "id": 12,
          "title": "📱 FRONTEND - Logs",
          "type": "logs",
          "gridPos": {"h": 6, "w": 10, "x": 14, "y": 10},
          "targets": [
            {
              "expr": "{namespace=\"staging\", pod=~\"frontend-.*\"}",
              "refId": "A"
            }
          ],
          "datasource": {"type": "loki", "uid": "$LOKI_UID"},
          "options": {
            "showTime": true,
            "showLabels": false,
            "wrapLogMessage": true,
            "enableLogDetails": true,
            "sortOrder": "Descending"
          }
        },
        {
          "id": 20,
          "title": "👤 USER SERVICE - Rollout Status",
          "type": "stat",
          "gridPos": {"h": 3, "w": 4, "x": 0, "y": 16},
          "targets": [
            {
              "expr": "rollout_info_replicas_available{namespace=\"staging\", name=\"user-service\"}",
              "refId": "A",
              "legendFormat": "Available"
            },
            {
              "expr": "rollout_info_replicas_desired{namespace=\"staging\", name=\"user-service\"}",
              "refId": "B",
              "legendFormat": "Desired"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": null, "color": "red"},
                  {"value": 1, "color": "green"}
                ]
              }
            }
          }
        },
        {
          "id": 21,
          "title": "👤 USER SERVICE - HTTP Rate by Status",
          "type": "timeseries",
          "gridPos": {"h": 6, "w": 10, "x": 4, "y": 16},
          "targets": [
            {
              "expr": "sum(rate(http_requests_total{namespace=\"staging\", pod=~\"user-service-.*\"}[5m])) by (status)",
              "refId": "A",
              "legendFormat": "{{status}}"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "reqps",
              "custom": {"drawStyle": "line", "lineInterpolation": "linear", "fillOpacity": 10}
            }
          }
        },
        {
          "id": 22,
          "title": "👤 USER SERVICE - Latency (p50/p95/p99)",
          "type": "timeseries",
          "gridPos": {"h": 6, "w": 10, "x": 14, "y": 16},
          "targets": [
            {
              "expr": "histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket{namespace=\"staging\", pod=~\"user-service-.*\"}[5m])) by (le))",
              "refId": "A",
              "legendFormat": "p50"
            },
            {
              "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{namespace=\"staging\", pod=~\"user-service-.*\"}[5m])) by (le))",
              "refId": "B",
              "legendFormat": "p95"
            },
            {
              "expr": "histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{namespace=\"staging\", pod=~\"user-service-.*\"}[5m])) by (le))",
              "refId": "C",
              "legendFormat": "p99"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "s",
              "custom": {"drawStyle": "line", "lineInterpolation": "linear"}
            }
          }
        },
        {
          "id": 23,
          "title": "👤 USER SERVICE - Error Rate (5xx)",
          "type": "timeseries",
          "gridPos": {"h": 3, "w": 4, "x": 0, "y": 19},
          "targets": [
            {
              "expr": "sum(rate(http_requests_total{namespace=\"staging\", pod=~\"user-service-.*\", status=~\"5xx\"}[5m]))",
              "refId": "A"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "reqps",
              "custom": {"drawStyle": "line", "fillOpacity": 30},
              "color": {"mode": "fixed", "fixedColor": "red"}
            }
          }
        },
        {
          "id": 24,
          "title": "👤 USER SERVICE - CPU & Memory",
          "type": "timeseries",
          "gridPos": {"h": 6, "w": 12, "x": 0, "y": 22},
          "targets": [
            {
              "expr": "sum(rate(container_cpu_usage_seconds_total{namespace=\"staging\", pod=~\"user-service-.*\", container!=\"\", container!=\"POD\"}[5m]))",
              "refId": "A",
              "legendFormat": "CPU (cores)"
            },
            {
              "expr": "sum(container_memory_working_set_bytes{namespace=\"staging\", pod=~\"user-service-.*\", container!=\"\", container!=\"POD\"}) / 1024 / 1024",
              "refId": "B",
              "legendFormat": "Memory (MB)"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "custom": {"drawStyle": "line", "fillOpacity": 10}
            },
            "overrides": [
              {"matcher": {"id": "byName", "options": "CPU (cores)"}, "properties": [{"id": "unit", "value": "cores"}]},
              {"matcher": {"id": "byName", "options": "Memory (MB)"}, "properties": [{"id": "unit", "value": "decmbytes"}]}
            ]
          }
        },
        {
          "id": 25,
          "title": "👤 USER SERVICE - Logs",
          "type": "logs",
          "gridPos": {"h": 6, "w": 12, "x": 12, "y": 22},
          "targets": [
            {
              "expr": "{namespace=\"staging\", pod=~\"user-service-.*\"}",
              "refId": "A"
            }
          ],
          "datasource": {"type": "loki", "uid": "$LOKI_UID"},
          "options": {
            "showTime": true,
            "wrapLogMessage": true,
            "enableLogDetails": true,
            "sortOrder": "Descending"
          }
        },
        {
          "id": 30,
          "title": "📝 TODO SERVICE - Rollout Status",
          "type": "stat",
          "gridPos": {"h": 3, "w": 4, "x": 0, "y": 28},
          "targets": [
            {
              "expr": "rollout_info_replicas_available{namespace=\"staging\", name=\"todo-service\"}",
              "refId": "A",
              "legendFormat": "Available"
            },
            {
              "expr": "rollout_info_replicas_desired{namespace=\"staging\", name=\"todo-service\"}",
              "refId": "B",
              "legendFormat": "Desired"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": null, "color": "red"},
                  {"value": 1, "color": "green"}
                ]
              }
            }
          }
        },
        {
          "id": 31,
          "title": "📝 TODO SERVICE - HTTP Rate by Status",
          "type": "timeseries",
          "gridPos": {"h": 6, "w": 10, "x": 4, "y": 28},
          "targets": [
            {
              "expr": "sum(rate(http_requests_total{namespace=\"staging\", pod=~\"todo-service-.*\"}[5m])) by (status)",
              "refId": "A",
              "legendFormat": "{{status}}"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "reqps",
              "custom": {"drawStyle": "line", "fillOpacity": 10}
            }
          }
        },
        {
          "id": 32,
          "title": "📝 TODO SERVICE - Latency (p50/p95/p99)",
          "type": "timeseries",
          "gridPos": {"h": 6, "w": 10, "x": 14, "y": 28},
          "targets": [
            {
              "expr": "histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket{namespace=\"staging\", pod=~\"todo-service-.*\"}[5m])) by (le))",
              "refId": "A",
              "legendFormat": "p50"
            },
            {
              "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{namespace=\"staging\", pod=~\"todo-service-.*\"}[5m])) by (le))",
              "refId": "B",
              "legendFormat": "p95"
            },
            {
              "expr": "histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{namespace=\"staging\", pod=~\"todo-service-.*\"}[5m])) by (le))",
              "refId": "C",
              "legendFormat": "p99"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "s",
              "custom": {"drawStyle": "line"}
            }
          }
        },
        {
          "id": 33,
          "title": "📝 TODO SERVICE - Error Rate (5xx)",
          "type": "timeseries",
          "gridPos": {"h": 3, "w": 4, "x": 0, "y": 31},
          "targets": [
            {
              "expr": "sum(rate(http_requests_total{namespace=\"staging\", pod=~\"todo-service-.*\", status=~\"5xx\"}[5m]))",
              "refId": "A"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "reqps",
              "custom": {"drawStyle": "line", "fillOpacity": 30},
              "color": {"mode": "fixed", "fixedColor": "red"}
            }
          }
        },
        {
          "id": 34,
          "title": "📝 TODO SERVICE - CPU & Memory",
          "type": "timeseries",
          "gridPos": {"h": 6, "w": 12, "x": 0, "y": 34},
          "targets": [
            {
              "expr": "sum(rate(container_cpu_usage_seconds_total{namespace=\"staging\", pod=~\"todo-service-.*\", container!=\"\", container!=\"POD\"}[5m]))",
              "refId": "A",
              "legendFormat": "CPU (cores)"
            },
            {
              "expr": "sum(container_memory_working_set_bytes{namespace=\"staging\", pod=~\"todo-service-.*\", container!=\"\", container!=\"POD\"}) / 1024 / 1024",
              "refId": "B",
              "legendFormat": "Memory (MB)"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "custom": {"drawStyle": "line", "fillOpacity": 10}
            },
            "overrides": [
              {"matcher": {"id": "byName", "options": "CPU (cores)"}, "properties": [{"id": "unit", "value": "cores"}]},
              {"matcher": {"id": "byName", "options": "Memory (MB)"}, "properties": [{"id": "unit", "value": "decmbytes"}]}
            ]
          }
        },
        {
          "id": 35,
          "title": "📝 TODO SERVICE - Logs",
          "type": "logs",
          "gridPos": {"h": 6, "w": 12, "x": 12, "y": 34},
          "targets": [
            {
              "expr": "{namespace=\"staging\", pod=~\"todo-service-.*\"}",
              "refId": "A"
            }
          ],
          "datasource": {"type": "loki", "uid": "$LOKI_UID"},
          "options": {
            "showTime": true,
            "wrapLogMessage": true,
            "enableLogDetails": true,
            "sortOrder": "Descending"
          }
        },
        {
          "id": 40,
          "title": "🖥️ Node CPU Usage",
          "type": "timeseries",
          "gridPos": {"h": 6, "w": 12, "x": 0, "y": 40},
          "targets": [
            {
              "expr": "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
              "refId": "A",
              "legendFormat": "{{instance}}"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "percent",
              "max": 100,
              "min": 0,
              "custom": {"drawStyle": "line", "fillOpacity": 20}
            }
          }
        },
        {
          "id": 41,
          "title": "🖥️ Node Memory Usage",
          "type": "timeseries",
          "gridPos": {"h": 6, "w": 12, "x": 12, "y": 40},
          "targets": [
            {
              "expr": "100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))",
              "refId": "A",
              "legendFormat": "{{instance}}"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "percent",
              "max": 100,
              "min": 0,
              "custom": {"drawStyle": "line", "fillOpacity": 20}
            }
          }
        }
      ]
    }
EOF

echo ""
echo "✅ Staging Elite Troubleshooting Dashboard Created!"
echo ""
echo "Restarting Grafana to load dashboard..."
kubectl rollout restart deployment/grafana -n observability
kubectl rollout status deployment/grafana -n observability --timeout=120s

echo ""
echo "=== Elite Staging Dashboard Ready ==="
echo ""

# Get Nginx Ingress LoadBalancer IP
INGRESS_IP=$(kubectl get service nginx-ingress-loadbalancer -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$INGRESS_IP" ]; then
    echo "Access Grafana: http://grafana.observability.svc.cluster.local:80"
else
    echo "🔗 Access Grafana: http://grafana.${INGRESS_IP}.nip.io"
fi

echo "Username: admin"
echo "Password: admin123"
echo ""
echo "Dashboard: Dashboards -> Staging Environment - Elite Troubleshooting Dashboard"
echo ""
echo "📊 ELITE DASHBOARD STRUCTURE:"
echo ""
echo "🔥 At-a-Glance (Top Row):"
echo "  • Overall Error Rate (5xx) - Instant health check"
echo "  • Total Request Rate - Traffic volume"
echo "  • Worst Latency (p99) - Performance ceiling"
echo ""
echo "🔄 Pod Health (Row 2):"
echo "  • Pod Restart Rate - WHAT is restarting? (Left)"
echo "  • Pod Status Events - WHY is it restarting? (Right)"
echo "    └─ OOMKilled → Memory limit too low"
echo "    └─ CrashLoopBackOff → Application crash"
echo "    └─ ImagePullBackOff → Image not found"
echo "    └─ Evicted → Node resource pressure"
echo "    └─ FailedScheduling → No resources available"
echo ""
echo "📱 FRONTEND (Row 1):"
echo "  • CPU & Memory Usage"
echo "  • Logs (Loki)"
echo ""
echo "👤 USER SERVICE (Rows 2-3) - Dependency Order:"
echo "  • Rollout Status (Available vs Desired)"
echo "  • HTTP Request Rate (by status: 2xx, 4xx, 5xx)"
echo "  • Latency Percentiles (p50, p95, p99)"
echo "  • Error Rate (5xx)"
echo "  • CPU & Memory"
echo "  • Logs"
echo ""
echo "📝 TODO SERVICE (Rows 4-5) - Root Cause Layer:"
echo "  • Rollout Status (Available vs Desired)"
echo "  • HTTP Request Rate (by status: 2xx, 4xx, 5xx)"
echo "  • Latency Percentiles (p50, p95, p99)"
echo "  • Error Rate (5xx)"
echo "  • CPU & Memory"
echo "  • Logs"
echo ""
echo "🖥️ NODE INFRASTRUCTURE (Bottom):"
echo "  • Node CPU Usage (%) - Host saturation check"
echo "  • Node Memory Usage (%) - Host resource limits"
echo ""
echo "💡 CHAOS TROUBLESHOOTING GUIDE:"
echo "  1. Check At-a-Glance row - Is there a problem?"
echo "  2. Check Pod Restart Rate - Are pods crashing?"
echo "  3. Read BOTTOM-UP (Todo → User → Frontend):"
echo "     └─ Todo Service RED? → Root cause found"
echo "     └─ Todo Service GREEN, User Service RED? → Problem in User Service"
echo "     └─ Both GREEN, Frontend RED? → Problem in Frontend"
echo "  4. Check Node Infrastructure - Is the host saturated?"
echo ""
echo "Total Panels: 16 (Elite troubleshooting structure)"
echo ""
echo "🎯 ROOT CAUSE ANALYSIS PATTERN:"
echo "  Pod Restart + OOMKilled? → Increase memory limits"
echo "  Pod Restart + CrashLoopBackOff? → Check logs for application errors"
echo "  Pod Restart + ImagePullBackOff? → Check image name/registry"
echo "  Pod Restart + Evicted? → Node resource pressure, check Node Infrastructure"

       