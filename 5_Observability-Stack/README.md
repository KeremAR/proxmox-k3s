# Observability Stack - OpenTelemetry + Prometheus + Grafana + Jaeger + Loki

Complete cloud-native observability solution for K3s cluster with **automatic instrumentation** - zero application code changes required.

## 🌟 Overview

This observability stack provides comprehensive monitoring, tracing, and logging for your Kubernetes applications using:

- **OpenTelemetry Operator**: Automatic instrumentation for Python (Flask) and Node.js (React)
- **OTEL Collector**: Central telemetry data processing and routing
- **Jaeger**: Distributed tracing and request flow visualization
- **Prometheus**: Metrics collection and storage
- **Grafana**: Unified dashboards for metrics, traces, and logs
- **Loki**: Log aggregation and querying

## 🎯 Key Features

### ✨ Zero Code Changes
- **Automatic Instrumentation**: Applications are instrumented at runtime using OpenTelemetry Operator
- **Annotation-Based**: Simple Kubernetes annotations enable instrumentation
- **Language Support**: Python (Flask) and Node.js (React) auto-instrumentation

### 📊 Complete Observability
- **Distributed Tracing**: Follow requests across microservices
- **Custom Metrics**: Application and infrastructure metrics
- **Centralized Logging**: All container logs in one place
- **Real-time Dashboards**: Pre-built Grafana dashboards

### 🔧 Production-Ready
- **LoadBalancer Access**: External IP addresses for all UIs
- **Persistent Storage**: Data retention for metrics and logs
- **Resource Limits**: Optimized for homelab environments
- **High Availability**: Fault-tolerant configuration

## 🚀 Quick Start

### Prerequisites
- K3s cluster with MetalLB LoadBalancer (IP range: 192.168.0.110-115)
- Deployed todo-app in `production` namespace
- Helm 3.x installed

### One-Click Installation from GitHub
```bash
# Direct installation from GitHub (no local files needed)
curl -sSL https://raw.githubusercontent.com/KeremAR/proxmox-k3s/main/5_Observability-Stack/install-observability-stack.sh | bash
```

### One-Click Installation (Local Files)
```bash
cd 5_Observability-Stack/
chmod +x *.sh
./install-observability-stack.sh
```

### Manual Step-by-Step Installation
```bash
# 1. Install OpenTelemetry Operator + Auto-Instrumentation
./5A-install-otel-operator.sh

# 2. Install Jaeger Tracing
./5B-install-jaeger.sh

# 3. Install Prometheus + Grafana
./5C-install-prometheus.sh

# 4. Install Loki Logging
./5D-install-loki.sh

# 5. Enable Auto-Instrumentation for todo-app
./5E-enable-auto-instrumentation.sh

# 6. Create Grafana Dashboards
./5F-create-grafana-dashboards.sh

# 7. Test and Verify Installation
./5G-test-observability.sh
```

## 🌐 Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| **Jaeger UI** | http://192.168.0.113:16686 | None |
| **Prometheus** | http://192.168.0.114:9090 | None |
| **Grafana** | http://192.168.0.115:3000 | admin / admin123 |
| **Todo-App** | http://192.168.0.111/ | Instrumented |

## 📊 Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Applications  │───▶│  OTEL Collector  │───▶│   Observability │
│                 │    │                  │    │    Backends     │
│ • Frontend      │    │ • Receives OTLP  │    │ • Jaeger        │
│ • User-Service  │    │ • Processes Data │    │ • Prometheus    │
│ • Todo-Service  │    │ • Routes Export  │    │ • Loki          │
└─────────────────┘    └──────────────────┘    └─────────────────┘
        │                        │                        │
        │                        │                        ▼
        │                        │               ┌─────────────────┐
        │                        │               │    Grafana      │
        │                        │               │                 │
        │                        │               │ • Dashboards    │
        └────────────────────────┼───────────────│ • Visualization │
                                 │               │ • Alerting      │
                                 │               └─────────────────┘
                                 │
                    ┌────────────────────────┐
                    │ OpenTelemetry Operator │
                    │                        │
                    │ • Auto-Instrumentation │
                    │ • Language Support     │
                    │ • Runtime Injection    │
                    └────────────────────────┘
