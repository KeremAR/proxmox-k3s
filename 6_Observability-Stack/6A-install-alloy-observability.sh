#!/bin/bash

echo "=== Installing Grafana Alloy Observability Stack ==="
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

# Step 1: Create observability namespace
echo "Step 1: Creating observability namespace..."
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update



# === Adım 1: Loki Veritabanı Kurulumu ===
echo ""
echo "Step 1: Installing Loki Database..."

cat <<EOF > /tmp/loki-values.yaml
# --- DÜZELTME (Tüm Loki Hataları İçin DOĞRU YAPI) ---

# 1. Kök dizin ayarları
chunksCache:
  enabled: false
resultsCache:
  enabled: false
minio:
  enabled: false
deploymentMode: SingleBinary
singleBinary:
  replicas: 1
write:
  replicas: 0
read:
  replicas: 0
backend:
  replicas: 0
test:
  enabled: false

# 2. Tüm loki konfigürasyonu 'loki:' anahtarı ALTINDA
loki:
  auth_enabled: false
  commonConfig:
    replication_factor: 1
  
  # 3. 'storage' bloğu 'loki:' altında
  #    VE DOĞRU anahtar 'chunks_directory'
  storage:
    type: filesystem
    filesystem:
      chunks_directory: /var/loki/chunks
      rules_directory: /var/loki/rules
      
  # 4. 'useTestSchema: false' (varsayılan) olduğu için,
  #    'filesystem' kullanan özel şema tanımı.
  #    'bucketNames' hatasını bu çözer.
  schemaConfig:
    configs:
      - from: 2024-01-01
        store: tsdb
        object_store: filesystem 
        schema: v13
        index:
          prefix: loki_index_
          period: 24h
# --- DÜZELTME BİTİŞİ ---
EOF

helm upgrade --install loki grafana/loki \
  --namespace observability \
  --create-namespace \
  --values /tmp/loki-values.yaml \
  --wait

echo "✅ Loki Database installed!"

# === Adım 2: Prometheus Veritabanı Kurulumu ===
echo ""
echo "Step 2: Installing Prometheus Database..."

cat <<EOF > /tmp/prometheus-values.yaml
server:

    
  nodeSelector:
    kubernetes.io/hostname: k3s-worker

  persistentVolume:
    enabled: true
    storageClass: local-path
    accessModes: ["ReadWriteOnce"]
    size: 10Gi

# --- DÜZELTME (Prometheus Çökme Hatası için) ---
# Chart'ın varsayılan (default) values.yaml'daki uzun
# 'scrape_configs' listesini eziyoruz (override).
# Sadece 'prometheus' (kendisi) işini bırakıyoruz.
# Bu, çökmesini engelleyecektir.
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

# === Adım 3: Grafana Arayüzü Kurulumu ===
echo ""
echo "Step 3: Installing Grafana UI..."

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

datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-server.observability.svc.cluster.local:80
      access: proxy
      isDefault: true

    # --- DÜZELTME BURADA ---
    - name: Loki
      type: loki
      # Port 3100 DEĞİL, Port 80
      url: http://loki-gateway.observability.svc.cluster.local:80
      access: proxy
    # --- DÜZELTME BİTTİ ---
EOF

helm upgrade --install grafana grafana/grafana \
  --namespace observability \
  --values /tmp/grafana-values.yaml \
  --wait

echo "✅ Grafana UI installed!"


# === Adım 4: Grafana Alloy Ajanı Kurulumu ===

cat <<'EOF' > /tmp/alloy-log-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alloy-log-config
  namespace: observability
