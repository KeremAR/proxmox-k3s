#!/bin/bash

echo "=== Creating Production Application Health Dashboard ==="
echo ""

# Get Loki datasource UID from Grafana
echo "Getting Loki datasource UID from Grafana..."
GRAFANA_POD=$(kubectl get pod -n observability -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')

# Wait for Grafana to be ready
kubectl wait --for=condition=ready pod/$GRAFANA_POD -n observability --timeout=60s

# Get Loki UID via Grafana API
LOKI_UID=$(kubectl exec -n observability $GRAFANA_POD -- curl -s -u admin:admin123 http://localhost:3000/api/datasources/name/Loki | grep -o '"uid":"[^"]*"' | cut -d'"' -f4)

if [ -z "$LOKI_UID" ]; then
    echo "⚠️  Warning: Could not get Loki UID, dashboard logs may not work"
    LOKI_UID="LOKI_UID_NOT_FOUND"
else
    echo "✅ Found Loki UID: $LOKI_UID"
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
  production-health.json: |-
    {
      "title": "Production Application Health",
      "uid": "prod-health",
      "tags": ["production", "health"],
      "timezone": "browser",
      "schemaVersion": 16,
      "version": 0,
      "refresh": "30s",
      "panels": [
        {
          "id": 1,
          "title": "Frontend - Pod Status",
          "type": "stat",
          "gridPos": {"h": 4, "w": 4, "x": 0, "y": 0},
          "targets": [
            {
              "expr": "kube_deployment_status_replicas_available{namespace=\"production\", deployment=\"frontend\"}",
              "refId": "A",
              "legendFormat": "Available"
            },
            {
              "expr": "kube_deployment_spec_replicas{namespace=\"production\", deployment=\"frontend\"}",
              "refId": "B",
              "legendFormat": "Desired"
            }
          ],
          "fieldConfig": {
            "defaults": {
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": 0, "color": "red"},
                  {"value": 1, "color": "green"}
                ]
              }
            }
          }
        },
        {
          "id": 2,
          "title": "User Service - Pod Status",
          "type": "stat",
          "gridPos": {"h": 4, "w": 4, "x": 4, "y": 0},
          "targets": [
            {
              "expr": "kube_deployment_status_replicas_available{namespace=\"production\", deployment=\"user-service\"}",
              "refId": "A",
              "legendFormat": "Available"
            },
            {
              "expr": "kube_deployment_spec_replicas{namespace=\"production\", deployment=\"user-service\"}",
              "refId": "B",
              "legendFormat": "Desired"
            }
          ],
          "fieldConfig": {
            "defaults": {
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": 0, "color": "red"},
                  {"value": 1, "color": "green"}
                ]
              }
            }
          }
        },
        {
          "id": 3,
          "title": "Todo Service - Pod Status",
          "type": "stat",
          "gridPos": {"h": 4, "w": 4, "x": 8, "y": 0},
          "targets": [
            {
              "expr": "kube_deployment_status_replicas_available{namespace=\"production\", deployment=\"todo-service\"}",
              "refId": "A",
              "legendFormat": "Available"
            },
            {
              "expr": "kube_deployment_spec_replicas{namespace=\"production\", deployment=\"todo-service\"}",
              "refId": "B",
              "legendFormat": "Desired"
            }
          ],
          "fieldConfig": {
            "defaults": {
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": 0, "color": "red"},
                  {"value": 1, "color": "green"}
                ]
              }
            }
          }
        },
        {
          "id": 4,
          "title": "Frontend - CPU Usage",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4},
          "targets": [
            {
              "expr": "sum(rate(container_cpu_usage_seconds_total{namespace=\"production\", pod=~\"frontend-.*\", container!=\"\"}[5m])) by (pod)",
              "refId": "A",
              "legendFormat": "{{pod}}"
            }
          ],
          "fieldConfig": {
            "defaults": {
              "unit": "cores"
            }
          }
        },
        {
          "id": 5,
          "title": "User Service - CPU Usage",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4},
          "targets": [
            {
              "expr": "sum(rate(container_cpu_usage_seconds_total{namespace=\"production\", pod=~\"user-service-.*\", container!=\"\"}[5m])) by (pod)",
              "refId": "A",
              "legendFormat": "{{pod}}"
            }
          ],
          "fieldConfig": {
            "defaults": {
              "unit": "cores"
            }
          }
        },
        {
          "id": 6,
          "title": "Todo Service - CPU Usage",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 0, "y": 12},
          "targets": [
            {
              "expr": "sum(rate(container_cpu_usage_seconds_total{namespace=\"production\", pod=~\"todo-service-.*\", container!=\"\"}[5m])) by (pod)",
              "refId": "A",
              "legendFormat": "{{pod}}"
            }
          ],
          "fieldConfig": {
            "defaults": {
              "unit": "cores"
            }
          }
        },
        {
          "id": 7,
          "title": "Frontend - Memory Usage",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 12, "y": 12},
          "targets": [
            {
              "expr": "sum(container_memory_usage_bytes{namespace=\"production\", pod=~\"frontend-.*\", container!=\"\"}) by (pod)",
              "refId": "A",
              "legendFormat": "{{pod}}"
            }
          ],
          "fieldConfig": {
            "defaults": {
              "unit": "bytes"
            }
          }
        },
        {
          "id": 8,
          "title": "Frontend - Recent Logs",
          "type": "logs",
          "gridPos": {"h": 8, "w": 24, "x": 0, "y": 20},
          "targets": [
            {
              "expr": "{namespace=\"production\", pod=~\"frontend-.*\"}",
              "refId": "A"
            }
          ],
          "datasource": {
            "type": "loki",
            "uid": "$LOKI_UID"
          }
        },
        {
          "id": 9,
          "title": "User Service - Recent Logs",
          "type": "logs",
          "gridPos": {"h": 8, "w": 24, "x": 0, "y": 28},
          "targets": [
            {
              "expr": "{namespace=\"production\", pod=~\"user-service-.*\"}",
              "refId": "A"
            }
          ],
          "datasource": {
            "type": "loki",
            "uid": "$LOKI_UID"
          }
        },
        {
          "id": 10,
          "title": "Todo Service - Recent Logs",
          "type": "logs",
          "gridPos": {"h": 8, "w": 24, "x": 0, "y": 36},
          "targets": [
            {
              "expr": "{namespace=\"production\", pod=~\"todo-service-.*\"}",
              "refId": "A"
            }
          ],
          "datasource": {
            "type": "loki",
            "uid": "$LOKI_UID"
          }
        }
      ]
    }
EOF

echo ""
echo "Production Health Dashboard created!"
echo ""
echo "Restarting Grafana to load dashboard..."
kubectl rollout restart deployment -n observability
kubectl rollout status deployment -n observability --timeout=120s


FILE="7-jenkins.sh"
[ -f "$FILE" ] || curl -sO "https://raw.githubusercontent.com/KeremAR/proxmox-k3s/main/7_jenkins-setup/$FILE" && chmod +x "$FILE"

echo ""
echo "=== Dashboard Ready ==="
echo ""

# Get Nginx Ingress LoadBalancer IP
INGRESS_IP=$(kubectl get service nginx-ingress-loadbalancer -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$INGRESS_IP" ]; then
    echo "Access Grafana: http://prometheus-grafana.observability.svc.cluster.local:80"
else
    echo "🔗 Access Grafana: http://grafana.${INGRESS_IP}.nip.io"
fi

echo "Username: admin"
echo "Password: admin123"
echo ""
echo "Dashboard: Dashboards -> Production Application Health"
echo ""
echo "Panels included:"
echo "  - Pod Status (Frontend, User Service, Todo Service)"
echo "  - CPU Usage (All services)"
echo "  - Memory Usage (Frontend)"
echo "  - Recent Logs (All services - from Loki)"
