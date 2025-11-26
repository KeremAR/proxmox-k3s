#!/bin/bash

echo "=== Installing Grafana Alloy (Unified Observability Agent) ==="
echo ""

# Create observability namespace (idempotent)
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

# Add Helm repos
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Step 1: Create Alloy ConfigMap with full configuration
cat <<'EOF' > /tmp/alloy-full-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alloy-full-config
  namespace: observability
data:
  config.alloy: |
    // ========================================
    // === CLUSTERING CONFIGURATION ===
    // ========================================
    // Clustering is enabled via Helm values (command line flags)
    // Individual components opt-in via clustering { enabled = true }

    // ========================================
    // === LOG COLLECTION (LOKI) ===
    // ========================================

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

    loki.write "loki_db" {
      endpoint {
        url = "http://loki-gateway.observability.svc.cluster.local:80/loki/api/v1/push"
      }
    }

    // ========================================
    // === METRICS COLLECTION (PROMETHEUS) ===
    // ========================================

    // --- 1. NODE-LEVEL METRICS: Unix Exporter (node-exporter equivalent) ---
    prometheus.exporter.unix "unix" {
      procfs_path = "/host/proc"
      sysfs_path  = "/host/sys"
      rootfs_path = "/host/root"
    }

    prometheus.scrape "unix" {
      targets    = prometheus.exporter.unix.unix.targets
      forward_to = [prometheus.remote_write.prometheus.receiver]
    }

    // --- 2. NODE-LEVEL METRICS: Kubelet (includes cAdvisor metrics) ---
    // K3s kubelet exposes container metrics at /metrics/cadvisor endpoint
    discovery.kubernetes "k8s_nodes" {
      role = "node"
    }

    discovery.relabel "kubelet" {
      targets = discovery.kubernetes.k8s_nodes.targets
      
      // Set address to node IP and port
      rule {
        source_labels = ["__meta_kubernetes_node_address_InternalIP"]
        target_label  = "__address__"
        replacement   = "$1:10250"
      }
      
      // Set metrics path to cAdvisor endpoint
      rule {
        replacement  = "/metrics/cadvisor"
        target_label = "__metrics_path__"
      }
      
      // Set scheme to HTTPS
      rule {
        replacement  = "https"
        target_label = "__scheme__"
      }
      
      // Add node label
      rule {
        source_labels = ["__meta_kubernetes_node_name"]
        target_label  = "node"
      }
      
      // Add job label
      rule {
        replacement  = "kubelet"
        target_label = "job"
      }
    }

    prometheus.scrape "kubelet" {
      targets    = discovery.relabel.kubelet.output
      
      // Kubelet uses self-signed certs, skip verification
      bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
      tls_config {
        insecure_skip_verify = true
      }
      
      forward_to = [prometheus.remote_write.prometheus.receiver]
      clustering {
        enabled = true
      }
    }

    // --- 3. CLUSTER-LEVEL METRICS: Pod Discovery ---
    discovery.kubernetes "k8s_pods" {
      role = "pod"
    }

    discovery.relabel "k8s_pods" {
      targets = discovery.kubernetes.k8s_pods.targets
      
      // Keep only pods with prometheus.io/scrape=true annotation
      rule {
        source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
        action        = "keep"
        regex         = "true"
      }
      
      // Use custom port from annotation if specified
      rule {
        source_labels = ["__address__", "__meta_kubernetes_pod_annotation_prometheus_io_port"]
        action        = "replace"
        target_label  = "__address__"
        regex         = "([^:]+)(?::\\d+)?;(\\d+)"
        replacement   = "$1:$2"
      }
      
      // Use custom metrics path from annotation if specified (default /metrics)
      rule {
        source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"]
        action        = "replace"
        target_label  = "__metrics_path__"
        regex         = "(.+)"
      }
      
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
        source_labels = ["__meta_kubernetes_pod_phase"]
        target_label  = "pod_phase"
      }
      rule {
        source_labels = ["__meta_kubernetes_namespace", "__meta_kubernetes_pod_name"]
        separator     = "/"
        target_label  = "job"
      }
    }

    prometheus.scrape "k8s_pods" {
      targets    = discovery.relabel.k8s_pods.output
      forward_to = [prometheus.remote_write.prometheus.receiver]
      clustering {
        enabled = true
      }
    }

    // --- 4. ARGO ROLLOUTS METRICS ---
    prometheus.scrape "argo_rollouts" {
      targets = [{
        __address__ = "argo-rollouts-metrics.argo-rollouts.svc.cluster.local:8090",
        job         = "argo-rollouts",
      }]
      forward_to = [prometheus.remote_write.prometheus.receiver]
      clustering {
        enabled = true
      }
    }
    
    // --- 5. CLUSTER-LEVEL METRICS: Service Discovery (DISABLED) ---
    // Service discovery disabled - Pod discovery is sufficient for application metrics
    // To enable: uncomment the section below and add prometheus.io/scrape annotation to Service manifests
    /*
    discovery.kubernetes "k8s_services" {
      role = "service"
    }

    discovery.relabel "k8s_services" {
      targets = discovery.kubernetes.k8s_services.targets
      
      // Keep only services with prometheus.io/scrape=true annotation
      rule {
        source_labels = ["__meta_kubernetes_service_annotation_prometheus_io_scrape"]
        action        = "keep"
        regex         = "true"
      }
      
      // Use custom port from annotation if specified
      rule {
        source_labels = ["__address__", "__meta_kubernetes_service_annotation_prometheus_io_port"]
        action        = "replace"
        target_label  = "__address__"
        regex         = "([^:]+)(?::\\d+)?;(\\d+)"
        replacement   = "$1:$2"
      }
      
      // Use custom metrics path from annotation if specified
      rule {
        source_labels = ["__meta_kubernetes_service_annotation_prometheus_io_path"]
        action        = "replace"
        target_label  = "__metrics_path__"
        regex         = "(.+)"
      }
      
      rule {
        source_labels = ["__meta_kubernetes_namespace"]
        target_label  = "namespace"
      }
      rule {
        source_labels = ["__meta_kubernetes_service_name"]
        target_label  = "service"
      }
      rule {
        source_labels = ["__meta_kubernetes_service_type"]
        target_label  = "type"
      }
      rule {
        source_labels = ["__meta_kubernetes_service_port_number"]
        target_label  = "port_number"
      }
      rule {
        source_labels = ["__meta_kubernetes_namespace", "__meta_kubernetes_service_name"]
        separator     = "/"
        target_label  = "job"
      }
    }

    prometheus.scrape "k8s_services" {
      targets    = discovery.relabel.k8s_services.output
      forward_to = [prometheus.remote_write.prometheus.receiver]
    }
    */

    // --- 5. BLACKBOX EXPORTER: External Monitoring Probes ---
    // Probes services from OUTSIDE to measure end-to-end latency (includes network)
    // Discovers services with annotation: blackbox.prometheus.io/scrape: "true"
    
    discovery.kubernetes "k8s_services_blackbox" {
      role = "service"
      namespaces {
        names = ["staging", "production"]
      }
    }

    discovery.relabel "blackbox_services" {
      targets = discovery.kubernetes.k8s_services_blackbox.targets
      
      // 1. Initialize defaults from service metadata or static values
      rule {
        source_labels = ["__meta_kubernetes_service_port_number"]
        target_label  = "__blackbox_port__"
      }
      rule {
        target_label  = "__blackbox_path__"
        replacement   = "/ready"
      }
      rule {
        target_label  = "__param_module"
        replacement   = "http_2xx"
      }
      rule {
        target_label  = "__metrics_path__"
        replacement   = "/probe"
      }

      // 2. Override with annotations if present
      rule {
        source_labels = ["__meta_kubernetes_service_annotation_blackbox_prometheus_io_port"]
        regex         = "(.+)"
        target_label  = "__blackbox_port__"
      }
      rule {
        source_labels = ["__meta_kubernetes_service_annotation_blackbox_prometheus_io_path"]
        regex         = "(.+)"
        target_label  = "__blackbox_path__"
      }
      rule {
        source_labels = ["__meta_kubernetes_service_annotation_blackbox_prometheus_io_module"]
        regex         = "(.+)"
        target_label  = "__param_module"
      }

      // 3. Filter: Keep only services with scrape=true
      rule {
        source_labels = ["__meta_kubernetes_service_annotation_blackbox_prometheus_io_scrape"]
        action        = "keep"
        regex         = "true"
      }

      // 4. Construct Target URL
      rule {
        source_labels = ["__meta_kubernetes_service_name", "__meta_kubernetes_namespace", "__blackbox_port__", "__blackbox_path__"]
        separator     = ";"
        target_label  = "__param_target"
        regex         = "([^;]+);([^;]+);([^;]+);(.+)"
        replacement   = "http://$1.$2.svc.cluster.local:$3$4"
      }

      // 5. Set Labels
      rule {
        source_labels = ["__meta_kubernetes_service_name", "__meta_kubernetes_namespace"]
        separator     = "."
        target_label  = "instance"
      }
      rule {
        target_label  = "__address__"
        replacement   = "blackbox-exporter-prometheus-blackbox-exporter.observability.svc.cluster.local:9115"
      }
      rule {
        source_labels = ["__meta_kubernetes_namespace"]
        target_label  = "namespace"
      }
      rule {
        source_labels = ["__meta_kubernetes_service_name"]
        target_label  = "service"
      }
      rule {
        source_labels = ["__meta_kubernetes_namespace"]
        target_label  = "job"
        replacement   = "blackbox-$1"
      }
    }

    prometheus.scrape "blackbox_probes" {
      targets         = discovery.relabel.blackbox_services.output
      forward_to      = [prometheus.remote_write.prometheus.receiver]
      scrape_interval = "15s"
      scrape_timeout  = "10s"
      clustering {
        enabled = true
      }
    }

    // --- 6. REMOTE WRITE: Send all metrics to Prometheus ---
    prometheus.remote_write "prometheus" {
      endpoint {
        url = "http://prometheus-server.observability.svc.cluster.local:80/api/v1/write"
      }
    }

    // ==========================================
    // OPENTELEMETRY TRACING CONFIGURATION
    // ==========================================

    // --- 7. OTEL RECEIVER: Accept traces from Python services ---
    otelcol.receiver.otlp "default" {
      // gRPC endpoint
      grpc {
        endpoint = "0.0.0.0:4317"
      }

      // HTTP endpoint
      http {
        endpoint = "0.0.0.0:4318"
      }

      output {
        traces  = [otelcol.exporter.otlp.jaeger.input]
      }
    }

    // --- 8. OTEL EXPORTER: Forward traces to Jaeger ---
    otelcol.exporter.otlp "jaeger" {
      client {
        endpoint = "jaeger-collector.observability.svc.cluster.local:4317"
        tls {
          insecure = true
        }
      }
    }