```

## 🎯 Auto-Instrumentation Details

### How It Works
1. **OpenTelemetry Operator** deployed cluster-wide
2. **Instrumentation CRDs** created for Python and Node.js
3. **Pod Annotations** added to application deployments
4. **Runtime Injection** of OTEL libraries at pod startup
5. **Automatic Data Export** to OTEL Collector

### Supported Frameworks
- **Python**: Flask, Django, FastAPI, SQLAlchemy, Requests
- **Node.js**: Express, HTTP/HTTPS, File System operations
- **Automatic Discovery**: Database connections, HTTP clients, etc.

### Generated Telemetry
- **Traces**: HTTP requests, database queries, service calls
- **Metrics**: Request rate, duration, error rate, resource usage
- **Logs**: Application logs with trace correlation

## 📈 Pre-Built Dashboards

### 1. Kubernetes Overview
- Pod status and health metrics
- CPU and memory usage by pod
- Network I/O statistics
- Resource utilization trends

### 2. Todo-App Performance
- HTTP request rate and response times
- Database connection pools
- Error rates and status codes
- Application-specific metrics

### 3. OpenTelemetry Collector
- Telemetry pipeline health
- Data ingestion rates
- Export queue sizes
- Collector resource usage

## 🔍 Troubleshooting

### Common Issues

#### No Traces in Jaeger
```bash
# Check OTEL Collector status
kubectl get pods -n observability -l app.kubernetes.io/name=otel-collector

# Verify instrumentation annotations
kubectl describe deployment frontend -n production | grep instrumentation

# Check OTEL environment variables
kubectl exec -n production <pod-name> -- env | grep OTEL
```

#### Missing Metrics in Prometheus
```bash
# Check OTEL Collector metrics endpoint
kubectl exec -n observability deployment/prometheus-kube-prometheus-operator -- \
  curl http://otel-collector.observability.svc.cluster.local:8889/metrics

# Verify Prometheus targets
curl http://192.168.0.114:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="otel-collector")'
```

#### Grafana Dashboard Issues
```bash
# Check dashboard ConfigMaps
kubectl get configmaps -n observability -l grafana_dashboard=1

# Restart Grafana to reload dashboards
kubectl rollout restart deployment/prometheus-grafana -n observability
```

### Verification Commands
```bash
# Check all observability pods
kubectl get pods -n observability

# Verify LoadBalancer IPs
kubectl get svc -n observability -o wide

# Test OTEL Collector connectivity
kubectl run test-pod --image=curlimages/curl -it --rm -- \
  curl -v http://otel-collector.observability.svc.cluster.local:4317
```

## 🧪 Testing and Validation

### Generate Test Data
```bash
# Run load test to generate traces
for i in {1..50}; do
  curl -s http://192.168.0.111/ > /dev/null
  curl -s http://192.168.0.111/user-service/health > /dev/null
  curl -s http://192.168.0.111/todo-service/health > /dev/null
  sleep 1
done
```

### Verify Telemetry Data
1. **Jaeger**: Check for service maps and trace details
2. **Prometheus**: Query metrics like `http_requests_total`
3. **Grafana**: View real-time dashboards
4. **Loki**: Search application logs

## 🔧 Configuration

### OTEL Collector Configuration
The collector is configured to:
- Receive OTLP data on ports 4317 (gRPC) and 4318 (HTTP)
- Export traces to Jaeger
- Export metrics to Prometheus
- Export logs to Loki

### Auto-Instrumentation Settings
- **Sampling**: 100% trace sampling (configurable)
- **Propagation**: W3C TraceContext and Baggage
- **Endpoints**: Automatic OTEL Collector discovery
- **Resource Detection**: Kubernetes metadata injection

## 📚 Additional Resources

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)

## 🎉 What's Next?

After installation, explore:
1. 🔍 **Distributed Tracing**: Follow request flows in Jaeger
2. 📊 **Custom Dashboards**: Create application-specific Grafana dashboards
3. 🚨 **Alerting**: Set up Prometheus alerts for critical metrics
4. 📝 **Log Analysis**: Use Loki queries for troubleshooting
5. 🔧 **Custom Metrics**: Add business-specific instrumentation