data:
  config.alloy: |
    // === SADECE LOG TOPLAMA ===

    discovery.kubernetes "pods" {
      role = "pod"
    }

    discovery.relabel "pod_logs" {
      targets = discovery.kubernetes.pods.targets
      rule {
        source_labels = ["__meta_kubernetes_namespace"]
        target_label  = "namespace"
      }
      rule {
        source_labels = ["__meta_kubernetes_pod_name"]
        target_label  = "pod"
      }
      rule {
        source_labels = ["__meta_kubernetes_pod_container_name"]
        target_label  = "container"
      }
      rule {
        source_labels = ["__meta_kubernetes_namespace", "__meta_kubernetes_pod_name"]
        separator     = "/"
        target_label  = "job"
      }
      rule {
        source_labels = ["__meta_kubernetes_pod_uid", "__meta_kubernetes_pod_container_name"]
        separator     = "/"
        action        = "replace"
        replacement   = "/var/log/pods/*$1/*.log"
        target_label  = "__path__"
      }
      rule {
        action = "replace"
        source_labels = ["__meta_kubernetes_pod_container_id"]
        regex = "^(\\w+)://.+$"
        replacement = "$1"
        target_label = "tmp_container_runtime"
      }
    }

    local.file_match "pod_logs" {
      path_targets = discovery.relabel.pod_logs.output
    }

    loki.source.file "pod_logs" {
      targets    = local.file_match.pod_logs.targets
      forward_to = [loki.process.pod_logs.receiver]
    }

    loki.process "pod_logs" {
      stage.match {
        selector = "{tmp_container_runtime=\"containerd\"}"
        stage.cri {}
      }
      stage.match {
        selector = "{tmp_container_runtime=\"docker\"}"
        stage.docker {}
      }
      stage.label_drop {
        values = ["tmp_container_runtime"]
      }

      forward_to = [loki.write.loki_db.receiver]
    }

    // --- DÜZELTME BURADA ---
    // Logları LOKI'ye gönder
    loki.write "loki_db" {
      endpoint {
        // 'loki-write' YOKTU, 'loki-gateway' (Port 80) DOĞRUYDU
        url = "http://loki-gateway.observability.svc.cluster.local:80/loki/api/v1/push"
      }
    }
EOF
kubectl apply -f /tmp/alloy-log-config.yaml

echo ""
echo "Step 4: Installing Grafana Alloy (The *ONE* Agent)..."

cat <<EOF > /tmp/alloy-values.yaml
controller:
  type: 'daemonset'

alloy:
  configMap:
    # 1. Helm'e "ConfigMap oluşturma" diyoruz
    create: false
    # 2. "Bunun yerine Adım 1'de oluşturduğumuz bu ismi kullan"
    name: alloy-log-config
    # 3. Dosya adının 'config.alloy' olduğunu belirtiyoruz
    key: config.alloy

  # 4. Alloy pod'una logları okuyabilmesi için
  #    ana makinedeki (host) klasörleri bağlıyoruz.
  #    Bu, 'discovery.relabel' kuralının çalışması için ZORUNLU.
  mounts:
    varlog: true
    dockercontainers: true
EOF

helm upgrade --install alloy grafana/alloy \
  --namespace observability \
  --values /tmp/alloy-values.yaml \
  --wait

echo "✅ Grafana Alloy Agent installed!"

# Step 5: Create Ingress Routes
echo ""
echo "Step 5: Creating Ingress routes..."

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

    # Create Prometheus Ingress
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
    
    echo "✅ Ingress routes created!"
fi

# Step 6: Verification
echo ""
echo "=== Verification ==="
echo ""

echo "Pods in observability namespace:"
kubectl get pods -n observability
echo ""

echo "Services in observability namespace:"
kubectl get svc -n observability
echo ""

echo "=== Installation Complete ==="
echo ""
if [ -z "$INGRESS_IP" ]; then
    echo "⚠️  Services accessible via ClusterIP (Nginx Ingress not found)"
    echo ""
    echo "Internal Access:"
    echo "  - Grafana:    prometheus-grafana.observability.svc.cluster.local:80"
    echo "  - Prometheus: prometheus-kube-prometheus-prometheus.observability.svc.cluster.local:9090"
else
    echo "🔗 Access URLs:"
    echo "  - Grafana:    http://grafana.${INGRESS_IP}.nip.io (admin / admin123)"
    echo "  - Prometheus: http://prometheus.${INGRESS_IP}.nip.io"
    echo ""
    echo "⚠️  Note: nip.io automatically resolves <name>.<IP>.nip.io → <IP>"
    echo "   No /etc/hosts editing needed!"
fi
echo ""
echo "Next Steps:"
echo "1. Access Grafana and go to Explore"
echo "2. Select 'Loki' datasource and query: {namespace=\"kube-system\"}"
echo "3. Select 'Prometheus' datasource and query: node_cpu_seconds_total"
echo ""
echo "Components:"
echo "  - Loki: Log storage"
echo "  - Prometheus: Metric storage"
echo "  - Grafana Alloy: Log + Metric collector (DaemonSet)"
echo "  - Grafana: Visualization"
