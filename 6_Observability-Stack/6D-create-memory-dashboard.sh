#!/bin/bash

echo "=== Creating Cluster Memory Analysis Dashboard ==="
echo ""

# Get datasource UIDs from Grafana
echo "Getting datasource UIDs from Grafana..."
GRAFANA_POD=$(kubectl get pod -n observability -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')

# Wait for Grafana to be ready
kubectl wait --for=condition=ready pod/$GRAFANA_POD -n observability --timeout=60s

PROMETHEUS_UID=$(kubectl exec -n observability $GRAFANA_POD -- curl -s -u admin:admin123 http://localhost:3000/api/datasources/name/Prometheus | grep -o '"uid":"[^"]*"' | cut -d'"' -f4)

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
  name: memory-analysis-dashboard
  namespace: observability
  labels:
    grafana_dashboard: "1"
data:
  memory-analysis.json: |
    {
      "title": "Cluster Memory Analysis (Master vs Worker)",
      "uid": "cluster-memory-analysis",
      "tags": ["memory", "k3s", "troubleshooting", "nodes"],
      "timezone": "browser",
      "schemaVersion": 38,
      "version": 1,
      "refresh": "30s",
      "panels": [
        {
          "id": 1,
          "title": "🧠 Master Node (k3s-master) - Total Memory Usage",
          "type": "stat",
          "gridPos": {"h": 4, "w": 12, "x": 0, "y": 0},
          "targets": [
            {
              "expr": "(node_memory_MemTotal_bytes{instance=\"k3s-master\"} - node_memory_MemAvailable_bytes{instance=\"k3s-master\"}) / 1024 / 1024",
              "refId": "A",
              "legendFormat": "Used"
            },
            {
              "expr": "node_memory_MemTotal_bytes{instance=\"k3s-master\"} / 1024 / 1024",
              "refId": "B",
              "legendFormat": "Total"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "mbytes",
              "color": {"mode": "thresholds"},
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": null, "color": "green"},
                  {"value": 6000, "color": "orange"},
                  {"value": 7500, "color": "red"}
                ]
              }
            }
          }
        },
        {
          "id": 2,
          "title": "👷 Worker Node (k3s-worker) - Total Memory Usage",
          "type": "stat",
          "gridPos": {"h": 4, "w": 12, "x": 12, "y": 0},
          "targets": [
            {
              "expr": "(node_memory_MemTotal_bytes{instance=\"k3s-worker\"} - node_memory_MemAvailable_bytes{instance=\"k3s-worker\"}) / 1024 / 1024",
              "refId": "A",
              "legendFormat": "Used"
            },
            {
              "expr": "node_memory_MemTotal_bytes{instance=\"k3s-worker\"} / 1024 / 1024",
              "refId": "B",
              "legendFormat": "Total"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "mbytes",
              "color": {"mode": "thresholds"},
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": null, "color": "green"},
                  {"value": 6000, "color": "orange"},
                  {"value": 7500, "color": "red"}
                ]
              }
            }
          }
        },
        {
          "id": 3,
          "title": "🏆 Top Memory Consumers - MASTER NODE (k3s-master)",
          "type": "table",
          "gridPos": {"h": 10, "w": 12, "x": 0, "y": 4},
          "targets": [
            {
              "expr": "topk(20, sum(container_memory_working_set_bytes{node=\"k3s-master\", container!=\"\", container!=\"POD\"}) by (namespace, pod)) / 1024 / 1024",
              "refId": "A",
              "format": "table",
              "instant": true
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "transformations": [
            {
              "id": "organize",
              "options": {
                "excludeByName": {
                  "Time": true,
                  "__name__": true
                },
                "renameByName": {
                  "Value": "Memory (MB)",
                  "pod": "Pod Name",
                  "namespace": "Namespace"
                }
              }
            },
            {
              "id": "sortBy",
              "options": {
                "fields": {},
                "sort": [
                  {"field": "Memory (MB)", "desc": true}
                ]
              }
            }
          ],
          "fieldConfig": {
            "defaults": {
              "custom": {
                "align": "auto",
                "displayMode": "auto"
              },
              "unit": "mbytes",
              "color": {
                "mode": "thresholds"
              },
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": null, "color": "transparent"},
                  {"value": 100, "color": "rgba(237, 129, 40, 0.2)"},
                  {"value": 500, "color": "rgba(245, 54, 54, 0.3)"}
                ]
              }
            }
          }
        },
        {
          "id": 4,
          "title": "🏆 Top Memory Consumers - WORKER NODE (k3s-worker)",
          "type": "table",
          "gridPos": {"h": 10, "w": 12, "x": 12, "y": 4},
          "targets": [
            {
              "expr": "topk(20, sum(container_memory_working_set_bytes{node=\"k3s-worker\", container!=\"\", container!=\"POD\"}) by (namespace, pod)) / 1024 / 1024",
              "refId": "A",
              "format": "table",
              "instant": true
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "transformations": [
            {
              "id": "organize",
              "options": {
                "excludeByName": {
                  "Time": true,
                  "__name__": true
                },
                "renameByName": {
                  "Value": "Memory (MB)",
                  "pod": "Pod Name",
                  "namespace": "Namespace"
                }
              }
            },
            {
              "id": "sortBy",
              "options": {
                "fields": {},
                "sort": [
                  {"field": "Memory (MB)", "desc": true}
                ]
              }
            }
          ],
          "fieldConfig": {
            "defaults": {
              "custom": {
                "align": "auto",
                "displayMode": "auto"
              },
              "unit": "mbytes",
              "color": {
                "mode": "thresholds"
              },
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": null, "color": "transparent"},
                  {"value": 100, "color": "rgba(237, 129, 40, 0.2)"},
                  {"value": 500, "color": "rgba(245, 54, 54, 0.3)"}
                ]
              }
            }
          }
        },
        {
          "id": 5,
          "title": "📈 Memory Usage Over Time (Top 5 Pods - Master)",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 0, "y": 14},
          "targets": [
            {
              "expr": "topk(5, sum(container_memory_working_set_bytes{node=\"k3s-master\", container!=\"\", container!=\"POD\"}) by (namespace, pod)) / 1024 / 1024",
              "refId": "A",
              "legendFormat": "{{pod}} ({{namespace}})"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "mbytes",
              "custom": {
                "drawStyle": "line",
                "lineInterpolation": "linear",
                "fillOpacity": 10
              }
            }
          }
        },
        {
          "id": 6,
          "title": "📈 Memory Usage Over Time (Top 5 Pods - Worker)",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 12, "y": 14},
          "targets": [
            {
              "expr": "topk(5, sum(container_memory_working_set_bytes{node=\"k3s-worker\", container!=\"\", container!=\"POD\"}) by (namespace, pod)) / 1024 / 1024",
              "refId": "A",
              "legendFormat": "{{pod}} ({{namespace}})"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "mbytes",
              "custom": {
                "drawStyle": "line",
                "lineInterpolation": "linear",
                "fillOpacity": 10
              }
            }
          }
        }
      ]
    }
EOF

echo ""
echo "✅ Memory Analysis Dashboard Created!"
echo ""
echo "Restarting Grafana to load dashboard..."
kubectl rollout restart deployment/grafana -n observability
kubectl rollout status deployment/grafana -n observability --timeout=120s

echo ""
echo "=== Memory Dashboard Ready ==="
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
echo "Dashboard: Dashboards -> Cluster Memory Analysis (Master vs Worker)"
echo ""
