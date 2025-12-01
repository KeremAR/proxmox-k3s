#!/bin/bash

echo "=== Creating Microservice Detail Dashboard ==="
echo ""

# Get datasource UIDs from Grafana
echo "Getting datasource UIDs from Grafana..."
GRAFANA_POD=$(kubectl get pod -n observability -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')
INGRESS_IP=$(kubectl get service nginx-ingress-loadbalancer -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Wait for Grafana to be ready
kubectl wait --for=condition=ready pod/$GRAFANA_POD -n observability --timeout=60s

# Get Loki and Prometheus UIDs via Grafana API
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
  name: microservice-detail-dashboard
  namespace: observability
  labels:
    grafana_dashboard: "1"
data:
  microservice-detail.json: |
    {
      "title": "Microservice Detail - RED Method Analysis",
      "uid": "microservice-detail",
      "tags": ["microservice", "red-method", "service", "detail"],
      "timezone": "browser",
      "schemaVersion": 38,
      "version": 1,
      "refresh": "30s",
      "templating": {
        "list": [
          {
            "name": "namespace",
            "type": "query",
            "label": "Namespace",
            "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
            "query": "label_values(rollout_info_replicas_available, namespace)",
            "refresh": 1,
            "includeAll": false,
            "multi": false,
            "sort": 1
          },
          {
            "name": "service",
            "type": "query",
            "label": "Service",
            "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
            "query": "label_values(rollout_info_replicas_available{namespace=\"\$namespace\"}, name)",
            "refresh": 2,
            "includeAll": false,
            "multi": false,
            "sort": 1
          }
        ]
      },
      "panels": [
        {
          "id": 1,
          "title": "🔄 Rollout Status",
          "type": "stat",
          "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0},
          "targets": [
            {
              "expr": "rollout_info_replicas_available{namespace=\"\$namespace\", name=\"\$service\"}",
              "refId": "A",
              "legendFormat": "Available"
            },
            {
              "expr": "rollout_info_replicas_desired{namespace=\"\$namespace\", name=\"\$service\"}",
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
          },
          "options": {
            "reduceOptions": {
              "values": false,
              "calcs": ["lastNotNull"]
            },
            "orientation": "auto",
            "textMode": "value_and_name",
            "colorMode": "background"
          }
        },
        {
          "id": 2,
          "title": "📊 Rate - Request Rate (RPS)",
          "type": "stat",
          "gridPos": {"h": 4, "w": 6, "x": 6, "y": 0},
          "targets": [
            {
              "expr": "sum(rate(http_requests_total{namespace=\"\$namespace\", pod=~\"\$service.*\"}[5m]))",
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
              "unit": "reqps",
              "decimals": 2
            }
          },
          "options": {
            "reduceOptions": {
              "values": false,
              "calcs": ["lastNotNull"]
            },
            "orientation": "auto",
            "textMode": "value_and_name",
            "colorMode": "value"
          }
        },
        {
          "id": 3,
          "title": "🔥 Errors - Error Rate (5xx)",
          "type": "stat",
          "gridPos": {"h": 4, "w": 6, "x": 12, "y": 0},
          "targets": [
            {
              "expr": "sum(rate(http_requests_total{namespace=\"\$namespace\", pod=~\"\$service.*\", status=~\"5..\"}[5m]))",
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
                  {"value": 0.01, "color": "yellow"},
                  {"value": 0.1, "color": "red"}
                ]
              },
              "unit": "reqps",
              "decimals": 3
            }
          },
          "options": {
            "reduceOptions": {
              "values": false,
              "calcs": ["lastNotNull"]
            },
            "orientation": "auto",
            "textMode": "value_and_name",
            "colorMode": "background"
          }
        },
        {
          "id": 4,
          "title": "⏱️ Duration - P95 Latency",
          "type": "stat",
          "gridPos": {"h": 4, "w": 6, "x": 18, "y": 0},
          "targets": [
            {
              "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{namespace=\"\$namespace\", pod=~\"\$service.*\"}[5m])) by (le))",
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
              "unit": "s",
              "decimals": 3
            }
          },
          "options": {
            "reduceOptions": {
              "values": false,
              "calcs": ["lastNotNull"]
            },
            "orientation": "auto",
            "textMode": "value_and_name",
            "colorMode": "background"
          }
        },
        {
          "id": 5,
          "title": "📊 Rate - Request Rate Over Time",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4},
          "targets": [
            {
              "expr": "sum(rate(http_requests_total{namespace=\"\$namespace\", pod=~\"\$service.*\"}[5m])) by (pod)",
              "refId": "A",
              "legendFormat": "{{pod}}"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "reqps",
              "custom": {
                "drawStyle": "line",
                "lineInterpolation": "linear",
                "fillOpacity": 10,
                "showPoints": "never"
              }
            }
          },
          "options": {
            "legend": {
              "displayMode": "table",
              "placement": "bottom",
              "calcs": ["lastNotNull", "max", "mean"]
            }
          }
        },
        {
          "id": 6,
          "title": "🔥 Errors - HTTP Status Code Distribution",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4},
          "targets": [
            {
              "expr": "sum(rate(http_requests_total{namespace=\"\$namespace\", pod=~\"\$service.*\"}[5m])) by (status)",
              "refId": "A",
              "legendFormat": "{{status}}"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "reqps",
              "custom": {
                "drawStyle": "line",
                "lineInterpolation": "linear",
                "fillOpacity": 10,
                "showPoints": "never"
              }
            }
          },
          "options": {
            "legend": {
              "displayMode": "table",
              "placement": "bottom",
              "calcs": ["lastNotNull", "max"]
            }
          }
        },
        {
          "id": 7,
          "title": "⏱️ Duration - Application Latency (p50/p95/p99)",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 0, "y": 12},
          "targets": [
            {
              "expr": "histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket{namespace=\"\$namespace\", pod=~\"\$service.*\"}[5m])) by (le))",
              "refId": "A",
              "legendFormat": "p50 - App Only"
            },
            {
              "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{namespace=\"\$namespace\", pod=~\"\$service.*\"}[5m])) by (le))",
              "refId": "B",
              "legendFormat": "p95 - App Only"
            },
            {
              "expr": "histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{namespace=\"\$namespace\", pod=~\"\$service.*\"}[5m])) by (le))",
              "refId": "C",
              "legendFormat": "p99 - App Only"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "s",
              "custom": {
                "drawStyle": "line",
                "lineInterpolation": "linear",
                "fillOpacity": 5,
                "showPoints": "never"
              },
              "color": {"mode": "palette-classic"}
            }
          },
          "options": {
            "legend": {
              "displayMode": "table",
              "placement": "bottom",
              "calcs": ["lastNotNull", "max", "mean"]
            }
          }
        },
        {
          "id": 7.1,
          "title": "🌐 Duration - End-to-End Latency (Network Included)",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 12, "y": 12},
          "targets": [
            {
              "expr": "probe_duration_seconds{service=\"\$service\", namespace=\"\$namespace\"}",
              "refId": "A",
              "legendFormat": "End-to-End (Blackbox)"
            },
            {
              "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{namespace=\"\$namespace\", pod=~\"\$service.*\"}[5m])) by (le))",
              "refId": "B",
              "legendFormat": "p95 - App Only (comparison)"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "s",
              "custom": {
                "drawStyle": "line",
                "lineInterpolation": "linear",
                "fillOpacity": 10,
                "showPoints": "auto"
              },
              "color": {"mode": "palette-classic"},
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": null, "color": "green"},
                  {"value": 0.5, "color": "yellow"},
                  {"value": 1.0, "color": "orange"},
                  {"value": 2.0, "color": "red"}
                ]
              }
            },
            "overrides": [
              {
                "matcher": {"id": "byName", "options": "End-to-End (Blackbox)"},
                "properties": [
                  {"id": "custom.lineWidth", "value": 2},
                  {"id": "color", "value": {"mode": "fixed", "fixedColor": "blue"}}
                ]
              }
            ]
          },
          "options": {
            "legend": {
              "displayMode": "table",
              "placement": "bottom",
              "calcs": ["lastNotNull", "max", "mean"]
            }
          }
        },
        {
          "id": 8,
          "title": "💻 Resources - CPU Usage by Pod",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 0, "y": 20},
          "targets": [
            {
              "expr": "sum(rate(container_cpu_usage_seconds_total{namespace=\"\$namespace\", pod=~\"\$service.*\", container!=\"\", container!=\"POD\"}[5m])) by (pod)",
              "refId": "A",
              "legendFormat": "{{pod}}"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "cores",
              "custom": {
                "drawStyle": "line",
                "lineInterpolation": "linear",
                "fillOpacity": 10,
                "showPoints": "never"
              }
            }
          },
          "options": {
            "legend": {
              "displayMode": "table",
              "placement": "bottom",
              "calcs": ["lastNotNull", "max"]
            }
          }
        },
        {
          "id": 9,
          "title": "💾 Resources - Memory Usage by Pod",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 12, "y": 20},
          "targets": [
            {
              "expr": "sum(container_memory_working_set_bytes{namespace=\"\$namespace\", pod=~\"\$service.*\", container!=\"\", container!=\"POD\"}) by (pod) / 1024 / 1024",
              "refId": "A",
              "legendFormat": "{{pod}}"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "decmbytes",
              "custom": {
                "drawStyle": "line",
                "lineInterpolation": "linear",
                "fillOpacity": 10,
                "showPoints": "never"
              }
            }
          },
          "options": {
            "legend": {
              "displayMode": "table",
              "placement": "bottom",
              "calcs": ["lastNotNull", "max"]
            }
          }
        },
        {
          "id": 10,
          "title": "📝 Logs - Service Logs (Loki)",
          "type": "logs",
          "gridPos": {"h": 10, "w": 24, "x": 0, "y": 28},
          "targets": [
            {
              "expr": "{namespace=\"\$namespace\", pod=~\"\$service.*\"}",
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
          "id": 11,
          "title": "🔍 Tracing - Jaeger Link",
          "type": "text",
          "gridPos": {"h": 4, "w": 24, "x": 0, "y": 38},
          "options": {
            "mode": "markdown",
            "content": "### 🔍 Distributed Tracing\\n\\n**Service:** \`\$service\`\\n\\n**Namespace:** \`\$namespace\`\\n\\n[🔗 Open Jaeger UI](http://jaeger.$INGRESS_IP.nip.io/search?service=\$service)\\n\\n**Internal Service:** jaeger-query.observability.svc.cluster.local:16686"
          }
        },
        {
          "id": 12,
          "title": "🔄 Pod Restart Rate",
          "type": "timeseries",
          "gridPos": {"h": 6, "w": 12, "x": 0, "y": 42},
          "targets": [
            {
              "expr": "rate(kube_pod_container_status_restarts_total{namespace=\"\$namespace\", pod=~\"\$service.*\"}[5m]) > 0",
              "refId": "A",
              "legendFormat": "{{pod}} - {{container}}"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "short",
              "custom": {
                "drawStyle": "bars",
                "lineInterpolation": "linear",
                "fillOpacity": 50,
                "showPoints": "never"
              },
              "color": {"mode": "palette-classic"},
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": null, "color": "green"},
                  {"value": 0.01, "color": "red"}
                ]
              }
            }
          },
          "options": {
            "legend": {
              "displayMode": "table",
              "placement": "bottom",
              "calcs": ["lastNotNull", "max"]
            }
          }
        },
        {
          "id": 13,
          "title": "⚠️ Pod Status Events",
          "type": "table",
          "gridPos": {"h": 6, "w": 12, "x": 12, "y": 42},
          "targets": [
            {
              "expr": "kube_pod_container_status_waiting_reason{namespace=\"\$namespace\", pod=~\"\$service.*\", reason=~\"CrashLoopBackOff|ImagePullBackOff|ErrImagePull\"} > 0",
              "refId": "A",
              "instant": true,
              "format": "table"
            },
            {
              "expr": "kube_pod_container_status_terminated_reason{namespace=\"\$namespace\", pod=~\"\$service.*\", reason=~\"OOMKilled|Error\"} > 0",
              "refId": "B",
              "instant": true,
              "format": "table"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "transformations": [
            {
              "id": "merge"
            },
            {
              "id": "organize",
              "options": {
                "excludeByName": {
                  "Time": true,
                  "__name__": true,
                  "job": true,
                  "instance": true,
                  "endpoint": true,
                  "service": true,
                  "namespace": true,
                  "uid": true
                },
                "indexByName": {
                  "pod": 0,
                  "container": 1,
                  "reason": 2,
                  "Value": 3
                },
                "renameByName": {
                  "pod": "Pod",
                  "container": "Container",
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
                          "ErrImagePull": {"color": "dark-yellow", "text": "🟡 ErrImagePull"}
                        }
                      },
                      {
                        "type": "value",
                        "options": {
                          "Error": {"color": "dark-red", "text": "🔴 Error"}
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
        }
      ]
    }
EOF

echo ""
echo "✅ Microservice Detail Dashboard Created!"
echo ""

# Get Nginx Ingress LoadBalancer IP
INGRESS_IP=$(kubectl get service nginx-ingress-loadbalancer -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')



echo ""
echo "Restarting Grafana to load dashboard..."
kubectl rollout restart deployment/grafana -n observability
kubectl rollout status deployment/grafana -n observability --timeout=120s

echo ""
echo "=== Microservice Detail Dashboard Ready ==="
echo ""

if [ -z "$INGRESS_IP" ]; then
    echo "Access Grafana: http://grafana.observability.svc.cluster.local:80"
    echo "Access Jaeger: http://jaeger-query.observability.svc.cluster.local:16686"
else
    echo "🔗 Access Grafana: http://grafana.${INGRESS_IP}.nip.io"
    echo "🔗 Access Jaeger: http://jaeger.${INGRESS_IP}.nip.io"
fi

echo "Username: admin"
echo "Password: admin123"
echo ""
echo "Dashboard: Dashboards -> Microservice Detail - RED Method Analysis"
echo ""
echo "📊 DASHBOARD STRUCTURE (RED Method):"
echo ""
echo "🎯 Top Row - RED Method KPIs:"
echo "  • Rollout Status - Argo Rollouts availability"
echo "  • Rate - Request Rate (RPS)"
echo "  • Errors - Error Rate (5xx)"
echo "  • Duration - P95 Latency"
echo ""
echo "📈 RED Method Details:"
echo "  • Rate - Request Rate Over Time"
echo "  • Errors - HTTP Status Code Distribution (2xx/4xx/5xx)"
echo "  • Duration - Latency Percentiles (p50/p95/p99)"
echo ""
echo "💻 Resources:"
echo "  • CPU Usage by Pod"
echo "  • Memory Usage by Pod"
echo ""
echo "📝 Logs & Tracing:"
echo "  • Service Logs (Loki) - Real-time log viewer"
echo "  • Jaeger Tracing Link - Distributed tracing integration"
echo ""
echo "⚠️ Health Indicators:"
echo "  • Pod Restart Rate - Detects instability"
echo "  • Pod Status Events - OOMKilled, CrashLoop, ImagePull errors"
echo ""
echo "💡 VARIABLE USAGE:"
echo "  • \$namespace - Select target namespace"
echo "  • \$service - Select target service (auto-populated based on namespace)"
echo ""
echo "🔗 DRILL-DOWN FROM:"
echo "  • Global SRE Overview Dashboard → Click service name in Health Grid"
echo "  • URL Parameters: ?var-namespace=staging&var-service=user-service"
echo ""
echo "Total Panels: 13 (RED Method + Resources + Logs + Tracing)"
echo ""

