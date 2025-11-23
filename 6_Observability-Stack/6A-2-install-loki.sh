#!/bin/bash

echo "=== Installing Loki Database ==="
echo ""

# Create observability namespace (idempotent)
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

# Add Helm repos
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

cat <<EOF > /tmp/loki-values.yaml
# Root-level cache and deployment settings
chunksCache:
  enabled: false
resultsCache:
  enabled: false
minio:
  enabled: false
deploymentMode: SingleBinary
singleBinary:
  replicas: 1
  nodeSelector:
    kubernetes.io/hostname: k3s-worker
write:
  replicas: 0
read:
  replicas: 0
backend:
  replicas: 0
test:
  enabled: false

# All Loki configuration under 'loki:' key
loki:
  auth_enabled: false
  commonConfig:
    replication_factor: 1
  
  # Storage configuration with correct key name
  storage:
    type: filesystem
    filesystem:
      chunks_directory: /var/loki/chunks
      rules_directory: /var/loki/rules
      
  # Schema configuration to prevent bucketNames error
  schemaConfig:
    configs:
      - from: 2024-01-01
        store: tsdb
        object_store: filesystem 
        schema: v13
        index:
          prefix: loki_index_
          period: 24h


gateway:
  nodeSelector:
    kubernetes.io/hostname: k3s-worker
EOF

helm upgrade --install loki grafana/loki \
  --namespace observability \
  --create-namespace \
  --values /tmp/loki-values.yaml \
  --wait

echo "✅ Loki Database installed!"
echo ""
echo "Service: loki-gateway.observability.svc.cluster.local:80"
echo "Push URL: http://loki-gateway.observability.svc.cluster.local:80/loki/api/v1/push"
