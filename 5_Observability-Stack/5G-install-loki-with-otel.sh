#!/bin/bash

echo "🚀 Installing Loki with OpenTelemetry Integration..."
echo ""

# Step 1: Install Loki (Storage only, no Promtail)
echo "📦 Step 1: Installing Loki..."
echo "Note: Using Loki as log storage. OpenTelemetry Collector will send logs."
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update

# Install loki-stack WITHOUT Promtail (OTEL handles log collection)
helm install loki grafana/loki-stack -n observability \
  --set loki.enabled=true \
  --set promtail.enabled=false \
  --set grafana.enabled=false \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=10Gi \
  --set loki.config.limits_config.retention_period=168h \
  --set loki.config.table_manager.retention_deletes_enabled=true \
  --set loki.config.table_manager.retention_period=168h

echo "⏳ Waiting for Loki to be ready..."
kubectl wait --for=condition=ready pod -l app=loki -n observability --timeout=300s

echo ""
echo "✅ Loki installed!"

# Step 2: Update OTEL Collector to use CONTRIB image (includes Loki exporter)
echo ""
echo "🔧 Step 2: Switching OTEL Collector to contrib image..."
echo "Note: Loki exporter is only available in contrib distribution"

# Delete existing collector to force recreation with new image
kubectl delete opentelemetrycollector otel-collector -n observability

# Create new collector with contrib image and Loki exporter
cat <<'EOF' | kubectl apply -f -
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: otel-collector
  namespace: observability
spec:
  # Use CONTRIB image (includes Loki exporter)
  image: ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:0.136.0
  
  mode: deployment
  
  ports:
  - name: otlp-grpc
    port: 4317
    targetPort: 4317
  - name: otlp-http
    port: 4318
    targetPort: 4318
  - name: metrics
    port: 8889
    targetPort: 8889
  
  config: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
      
    processors:
      batch: {}
      memory_limiter:
        limit_mib: 256
        check_interval: 1s
        
    exporters:
      # Jaeger for traces
      otlp/jaeger:
        endpoint: jaeger-collector:4317
        tls:
          insecure: true
          
      # Prometheus for metrics  
      prometheus:
        endpoint: "0.0.0.0:8889"
      
      # Loki for logs (CONTRIB only)
      loki:
        endpoint: http://loki:3100/loki/api/v1/push
        
      # Debug for troubleshooting
      debug:
        verbosity: detailed
        
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [otlp/jaeger]
          
        metrics:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [prometheus]
          
        logs:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [loki, debug]
EOF

echo "⏳ Waiting for OTEL Collector to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=otel-collector-collector -n observability --timeout=300s

echo ""
echo "✅ OTEL Collector updated with contrib image and Loki exporter!"

# Step 2b: Recreate ServiceMonitor for Prometheus
echo ""
echo "🔧 Step 2b: Creating ServiceMonitor for Prometheus..."

cat <<'EOF' | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: otel-collector-monitoring
  namespace: observability
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: otel-collector-collector
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
EOF

echo "✅ ServiceMonitor created!"

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
echo "Loki Pods:"
kubectl get pods -n observability | grep loki

echo ""
echo "Loki Service:"
kubectl get service -n observability | grep loki

echo ""
echo "OTEL Collector Pod (contrib image):"
kubectl get pods -n observability | grep otel-collector-collector

echo ""
echo "OTEL Collector Image:"
kubectl get deployment otel-collector-collector -n observability -o jsonpath='{.spec.template.spec.containers[0].image}'
echo ""

echo ""
echo "OTEL Collector Logs Pipeline:"
kubectl get opentelemetrycollector otel-collector -n observability -o jsonpath='{.spec.config.service.pipelines.logs}' 2>/dev/null || echo "Config embedded in CRD"

echo ""
echo "ServiceMonitor:"
kubectl get servicemonitor otel-collector-monitoring -n observability

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
echo ""
echo "⚠️  Note: Logs will appear after applications generate log entries"
echo "   Trigger some activity in your apps to see logs flowing!"