#!/bin/bash

echo "=== Creating Infrastructure & Cluster Dashboard ==="
echo ""

# Get datasource UIDs from Grafana
echo "Getting datasource UIDs from Grafana..."
GRAFANA_POD=$(kubectl get pod -n observability -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')

# Wait for Grafana to be ready
kubectl wait --for=condition=ready pod/$GRAFANA_POD -n observability --timeout=60s

# Get Prometheus UID via Grafana API
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
  name: infrastructure-cluster-dashboard
  namespace: observability
  labels:
    grafana_dashboard: "1"
data:
  infrastructure-cluster.json: |
    {
      "title": "Infrastructure & Cluster - Node & Pod Resource Analysis",
      "uid": "infrastructure-cluster",
      "tags": ["infrastructure", "cluster", "nodes", "pods", "resources"],
      "timezone": "browser",
      "schemaVersion": 38,
      "version": 1,
      "refresh": "30s",
      "templating": {
        "list": [
          {
            "name": "node",
            "type": "query",
            "label": "Node",
            "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
            "query": "label_values(node_uname_info, instance)",
            "refresh": 1,
            "includeAll": true,
            "multi": false,
            "allValue": ".*",
            "current": {
              "selected": false,
              "text": "All",
              "value": "\$__all"
            }
          }
        ]
      },
      "panels": [
        {
          "id": 1,
          "title": "🖥️ Cluster CPU Saturation (%)",
          "type": "stat",
          "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0},
          "targets": [
            {
              "expr": "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
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
                  {"value": 70, "color": "yellow"},
                  {"value": 85, "color": "red"}
                ]
              },
              "unit": "percent",
              "decimals": 1
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
          "title": "🧠 Cluster Memory Saturation (%)",
          "type": "stat",
          "gridPos": {"h": 4, "w": 6, "x": 6, "y": 0},
          "targets": [
            {
              "expr": "100 * (1 - (sum(node_memory_MemAvailable_bytes) / sum(node_memory_MemTotal_bytes)))",
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
                  {"value": 75, "color": "yellow"},
                  {"value": 90, "color": "red"}
                ]
              },
              "unit": "percent",
              "decimals": 1
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
          "id": 3,
          "title": "💾 Cluster Disk Usage (%)",
          "type": "stat",
          "gridPos": {"h": 4, "w": 6, "x": 12, "y": 0},
          "targets": [
            {
              "expr": "100 - ((sum(node_filesystem_avail_bytes{fstype!~\"tmpfs|fuse.lxcfs|squashfs|vfat\"}) / sum(node_filesystem_size_bytes{fstype!~\"tmpfs|fuse.lxcfs|squashfs|vfat\"})) * 100)",
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
                  {"value": 80, "color": "yellow"},
                  {"value": 90, "color": "red"}
                ]
              },
              "unit": "percent",
              "decimals": 1
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
          "title": "📡 Network Traffic (In/Out)",
          "type": "stat",
          "gridPos": {"h": 4, "w": 6, "x": 18, "y": 0},
          "targets": [
            {
              "expr": "sum(rate(node_network_receive_bytes_total{device!~\"lo|veth.*|docker.*|flannel.*|cali.*\"}[5m])) / 1024 / 1024",
              "refId": "A",
              "legendFormat": "In"
            },
            {
              "expr": "sum(rate(node_network_transmit_bytes_total{device!~\"lo|veth.*|docker.*|flannel.*|cali.*\"}[5m])) / 1024 / 1024",
              "refId": "B",
              "legendFormat": "Out"
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
              "unit": "MBs",
              "decimals": 2
            }
          },
          "options": {
            "reduceOptions": {
              "values": false,
              "calcs": ["lastNotNull"]
            },
            "orientation": "auto",
            "textMode": "value",
            "colorMode": "value"
          }
        },
        {
          "id": 5,
          "title": "🖥️ Node CPU Usage (%) - Filtered by \$node",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4},
          "targets": [
            {
              "expr": "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\", instance=~\"\$node\"}[5m])) * 100)",
              "refId": "A",
              "legendFormat": "{{instance}}"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "percent",
              "min": 0,
              "max": 100,
              "custom": {
                "drawStyle": "line",
                "lineInterpolation": "linear",
                "fillOpacity": 20,
                "showPoints": "never"
              },
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": null, "color": "green"},
                  {"value": 70, "color": "yellow"},
                  {"value": 85, "color": "red"}
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
          "id": 6,
          "title": "🧠 Node Memory Usage (%) - Filtered by \$node",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4},
          "targets": [
            {
              "expr": "100 * (1 - (node_memory_MemAvailable_bytes{instance=~\"\$node\"} / node_memory_MemTotal_bytes{instance=~\"\$node\"}))",
              "refId": "A",
              "legendFormat": "{{instance}}"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "percent",
              "min": 0,
              "max": 100,
              "custom": {
                "drawStyle": "line",
                "lineInterpolation": "linear",
                "fillOpacity": 20,
                "showPoints": "never"
              },
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": null, "color": "green"},
                  {"value": 75, "color": "yellow"},
                  {"value": 90, "color": "red"}
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
          "id": 7,
          "title": "💾 Node Disk I/O (Read/Write MB/s) - Filtered by \$node",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 0, "y": 12},
          "targets": [
            {
              "expr": "sum by (instance) (rate(node_disk_read_bytes_total{instance=~\"\$node\"}[5m])) / 1024 / 1024",
              "refId": "A",
              "legendFormat": "{{instance}} - Read"
            },
            {
              "expr": "sum by (instance) (rate(node_disk_written_bytes_total{instance=~\"\$node\"}[5m])) / 1024 / 1024",
              "refId": "B",
              "legendFormat": "{{instance}} - Write"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "MBs",
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
          "id": 8,
          "title": "📡 Node Network Traffic (MB/s) - Filtered by \$node",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 12, "y": 12},
          "targets": [
            {
              "expr": "sum by (instance) (rate(node_network_receive_bytes_total{instance=~\"\$node\", device!~\"lo|veth.*|docker.*|flannel.*|cali.*\"}[5m])) / 1024 / 1024",
              "refId": "A",
              "legendFormat": "{{instance}} - Receive"
            },
            {
              "expr": "sum by (instance) (rate(node_network_transmit_bytes_total{instance=~\"\$node\", device!~\"lo|veth.*|docker.*|flannel.*|cali.*\"}[5m])) / 1024 / 1024",
              "refId": "B",
              "legendFormat": "{{instance}} - Transmit"
            }
          ],
          "datasource": {"type": "prometheus", "uid": "$PROMETHEUS_UID"},
          "fieldConfig": {
            "defaults": {
              "unit": "MBs",
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
          "title": "🏆 Top 15 Memory Consumers (Noisy Neighbors)",
          "type": "table",
          "gridPos": {"h": 10, "w": 12, "x": 0, "y": 20},
          "targets": [
            {
              "expr": "topk(15, sum(container_memory_working_set_bytes{container!=\"\", container!=\"POD\"}) by (namespace, pod, node)) / 1024 / 1024",
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
                "indexByName": {
                  "node": 0,
                  "namespace": 1,
                  "pod": 2,
                  "Value": 3
                },
                "renameByName": {
                  "node": "Node",
                  "namespace": "Namespace",
                  "pod": "Pod",
                  "Value": "Memory (MB)"
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
                "align": "left",
                "displayMode": "auto"
              }
            },
            "overrides": [
              {
                "matcher": {"id": "byName", "options": "Memory (MB)"},
                "properties": [
                  {"id": "unit", "value": "mbytes"},
                  {"id": "decimals", "value": 1},
                  {"id": "custom.displayMode", "value": "color-background"},
                  {
                    "id": "thresholds",
                    "value": {
                      "mode": "absolute",
                      "steps": [
                        {"value": null, "color": "transparent"},
                        {"value": 100, "color": "rgba(237, 129, 40, 0.2)"},
                        {"value": 500, "color": "rgba(245, 54, 54, 0.3)"}
                      ]
                    }
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
          "title": "🔥 Top 15 CPU Consumers (Noisy Neighbors)",
          "type": "table",
          "gridPos": {"h": 10, "w": 12, "x": 12, "y": 20},
          "targets": [
            {
              "expr": "topk(15, sum(rate(container_cpu_usage_seconds_total{container!=\"\", container!=\"POD\"}[5m])) by (namespace, pod, node))",
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
                "indexByName": {
                  "node": 0,
                  "namespace": 1,
                  "pod": 2,
                  "Value": 3
                },
                "renameByName": {
                  "node": "Node",
                  "namespace": "Namespace",
                  "pod": "Pod",
                  "Value": "CPU (cores)"
                }
              }
            },
            {
              "id": "sortBy",
              "options": {
                "fields": {},
                "sort": [
                  {"field": "CPU (cores)", "desc": true}
                ]
              }
            }
          ],
          "fieldConfig": {
            "defaults": {
              "custom": {
                "align": "left",
                "displayMode": "auto"
              }
            },
            "overrides": [
              {
                "matcher": {"id": "byName", "options": "CPU (cores)"},
                "properties": [
                  {"id": "unit", "value": "cores"},
                  {"id": "decimals", "value": 3},
                  {"id": "custom.displayMode", "value": "color-background"},
                  {
                    "id": "thresholds",
                    "value": {
                      "mode": "absolute",
                      "steps": [
                        {"value": null, "color": "transparent"},
                        {"value": 0.5, "color": "rgba(237, 129, 40, 0.2)"},
                        {"value": 1, "color": "rgba(245, 54, 54, 0.3)"}
                      ]
                    }
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
          "id": 11,
          "title": "⚠️ Problematic Pod Events (OOMKilled, CrashLoop, ImagePull, Evicted)",
          "type": "table",
          "gridPos": {"h": 8, "w": 24, "x": 0, "y": 30},
          "targets": [
            {
              "expr": "kube_pod_container_status_waiting_reason{reason=~\"CrashLoopBackOff|ImagePullBackOff|ErrImagePull\"} > 0",
              "refId": "A",
              "instant": true,
              "format": "table"
            },
            {
              "expr": "kube_pod_container_status_terminated_reason{reason=~\"OOMKilled|Error\"} > 0",
              "refId": "B",
              "instant": true,
              "format": "table"
            },
            {
              "expr": "kube_pod_status_reason{reason=~\"Evicted|NodeLost|FailedScheduling\"} > 0",
              "refId": "C",
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
                  "uid": true,
                  "id": true,
                  "container": true
                },
                "indexByName": {
                  "node": 0,
                  "namespace": 1,
                  "pod": 2,
                  "reason": 3,
                  "Value": 4
                },
                "renameByName": {
                  "node": "Node",
                  "namespace": "Namespace",
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
                          "ErrImagePull": {"color": "dark-yellow", "text": "🟡 ErrImagePull"}
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
        },
        {
          "id": 12,
          "title": "🔄 Pod Restart Rate (Last 5m)",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 24, "x": 0, "y": 38},
          "targets": [
            {
              "expr": "topk(10, rate(kube_pod_container_status_restarts_total[5m]) > 0)",
              "refId": "A",
              "legendFormat": "{{namespace}}/{{pod}} - {{container}}"
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
        }
      ]
    }
EOF

echo ""
echo "✅ Infrastructure & Cluster Dashboard Created!"
echo ""
echo "Restarting Grafana to load dashboard..."
kubectl rollout restart deployment/grafana -n observability
kubectl rollout status deployment/grafana -n observability --timeout=120s

echo ""
echo "=== Infrastructure & Cluster Dashboard Ready ==="
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
echo "Dashboard: Dashboards -> Infrastructure & Cluster - Node & Pod Resource Analysis"
echo ""
echo "📊 DASHBOARD STRUCTURE:"
echo ""
echo "🎯 Top Row - Cluster-Wide Saturation:"
echo "  • Cluster CPU Saturation (%)"
echo "  • Cluster Memory Saturation (%)"
echo "  • Cluster Disk Usage (%)"
echo "  • Network Traffic (In/Out)"
echo ""
echo "🖥️ Node Detail Section (Variable: \$node):"
echo "  • Node CPU Usage (%) - Filtered by selected node"
echo "  • Node Memory Usage (%) - Filtered by selected node"
echo "  • Node Disk I/O (Read/Write MB/s) - Filtered by selected node"
echo "  • Node Network Traffic (MB/s) - Filtered by selected node"
echo ""
echo "🏆 Noisy Neighbor Analysis:"
echo "  • Top 15 Memory Consumers - Which pods use most RAM"
echo "  • Top 15 CPU Consumers - Which pods use most CPU"
echo ""
echo "⚠️ Problematic Pod Events:"
echo "  • OOMKilled → Memory limit too low"
echo "  • CrashLoopBackOff → Application crash"
echo "  • ImagePullBackOff → Image not found"
echo "  • Evicted → Node resource pressure"
echo "  • FailedScheduling → No resources available"
echo ""
echo "🔄 Pod Restart Rate:"
echo "  • Top 10 restarting pods in the last 5 minutes"
echo ""
echo "💡 VARIABLE USAGE:"
echo "  • Select a specific node from \$node dropdown to filter node-level panels"
echo "  • Select 'All' to see all nodes aggregated"
echo ""
echo "Total Panels: 12 (Infrastructure-focused resource analysis)"
echo ""

