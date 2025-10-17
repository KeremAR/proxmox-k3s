#!/bin/bash

# Fix Grafana Dashboard - Simplify datasource reference

kubectl delete configmap otel-collector-dashboard -n observability --ignore-not-found

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
      "title": "OpenTelemetry Collector Metrics",
      "uid": "otel-collector",
      "tags": ["opentelemetry", "otel", "collector"],
      "timezone": "browser",
      "refresh": "30s",
      "time": {
        "from": "now-1h",
        "to": "now"
      },
      "panels": [
        {
          "id": 1,
          "title": "OTEL Spans Sent to Jaeger",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
          "targets": [
            {
              "expr": "otelcol_exporter_sent_spans_total",
              "legendFormat": "Spans Sent to {{exporter}}",
              "refId": "A"
            }
          ]
        },
        {
          "id": 2,
          "title": "Total Spans Sent",
          "type": "stat",
          "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
          "targets": [
            {
              "expr": "otelcol_exporter_sent_spans_total",
              "refId": "A"
            }
          ]
        },
        {
          "id": 3,
          "title": "Export Queue Size",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
          "targets": [
            {
              "expr": "otelcol_exporter_queue_size",
              "legendFormat": "Queue: {{exporter}}",
              "refId": "A"
            }
          ]
        },
        {
          "id": 4,
          "title": "Spans by Exporter",
          "type": "piechart",
          "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
          "targets": [
            {
              "expr": "sum by (exporter) (otelcol_exporter_sent_spans_total)",
              "legendFormat": "{{exporter}}",
              "refId": "A"
            }
          ]
        }
      ]
    }
EOF

echo "✅ Dashboard updated!"
echo "🔄 Restarting Grafana..."
kubectl rollout restart deployment/prometheus-grafana -n observability

echo "⏳ Waiting for Grafana..."
kubectl rollout status deployment/prometheus-grafana -n observability --timeout=120s

echo ""
echo "✅ Done! Check Grafana:"
echo "http://192.168.0.115:3000"
echo "Dashboards → OpenTelemetry Collector Metrics"
