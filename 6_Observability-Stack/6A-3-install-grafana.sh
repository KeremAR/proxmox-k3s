#!/bin/bash

echo "=== Installing Grafana UI ==="
echo ""

# Create observability namespace (idempotent)
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

# Add Helm repos
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

cat <<EOF > /tmp/grafana-values.yaml
adminPassword: admin123
service:
  type: ClusterIP
nodeSelector:
  kubernetes.io/hostname: k3s-worker
securityContext:
  fsGroup: 472
  runAsGroup: 472
  runAsUser: 472

# Enable sidecar for automatic dashboard loading from ConfigMaps
sidecar:
  dashboards:
    enabled: true
    label: grafana_dashboard
    labelValue: "1"
    folder: /tmp/dashboards
    folderAnnotation: grafana_folder
    provider:
      foldersFromFilesStructure: true

datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-server.observability.svc.cluster.local:80
      access: proxy
      isDefault: true

    - name: Loki
      type: loki
      url: http://loki-gateway.observability.svc.cluster.local:80
      access: proxy
EOF

helm upgrade --install grafana grafana/grafana \
  --namespace observability \
  --values /tmp/grafana-values.yaml \
  --wait

  # Get Nginx Ingress LoadBalancer IP
INGRESS_IP=$(kubectl get service nginx-ingress-loadbalancer -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$INGRESS_IP" ]; then
    echo "⚠️  Warning: Nginx Ingress LoadBalancer not found"
    echo "   Skipping Ingress creation. Services accessible via ClusterIP only."
else
    echo "✅ Found LoadBalancer IP: $INGRESS_IP"
    
    # Create Grafana Ingress
    echo "📝 Creating Grafana Ingress..."
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: observability
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: grafana.${INGRESS_IP}.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 80
EOF
fi

echo "✅ Grafana UI installed!"
echo ""
echo "  - Grafana:    http://grafana.${INGRESS_IP}.nip.io (admin / admin123)"
echo ""
echo "Service: grafana.observability.svc.cluster.local:80"
echo "Credentials: admin / admin123"
echo ""
echo "Datasources configured:"
echo "  - Prometheus: http://prometheus-server.observability.svc.cluster.local:80"
echo "  - Loki: http://loki-gateway.observability.svc.cluster.local:80"
echo "⚠️  Note: nip.io automatically resolves <name>.<IP>.nip.io → <IP>"
echo "   No /etc/hosts editing needed!"