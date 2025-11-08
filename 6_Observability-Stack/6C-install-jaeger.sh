#!/bin/bash

echo "=== Installing Jaeger Tracing (OpenTelemetry Backend) ==="
echo ""

# Add Jaeger Helm repository
echo "Adding Jaeger Helm repository..."
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

echo ""
echo "Installing Jaeger in observability namespace..."

# Install Jaeger with OTLP receiver enabled
helm upgrade --install jaeger jaegertracing/jaeger \
  --namespace observability \
  --create-namespace \
  --set provisionDataStore.cassandra=false \
  --set storage.type=memory \
  --set allInOne.enabled=true \
  --set agent.enabled=false \
  --set collector.enabled=false \
  --set query.enabled=false \
  --set allInOne.extraEnv[0].name=COLLECTOR_OTLP_ENABLED \
  --set allInOne.extraEnv[0].value=true \
  --set allInOne.extraEnv[1].name=SPAN_STORAGE_TYPE \
  --set allInOne.extraEnv[1].value=memory

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
