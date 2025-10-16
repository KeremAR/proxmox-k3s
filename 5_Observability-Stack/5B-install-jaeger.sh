#!/bin/bash

# ==============================================================================
# 5B - Install Jaeger Tracing 
# ==============================================================================
# Purpose: Distributed tracing system for microservices
# Components: Jaeger All-in-One with LoadBalancer access
# ==============================================================================

set -e

echo "🔍 Installing Jaeger Tracing..."

# Install Jaeger Operator
echo "📦 Installing Jaeger Operator..."
kubectl apply -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.51.0/jaeger-operator.yaml

# Wait for Jaeger operator (check which namespace it's in)
echo "⏳ Waiting for Jaeger Operator..."
# First check if it's in observability-system
if kubectl get deployment jaeger-operator -n observability-system &>/dev/null; then
    kubectl wait --for=condition=available deployment/jaeger-operator -n observability-system --timeout=300s
elif kubectl get deployment jaeger-operator -n observability &>/dev/null; then
    kubectl wait --for=condition=available deployment/jaeger-operator -n observability --timeout=300s
else
    # Otherwise check default namespace
    kubectl wait --for=condition=available deployment/jaeger-operator --timeout=300s
fi

# Deploy Jaeger All-in-One instance
echo "🚀 Deploying Jaeger instance..."
cat <<EOF | kubectl apply -f -
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger
  namespace: observability
spec:
  strategy: allinone
  allInOne:
    image: jaegertracing/all-in-one:1.51
    options:
      log-level: info
      memory.max-traces: 10000
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 100m
        memory: 128Mi
  storage:
    type: memory
    options:
      memory:
        max-traces: 10000
  ingress:
    enabled: false
  service:
    type: LoadBalancer
    loadBalancerIP: 192.168.0.113
EOF

# Wait for Jaeger to be ready
echo "⏳ Waiting for Jaeger to be ready..."
kubectl wait --for=condition=available deployment/jaeger -n observability --timeout=300s

# Get Jaeger URL
echo ""
echo "✅ Jaeger installation completed!"
echo "🔍 Jaeger UI: http://192.168.0.113:16686"
echo "📊 Jaeger Collector: jaeger-collector.observability.svc.cluster.local:14250"
echo ""
echo "🎯 Next Step: Run 5C-install-prometheus.sh to install Prometheus metrics"