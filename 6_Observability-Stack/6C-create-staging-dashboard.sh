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
      "title": "Staging Environment - Application Health (Argo Rollouts)",
      "uid": "staging-health",
      "tags": ["staging", "health", "argo-rollouts"],
      "timezone": "browser",
      "schemaVersion": 38,
      "version": 1,
      "refresh": "30s",
      "panels": [
        {
          "id": 1,
          "title": "Frontend - Rollout Replicas",
          "type": "stat",
          "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0},
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
              },
              "unit": "short"
            }
          }
        },
        {
          "id": 2,
          "title": "User Service - Rollout Replicas",
          "type": "stat",
          "gridPos": {"h": 4, "w": 6, "x": 6, "y": 0},
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
              },
              "unit": "short"
            }
          }
        },
        {
          "id": 3,
          "title": "Todo Service - Rollout Replicas",
          "type": "stat",
          "gridPos": {"h": 4, "w": 6, "x": 12, "y": 0},
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
              },
              "unit": "short"
            }
          }
        },
        {
          "id": 4,
          "title": "User Service - HTTP Request Rate",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4},
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
          "id": 5,
          "title": "Todo Service - HTTP Request Rate",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4},
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
              "custom": {"drawStyle": "line", "lineInterpolation": "linear", "fillOpacity": 10}
            }
          }
        },
        {
          "id": 6,
          "title": "User Service - HTTP Error Rate (4xx/5xx)",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 0, "y": 12},
          "targets": [
            {
              "expr": "sum(rate(http_requests_total{namespace=\"staging\", pod=~\"user-service-.*\", status=~\"4xx|5xx\"}[5m]))",
              "refId": "A",
              "legendFormat": "Errors"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "reqps",
              "custom": {"drawStyle": "line", "lineInterpolation": "linear", "fillOpacity": 20},
              "color": {"mode": "palette-classic"},
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": null, "color": "green"},
                  {"value": 0.1, "color": "yellow"},
                  {"value": 1, "color": "red"}
                ]
              }
            }
          }
        },
        {
          "id": 7,
          "title": "Todo Service - HTTP Error Rate (4xx/5xx)",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 12, "y": 12},
          "targets": [
            {
              "expr": "sum(rate(http_requests_total{namespace=\"staging\", pod=~\"todo-service-.*\", status=~\"4xx|5xx\"}[5m]))",
              "refId": "A",
              "legendFormat": "Errors"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "reqps",
              "custom": {"drawStyle": "line", "lineInterpolation": "linear", "fillOpacity": 20},
              "color": {"mode": "palette-classic"},
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": null, "color": "green"},
                  {"value": 0.1, "color": "yellow"},
                  {"value": 1, "color": "red"}
                ]
              }
            }
          }
        },
        {
          "id": 8,
          "title": "User Service - Request Latency (p50, p95, p99)",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 0, "y": 20},
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
              "custom": {"drawStyle": "line", "lineInterpolation": "linear", "fillOpacity": 0}
            }
          }
        },
        {
          "id": 9,
          "title": "Todo Service - Request Latency (p50, p95, p99)",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 12, "y": 20},
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
              "custom": {"drawStyle": "line", "lineInterpolation": "linear", "fillOpacity": 0}
            }
          }
        },
        {
          "id": 10,
          "title": "Frontend - CPU Usage",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 8, "x": 0, "y": 28},
          "targets": [
            {
              "expr": "sum(rate(container_cpu_usage_seconds_total{namespace=\"staging\", pod=~\"frontend-.*\", container!=\"\", container!=\"POD\"}[5m])) by (pod)",
              "refId": "A",
              "legendFormat": "{{pod}}"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "cores",
              "custom": {"drawStyle": "line", "lineInterpolation": "linear", "fillOpacity": 10}
            }
          }
        },
        {
          "id": 11,
          "title": "User Service - CPU Usage",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 8, "x": 8, "y": 28},
          "targets": [
            {
              "expr": "sum(rate(container_cpu_usage_seconds_total{namespace=\"staging\", pod=~\"user-service-.*\", container!=\"\", container!=\"POD\"}[5m])) by (pod)",
              "refId": "A",
              "legendFormat": "{{pod}}"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "cores",
              "custom": {"drawStyle": "line", "lineInterpolation": "linear", "fillOpacity": 10}
            }
          }
        },
        {
          "id": 12,
          "title": "Todo Service - CPU Usage",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 8, "x": 16, "y": 28},
          "targets": [
            {
              "expr": "sum(rate(container_cpu_usage_seconds_total{namespace=\"staging\", pod=~\"todo-service-.*\", container!=\"\", container!=\"POD\"}[5m])) by (pod)",
              "refId": "A",
              "legendFormat": "{{pod}}"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "cores",
              "custom": {"drawStyle": "line", "lineInterpolation": "linear", "fillOpacity": 10}
            }
          }
        },
        {
          "id": 13,
          "title": "Frontend - Memory Usage",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 8, "x": 0, "y": 36},
          "targets": [
            {
              "expr": "sum(container_memory_working_set_bytes{namespace=\"staging\", pod=~\"frontend-.*\", container!=\"\", container!=\"POD\"}) by (pod)",
              "refId": "A",
              "legendFormat": "{{pod}}"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "bytes",
              "custom": {"drawStyle": "line", "lineInterpolation": "linear", "fillOpacity": 10}
            }
          }
        },
        {
          "id": 14,
          "title": "User Service - Memory Usage",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 8, "x": 8, "y": 36},
          "targets": [
            {
              "expr": "sum(container_memory_working_set_bytes{namespace=\"staging\", pod=~\"user-service-.*\", container!=\"\", container!=\"POD\"}) by (pod)",
              "refId": "A",
              "legendFormat": "{{pod}}"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "bytes",
              "custom": {"drawStyle": "line", "lineInterpolation": "linear", "fillOpacity": 10}
            }
          }
        },
        {
          "id": 15,
          "title": "Todo Service - Memory Usage",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 8, "x": 16, "y": 36},
          "targets": [
            {
              "expr": "sum(container_memory_working_set_bytes{namespace=\"staging\", pod=~\"todo-service-.*\", container!=\"\", container!=\"POD\"}) by (pod)",
              "refId": "A",
              "legendFormat": "{{pod}}"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "bytes",
              "custom": {"drawStyle": "line", "lineInterpolation": "linear", "fillOpacity": 10}
            }
          }
        },
        {
          "id": 16,
          "title": "Frontend - Recent Logs",
          "type": "logs",
          "gridPos": {"h": 10, "w": 24, "x": 0, "y": 44},
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
            "showCommonLabels": false,
            "wrapLogMessage": false,
            "prettifyLogMessage": false,
            "enableLogDetails": true,
            "sortOrder": "Descending"
          }
        },
        {
          "id": 17,
          "title": "User Service - Recent Logs",
          "type": "logs",
          "gridPos": {"h": 10, "w": 24, "x": 0, "y": 54},
          "targets": [
            {
              "expr": "{namespace=\"staging\", pod=~\"user-service-.*\"}",
              "refId": "A"
            }
          ],
          "datasource": {"type": "loki", "uid": "$LOKI_UID"},
          "options": {
            "showTime": true,
            "showLabels": false,
            "showCommonLabels": false,
            "wrapLogMessage": false,
            "prettifyLogMessage": false,
            "enableLogDetails": true,
            "sortOrder": "Descending"
          }
        },
        {
          "id": 18,
          "title": "Todo Service - Recent Logs",
          "type": "logs",
          "gridPos": {"h": 10, "w": 24, "x": 0, "y": 64},
          "targets": [
            {
              "expr": "{namespace=\"staging\", pod=~\"todo-service-.*\"}",
              "refId": "A"
            }
          ],
          "datasource": {"type": "loki", "uid": "$LOKI_UID"},
          "options": {
            "showTime": true,
            "showLabels": false,
            "showCommonLabels": false,
            "wrapLogMessage": false,
            "prettifyLogMessage": false,
            "enableLogDetails": true,
            "sortOrder": "Descending"
          }
        }
      ]
    }
EOF

echo ""
echo "✅ Staging Health Dashboard ConfigMap created!"
echo ""
echo "Restarting Grafana to load dashboard..."
kubectl rollout restart deployment/grafana -n observability
kubectl rollout status deployment/grafana -n observability --timeout=120s

echo ""
echo "=== Staging Dashboard Ready ==="
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
echo "Dashboard: Dashboards -> Staging Environment - Application Health (Argo Rollouts)"
echo ""
echo "Panels included:"
echo "  ✅ Rollout Replicas (Available vs Desired - Frontend, User, Todo)"
echo "  ✅ HTTP Request Rate (by status: 2xx, 4xx, 5xx)"
echo "  ✅ HTTP Error Rate (4xx/5xx)"
echo "  ✅ Request Latency (p50, p95, p99)"
echo "  ✅ CPU Usage (all services)"
echo "  ✅ Memory Usage (all services)"
echo "  ✅ Recent Logs (from Loki)"
