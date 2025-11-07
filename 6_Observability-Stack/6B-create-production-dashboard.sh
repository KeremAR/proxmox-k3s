#!/bin/bash

echo "=== Creating Production Application Health Dashboard (Deployments) ==="
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
  name: production-health-dashboard
  namespace: observability
  labels:
    grafana_dashboard: "1"
data:
  production-health.json: |
    {
      "title": "Production Environment - Application Health (Deployments)",
      "uid": "prod-health",
      "tags": ["production", "health", "deployments"],
      "timezone": "browser",
      "schemaVersion": 38,
      "version": 1,
      "refresh": "30s",
      "panels": [
        {
          "id": 1,
          "title": "Frontend - Pod Status",
          "type": "stat",
          "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0},
          "targets": [
            {
              "expr": "kube_deployment_status_replicas_available{exported_namespace=\"production\", deployment=\"frontend\"}",
              "refId": "A",
              "legendFormat": "Available"
            },
            {
              "expr": "kube_deployment_spec_replicas{exported_namespace=\"production\", deployment=\"frontend\"}",
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
          "title": "User Service - Pod Status",
          "type": "stat",
          "gridPos": {"h": 4, "w": 6, "x": 6, "y": 0},
          "targets": [
            {
              "expr": "kube_deployment_status_replicas_available{exported_namespace=\"production\", deployment=\"user-service\"}",
              "refId": "A",
              "legendFormat": "Available"
            },
            {
              "expr": "kube_deployment_spec_replicas{exported_namespace=\"production\", deployment=\"user-service\"}",
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
          "title": "Todo Service - Pod Status",
          "type": "stat",
          "gridPos": {"h": 4, "w": 6, "x": 12, "y": 0},
          "targets": [
            {
              "expr": "kube_deployment_status_replicas_available{exported_namespace=\"production\", deployment=\"todo-service\"}",
              "refId": "A",
              "legendFormat": "Available"
            },
            {
              "expr": "kube_deployment_spec_replicas{exported_namespace=\"production\", deployment=\"todo-service\"}",
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
          "title": "Frontend - CPU Usage",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 8, "x": 0, "y": 4},
          "targets": [
            {
              "expr": "sum(rate(container_cpu_usage_seconds_total{namespace=\"production\", pod=~\"frontend-.*\", container!=\"\", container!=\"POD\"}[5m])) by (pod)",
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
          "id": 5,
          "title": "User Service - CPU Usage",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 8, "x": 8, "y": 4},
          "targets": [
            {
              "expr": "sum(rate(container_cpu_usage_seconds_total{namespace=\"production\", pod=~\"user-service-.*\", container!=\"\", container!=\"POD\"}[5m])) by (pod)",
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
          "id": 6,
          "title": "Todo Service - CPU Usage",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 8, "x": 16, "y": 4},
          "targets": [
            {
              "expr": "sum(rate(container_cpu_usage_seconds_total{namespace=\"production\", pod=~\"todo-service-.*\", container!=\"\", container!=\"POD\"}[5m])) by (pod)",
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
          "id": 7,
          "title": "Frontend - Memory Usage",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 8, "x": 0, "y": 12},
          "targets": [
            {
              "expr": "sum(container_memory_working_set_bytes{namespace=\"production\", pod=~\"frontend-.*\", container!=\"\", container!=\"POD\"}) by (pod)",
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
          "id": 8,
          "title": "User Service - Memory Usage",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 8, "x": 8, "y": 12},
          "targets": [
            {
              "expr": "sum(container_memory_working_set_bytes{namespace=\"production\", pod=~\"user-service-.*\", container!=\"\", container!=\"POD\"}) by (pod)",
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
          "id": 9,
          "title": "Todo Service - Memory Usage",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 8, "x": 16, "y": 12},
          "targets": [
            {
              "expr": "sum(container_memory_working_set_bytes{namespace=\"production\", pod=~\"todo-service-.*\", container!=\"\", container!=\"POD\"}) by (pod)",
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
          "id": 10,
          "title": "Frontend - Recent Logs",
          "type": "logs",
          "gridPos": {"h": 10, "w": 24, "x": 0, "y": 20},
          "targets": [
            {
              "expr": "{namespace=\"production\", pod=~\"frontend-.*\"}",
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
          "id": 11,
          "title": "User Service - Recent Logs",
          "type": "logs",
          "gridPos": {"h": 10, "w": 24, "x": 0, "y": 30},
          "targets": [
            {
              "expr": "{namespace=\"production\", pod=~\"user-service-.*\"}",
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
          "id": 12,
          "title": "Todo Service - Recent Logs",
          "type": "logs",
          "gridPos": {"h": 10, "w": 24, "x": 0, "y": 40},
          "targets": [
            {
              "expr": "{namespace=\"production\", pod=~\"todo-service-.*\"}",
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
echo "✅ Production Health Dashboard ConfigMap created!"
echo ""
echo "Restarting Grafana to load dashboard..."
kubectl rollout restart deployment/grafana -n observability
kubectl rollout status deployment/grafana -n observability --timeout=120s

echo ""
echo "=== Production Dashboard Ready ==="
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
echo "Dashboard: Dashboards -> Production Environment - Application Health (Deployments)"
echo ""
echo "Panels included:"
echo "  ✅ Pod Status (Frontend, User Service, Todo Service)"
echo "  ✅ CPU Usage (all services)"
echo "  ✅ Memory Usage (all services)"
echo "  ✅ Recent Logs (from Loki)"
echo ""
echo "Note: FastAPI metrics (HTTP requests, errors, latency) not included yet."
echo "      Production is still using basic deployments. Will add metrics when FastAPI is instrumented."

