#!/bin/bash

echo "=== Installing Jaeger Tracing (OpenTelemetry Backend) ==="
echo ""

# Add Jaeger Helm repository
echo "Adding Jaeger Helm repository..."
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

echo ""
echo "Installing Jaeger in observability namespace..."

echo "📝 Creating Jaeger values.yaml..."
cat > /tmp/jaeger-values.yaml <<'EOF'
# Jaeger All-in-One for OpenTelemetry Tracing
# Single pod with collector, query, and in-memory storage

allInOne:
  enabled: true
  
  # Enable OTLP receiver
  args:
    - "--collector.otlp.enabled=true"
  
  # Resource limits
  resources:
    requests:
      memory: "256Mi"
      cpu: "100m"
    limits:
      memory: "512Mi"
      cpu: "500m"

# Use memory storage (in all-in-one)
storage:
  type: memory

# Disable separate agent
agent:
  enabled: false

# Disable separate collector (we use all-in-one)
collector:
  enabled: false

# Disable separate query (we use all-in-one)
query:
  enabled: false

# Disable Cassandra
provisionDataStore:
  cassandra: false
  elasticsearch: false

# Disable ingress (we'll create it separately)
ingress:
  enabled: false

# Disable other components
hotrod:
  enabled: false

spark:
  enabled: false

esIndexCleaner:
  enabled: false

esRollover:
  enabled: false
EOF

echo "�🚀 Installing Jaeger with OTLP support..."
helm upgrade --install jaeger jaegertracing/jaeger \
  --namespace observability \
  --create-namespace \
  --values /tmp/jaeger-values.yaml \
  --wait

echo ""
echo "Waiting for Jaeger to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/jaeger -n observability

echo ""
echo "=== Creating Jaeger Ingress ==="

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: jaeger-ui
  namespace: observability
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: jaeger.192.168.0.111.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: jaeger-query
            port:
              number: 16686
EOF

echo ""
echo "✅ Jaeger Installation Complete!"
echo ""
echo "=== Jaeger Service Endpoints ==="
echo ""
echo "📍 Internal (for Alloy):"
echo "  OTLP HTTP: http://jaeger-collector.observability.svc.cluster.local:4318"
echo "  OTLP gRPC: jaeger-collector.observability.svc.cluster.local:4317"
echo ""

# Get Nginx Ingress LoadBalancer IP
INGRESS_IP=$(kubectl get service nginx-ingress-loadbalancer -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$INGRESS_IP" ]; then
    echo "🌐 External UI: kubectl port-forward -n observability svc/jaeger-query 16686:16686"
else
    echo "🌐 External UI: http://jaeger.${INGRESS_IP}.nip.io"
fi

echo ""
echo "=== Verify Installation ==="
echo "kubectl get pods -n observability -l app.kubernetes.io/name=jaeger"
echo "kubectl get svc -n observability -l app.kubernetes.io/name=jaeger"
echo ""
echo "Next Steps:"
echo "1. Configure Alloy to forward traces to Jaeger"
echo "2. Instrument Python services with OpenTelemetry SDK"
echo "3. Add OTEL environment variables to deployments"
