#!/bin/bash

echo "🚀 Installing Loki with OpenTelemetry Integration..."
echo ""

# Step 1: Install Loki
echo "📦 Step 1: Installing Loki..."
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update

helm install loki grafana/loki -n observability \
  --set persistence.enabled=true \
  --set persistence.size=10Gi \
  --set config.retention_period=168h \
  --set config.limits_config.retention_period=168h

echo "⏳ Waiting for Loki to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=loki -n observability --timeout=300s

echo ""
echo "✅ Loki installed!"

# Step 2: Update OTEL Collector with Loki exporter
echo ""
echo "🔧 Step 2: Adding Loki exporter to OTEL Collector..."

kubectl patch opentelemetrycollector otel-collector -n observability --type=merge -p '{
  "spec": {
    "config": {
      "exporters": {
        "loki": {
          "endpoint": "http://loki.observability.svc.cluster.local:3100/loki/api/v1/push"
        }
      },
      "service": {
        "pipelines": {
          "logs": {
            "receivers": ["otlp"],
            "processors": ["memory_limiter", "batch"],
            "exporters": ["loki", "debug"]
          }
        }
      }
    }
  }
}'

echo "⏳ Waiting for OTEL Collector to restart..."
kubectl rollout status deployment/otel-collector-collector -n observability --timeout=300s

echo ""
echo "✅ OTEL Collector updated with Loki exporter!"

# Step 3: Add Loki datasource to Grafana
echo ""
echo "📊 Step 3: Adding Loki datasource to Grafana..."

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-loki-datasource
  namespace: observability
  labels:
    grafana_datasource: "1"
data:
  loki-datasource.yaml: |-
    apiVersion: 1
    datasources:
    - name: Loki
      type: loki
      access: proxy
      url: http://loki.observability.svc.cluster.local:3100
      isDefault: false
      editable: true
EOF

echo "⏳ Restarting Grafana to load new datasource..."
kubectl rollout restart deployment/prometheus-grafana -n observability
kubectl rollout status deployment/prometheus-grafana -n observability --timeout=300s

echo ""
echo "✅ Grafana updated with Loki datasource!"

# Step 4: Verify
echo ""
echo "🔍 Verification:"
echo ""
echo "Loki Service:"
kubectl get service loki -n observability

echo ""
echo "OTEL Collector Logs Pipeline:"
kubectl get opentelemetrycollector otel-collector -n observability -o jsonpath='{.spec.config.service.pipelines.logs}' | jq '.'

echo ""
echo "✅ Loki + OTEL Integration Complete!"
echo ""
echo "📋 Next Steps:"
echo "1. Access Grafana: http://192.168.0.115:3000"
echo "2. Go to Explore → Select 'Loki' datasource"
echo "3. Query logs: {namespace=\"production\"}"
echo ""
echo "🔍 To test logs from auto-instrumented apps:"
echo "   - Logs will automatically flow from Python/Node.js apps"
echo "   - Check in Grafana Explore: {app=\"frontend\"} or {app=\"user-service\"}"