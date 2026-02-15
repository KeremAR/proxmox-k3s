#!/bin/bash

echo "=== Installing Prometheus Database ==="
echo ""
# Step 0: Install Helm if not already installed
echo "Step 0: Checking Helm installation..."
if ! command -v helm &> /dev/null; then
    echo "Helm not found. Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo "✅ Helm installed successfully"
else
    HELM_VERSION=$(helm version --short)
    echo "✅ Helm already installed: $HELM_VERSION"
fi
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
#found multiple scrape configs with job name "prometheus"  error fix by changing job name
serverFiles:
  prometheus.yml:
    rule_files:
      - /etc/config/recording_rules.yml
      - /etc/config/alerting_rules.yml
    scrape_configs:
      - job_name: 'prometheus-self'
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

echo "=== Installing Blackbox Exporter ==="
echo ""

cat <<EOF > /tmp/blackbox-exporter-values.yaml
config:
  modules:
    http_2xx:
      prober: http
      timeout: 10s
      http:
        valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
        valid_status_codes: [200]
        method: GET
        preferred_ip_protocol: "ip4"
    http_post_2xx:
      prober: http
      timeout: 10s
      http:
        valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
        valid_status_codes: [200, 201]
        method: POST
        preferred_ip_protocol: "ip4"

serviceMonitor:
  enabled: false

podAnnotations:
  prometheus.io/scrape: "false"

resources:
  requests:
    cpu: 10m
    memory: 32Mi
  limits:
    cpu: 100m
    memory: 64Mi

nodeSelector:
  kubernetes.io/hostname: k3s-worker
EOF

helm upgrade --install blackbox-exporter prometheus-community/prometheus-blackbox-exporter \
  --namespace observability \
  --values /tmp/blackbox-exporter-values.yaml \
  --wait

echo "✅ Blackbox Exporter installed!"

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
echo ""
echo "Services:"
echo "  • prometheus-server.observability.svc.cluster.local:80"
echo "  • Remote Write: http://prometheus-server.observability.svc.cluster.local:80/api/v1/write"
echo "  • kube-state-metrics.observability.svc.cluster.local:8080"
echo "  • blackbox-exporter-prometheus-blackbox-exporter.observability.svc.cluster.local:9115"

echo "⚠️  Note: nip.io automatically resolves <name>.<IP>.nip.io → <IP>"
echo "   No /etc/hosts editing needed!"
