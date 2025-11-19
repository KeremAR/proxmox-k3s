#!/bin/bash

echo "=== Installing Prometheus Database ==="
echo ""

# Create observability namespace (idempotent)
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

cat <<EOF > /tmp/prometheus-values.yaml
server:
  nodeSelector:
    kubernetes.io/hostname: k3s-worker

  persistentVolume:
    enabled: true
    storageClass: local-path
    accessModes: ["ReadWriteOnce"]
    size: 10Gi

  # Enable remote write receiver - CRITICAL for Alloy!
  extraArgs:
    web.enable-remote-write-receiver: ""

# Override default scrape_configs to prevent crashes
# Only keep prometheus self-monitoring
serverFiles:
  prometheus.yml:
    rule_files:
      - /etc/config/recording_rules.yml
      - /etc/config/alerting_rules.yml
    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']

alertmanager:
  enabled: false
prometheus-pushgateway:
  enabled: false
prometheus-node-exporter:
  enabled: false
kube-state-metrics:
  enabled: false
EOF

helm upgrade --install prometheus prometheus-community/prometheus \
  --namespace observability \
  --values /tmp/prometheus-values.yaml \
  --wait

echo "✅ Prometheus Database installed!"

echo "=== Installing kube-state-metrics ==="
echo ""

cat <<EOF > /tmp/kube-state-metrics-values.yaml
prometheus:
  monitor:
    enabled: false

selfMonitor:
  enabled: false

prometheusScrape: true

podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"

nodeSelector:
  kubernetes.io/hostname: k3s-worker
EOF

helm upgrade --install kube-state-metrics prometheus-community/kube-state-metrics \
  --namespace observability \
  --values /tmp/kube-state-metrics-values.yaml \
  --wait

echo "✅ kube-state-metrics installed!"

  # Get Nginx Ingress LoadBalancer IP
INGRESS_IP=$(kubectl get service nginx-ingress-loadbalancer -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo ""
if [ -z "$INGRESS_IP" ]; then
    echo "⚠️  Warning: Nginx Ingress LoadBalancer not found"
    echo "   Skipping Ingress creation. Services accessible via ClusterIP only."
else
    echo "✅ Found LoadBalancer IP: $INGRESS_IP"

    echo "📝 Creating Prometheus Ingress..."
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus-ingress
  namespace: observability
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: prometheus.${INGRESS_IP}.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-server
            port:
              number: 9090
EOF
fi

echo ""
echo "  - Prometheus: http://prometheus.${INGRESS_IP}.nip.io"
echo "Service: prometheus-server.observability.svc.cluster.local:80"
echo "Remote Write: http://prometheus-server.observability.svc.cluster.local:80/api/v1/write"
echo "Service: kube-state-metrics.observability.svc.cluster.local:8080"

echo "⚠️  Note: nip.io automatically resolves <name>.<IP>.nip.io → <IP>"
echo "   No /etc/hosts editing needed!"
