#!/bin/bash

# ==============================================================================
# 5A - Install OpenTelemetry Operator + Auto-Instrumentation
# ==============================================================================
# Purpose: Zero-code instrumentation for applications
# Components: OTEL Operator, Instrumentation CRDs, OTEL Collector
# ==============================================================================

set -e

echo "🚀 Installing OpenTelemetry Operator..."

# Install cert-manager first (required for OpenTelemetry Operator)
echo "🔐 Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

# Wait for cert-manager to be ready
echo "⏳ Waiting for cert-manager to be ready..."
kubectl wait --for=condition=available deployment/cert-manager -n cert-manager --timeout=300s
kubectl wait --for=condition=available deployment/cert-manager-cainjector -n cert-manager --timeout=300s
kubectl wait --for=condition=available deployment/cert-manager-webhook -n cert-manager --timeout=300s

# Install OpenTelemetry Operator
echo "📦 Installing OpenTelemetry Operator..."
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml

# Wait for operator to be ready
echo "⏳ Waiting for OpenTelemetry Operator to be ready..."
kubectl wait --for=condition=available deployment/opentelemetry-operator-controller-manager \
    -n opentelemetry-operator-system --timeout=300s

# Create observability namespace
echo "📁 Creating observability namespace..."
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

# Install OTEL Collector
echo "📊 Creating OTEL Collector configuration..."
cat <<EOF | kubectl apply -f -
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector  
metadata:
  name: otel-collector
  namespace: observability
spec:
  config: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
      
    processors:
      batch:
      memory_limiter:
        limit_mib: 256
        check_interval: 1s
        
    exporters:
      # OTLP for traces to Jaeger (using short service name in same namespace)
      otlp/jaeger:
        endpoint: http://jaeger-collector:4317
        tls:
          insecure: true
          
      # Prometheus for metrics  
      prometheus:
        endpoint: "0.0.0.0:8889"
        
      # Debug for logs (Loki exporter not available in this version)
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
          exporters: [debug]

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
EOF

# Create Auto-Instrumentation for Python/Flask
echo "🐍 Creating Python auto-instrumentation..."
cat <<EOF | kubectl apply -f -
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: python-instrumentation
  namespace: production
spec:
  exporter:
    endpoint: http://otel-collector.observability.svc.cluster.local:4318
  propagators:
    - tracecontext
    - baggage
  sampler:
    type: parentbased_traceidratio
    argument: "1.0"
  python:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:latest
    env:
      - name: OTEL_TRACES_EXPORTER
        value: otlp
      - name: OTEL_METRICS_EXPORTER  
        value: otlp
      - name: OTEL_LOGS_EXPORTER
        value: otlp
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: http/protobuf
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: http://otel-collector.observability.svc.cluster.local:4318
EOF

# Create Auto-Instrumentation for Node.js/React
echo "🟢 Creating Node.js auto-instrumentation..."
cat <<EOF | kubectl apply -f -
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: nodejs-instrumentation
  namespace: production
spec:
  exporter:
    endpoint: http://otel-collector.observability.svc.cluster.local:4318
  propagators:
    - tracecontext
    - baggage
  sampler:
    type: parentbased_traceidratio
    argument: "1.0"
  nodejs:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:latest
    env:
      - name: OTEL_TRACES_EXPORTER
        value: otlp
      - name: OTEL_METRICS_EXPORTER
        value: otlp
      - name: OTEL_LOGS_EXPORTER
        value: otlp
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: http/protobuf
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: http://otel-collector.observability.svc.cluster.local:4318
EOF

# Create explicit otel-collector Service (for reliable DNS resolution)
echo "🔧 Creating OTEL Collector Service..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: otel-collector
  namespace: observability
spec:
  selector:
    app.kubernetes.io/name: otel-collector-collector
  ports:
    - name: otlp-grpc
      port: 4317
      targetPort: 4317
      protocol: TCP
    - name: otlp-http
      port: 4318
      targetPort: 4318
      protocol: TCP
    - name: metrics
      port: 8889
      targetPort: 8889
      protocol: TCP
EOF

# Create ServiceMonitor for Prometheus scraping
echo "📊 Creating ServiceMonitor for Prometheus..."
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: otel-collector
  namespace: observability
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: otel-collector-collector-monitoring
  endpoints:
    - port: metrics
      interval: 15s
      path: /metrics
EOF

echo ""
echo "✅ OpenTelemetry Operator installation completed!"
echo "📊 OTEL Collector gRPC endpoint: otel-collector.observability.svc.cluster.local:4317"
echo "� OTEL Collector HTTP endpoint: otel-collector.observability.svc.cluster.local:4318"
echo "�🐍 Python instrumentation: python-instrumentation (using HTTP/protobuf on port 4318)"
echo "🟢 Node.js instrumentation: nodejs-instrumentation (using HTTP/protobuf on port 4318)"
echo ""
echo "🎯 Next Step: Run 5B-install-jaeger.sh to install Jaeger tracing"