EOF
kubectl apply -f /tmp/alloy-full-config.yaml

echo "✅ Alloy ConfigMap created"

# Step 2: Install Alloy Helm chart
cat <<EOF > /tmp/alloy-values.yaml
controller:
  type: 'daemonset'
  
  volumes:
    extra:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      - name: root
        hostPath:
          path: /

alloy:
  configMap:
    create: false
    name: alloy-full-config
    key: config.alloy

  clustering:
    enabled: true
    portName: http

  mounts:
    varlog: true
    dockercontainers: true
    extra:
      - name: proc
        mountPath: /host/proc
        readOnly: true
      - name: sys
        mountPath: /host/sys
        readOnly: true
      - name: root
        mountPath: /host/root
        readOnly: true
        mountPropagation: HostToContainer

  # Expose OTLP ports for trace ingestion
  extraPorts:
    - name: "otlp-grpc"
      port: 4317
      targetPort: 4317
      protocol: "TCP"
    - name: "otlp-http"
      port: 4318
      targetPort: 4318
      protocol: "TCP"

rbac:
  create: true
EOF

helm upgrade --install alloy grafana/alloy \
  --namespace observability \
  --values /tmp/alloy-values.yaml \
  --wait

 # Get Nginx Ingress LoadBalancer IP
INGRESS_IP=$(kubectl get service nginx-ingress-loadbalancer -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$INGRESS_IP" ]; then
    echo "⚠️  Warning: Nginx Ingress LoadBalancer not found"
    echo "   Skipping Ingress creation. Services accessible via ClusterIP only."
else
    echo "✅ Found LoadBalancer IP: $INGRESS_IP"

    echo "📝 Creating Alloy Ingress..."
    
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: alloy-ingress
  namespace: observability
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: alloy.${INGRESS_IP}.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: alloy
            port:
              number: 12345
EOF
fi

echo "✅ Grafana Alloy Agent installed!"
echo ""
echo "  - Alloy UI:   http://alloy.${INGRESS_IP}.nip.io"
echo ""
echo "⚠️  Note: nip.io automatically resolves <name>.<IP>.nip.io → <IP>"
echo "   No /etc/hosts editing needed!"
echo ""
echo "Service: alloy.observability.svc.cluster.local"
echo "Ports:"
echo "  - UI: 12345"
echo "  - OTLP gRPC: 4317"
echo "  - OTLP HTTP: 4318"
echo ""
echo "Alloy collects:"
echo "  • Logs → Loki (from /var/log/pods)"
echo "  • Metrics → Prometheus (Unix exporter, Kubelet, Pod discovery, Argo Rollouts, Blackbox probes)"
echo "  • Traces → Jaeger (via OTLP receiver)"
echo ""
echo "Blackbox Exporter probes:"
echo "  • Auto-discovers services in staging & production namespaces"
echo "  • Requires annotation: blackbox.prometheus.io/scrape: \"true\""
echo "  • Optional annotations:"
echo "    - blackbox.prometheus.io/path: \"/custom-path\" (default: /ready)"
echo "    - blackbox.prometheus.io/port: \"8080\" (default: first service port)"
echo "    - blackbox.prometheus.io/module: \"http_2xx\" (default: http_2xx)"
