#!/bin/bash

echo "Installing Loki with OpenTelemetry Integration..."
echo ""

# Step 1: Install Loki (OTLP endpoint enabled)
echo "Step 1: Installing Loki..."
echo "Note: Loki will receive logs via OTLP HTTP from OTEL Collector."
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update

# Install loki-stack WITHOUT Promtail (OTEL Collector sends logs via OTLP)
helm install loki grafana/loki-stack -n observability \
  --set loki.enabled=true \
  --set promtail.enabled=false \
  --set grafana.enabled=false \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=10Gi \
  --set loki.config.limits_config.retention_period=168h \
  --set loki.config.table_manager.retention_deletes_enabled=true \
  --set loki.config.table_manager.retention_period=168h

echo "Waiting for Loki to be ready..."
kubectl wait --for=condition=ready pod -l app=loki -n observability --timeout=300s

echo ""
echo "Loki installed!"

# Step 2: Update OTEL Collector (core image with OTLP HTTP exporter)
echo ""
echo "Step 2: Configuring OTEL Collector..."
echo "Note: Using OTLP HTTP exporter to send logs to Loki."

# Delete existing collector to force recreation
kubectl delete opentelemetrycollector otel-collector -n observability 2>/dev/null || true

# Create new collector with core image
cat <<'EOF' | kubectl apply -f -
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: otel-collector
  namespace: observability
spec:
  # Use CORE image (sufficient for traces + metrics)
  image: ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector:0.136.0
  
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
      
      # Loki for logs (using OTLP HTTP)
      otlphttp/logs:
        endpoint: http://loki:3100/otlp
        tls:
          insecure: true
        
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
          
        # Logs sent to Loki via OTLP HTTP
        logs:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [otlphttp/logs, debug]
EOF

echo "Waiting for OTEL Collector to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=otel-collector-collector -n observability --timeout=300s

echo ""
echo "OTEL Collector configured for traces + metrics + logs!"

# Step 2b: Recreate ServiceMonitor for Prometheus
echo ""
echo "Step 2b: Creating ServiceMonitor for Prometheus..."

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

echo "ServiceMonitor created!"

# Step 3: Add Loki datasource to Grafana
echo ""
echo "Step 3: Adding Loki datasource to Grafana..."

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

echo "Restarting Grafana to load new datasource..."
kubectl rollout restart deployment/prometheus-grafana -n observability
kubectl rollout status deployment/prometheus-grafana -n observability --timeout=300s

echo ""
echo "Grafana updated with Loki datasource!"

# Step 4: Verify
echo ""
echo "Verification:"
echo ""
echo "Loki Pods:"
kubectl get pods -n observability | grep loki

echo ""
echo "Loki Service:"
kubectl get service -n observability | grep loki

echo ""
echo "OTEL Collector Pod:"
kubectl get pods -n observability | grep otel-collector-collector

echo ""
echo "OTEL Collector Image:"
kubectl get deployment otel-collector-collector -n observability -o jsonpath='{.spec.template.spec.containers[0].image}'
echo ""

echo ""
echo "ServiceMonitor:"
kubectl get servicemonitor otel-collector-monitoring -n observability

echo ""
echo "=== Loki + OTEL Integration Complete ==="
echo ""
echo "Observability Stack Summary:"
echo "  - Traces:  OTEL Collector -> Jaeger"
echo "  - Metrics: OTEL Collector -> Prometheus"
echo "  - Logs:    OTEL Collector -> Loki (via OTLP HTTP)"
echo ""
echo "Next Steps:"
echo "1. Access Grafana: http://192.168.0.115:3000"
echo "2. Go to Explore -> Select 'Loki' datasource"
echo "3. Query logs: {namespace=\"production\"}"
echo ""
echo "To view logs from auto-instrumented apps:"
echo "   - Logs automatically flow via OTEL SDK"
echo "   - Check in Grafana Explore: {exporter=\"OTLP\"}"
echo ""
echo "Unified Telemetry Pipeline: All traces, metrics, and logs via OpenTelemetry!"
