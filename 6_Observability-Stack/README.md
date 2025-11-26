# Observability Stack

Complete observability stack for Kubernetes (K3s) cluster implementing the three pillars of observability: **Metrics**, **Logs**, and **Traces**.

## 📊 Architecture Overview

The observability stack is built around **Grafana Alloy** as a unified collection agent, replacing traditional separate tools (Prometheus Node Exporter, Promtail, etc.) with a single DaemonSet that collects all telemetry data.

### Data Flow

```
┌────────────────────────────────────────────────────────────────────┐
│  Kubernetes Cluster (K3s)                                          │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Grafana Alloy (DaemonSet - one pod per node)                │  │
│  │  ┌────────────────────────────────────────────────────────┐  │  │
│  │  │  Metrics Collection:                                   │  │  │
│  │  │  • Unix Exporter (node metrics)                        │  │  │
│  │  │  • Kubelet cAdvisor (container metrics)                │  │  │
│  │  │  • Pod Discovery (app metrics via annotations)         │  │  │
│  │  │  • kube-state-metrics (K8s object state)               │  │  │
│  │  │  • Argo Rollouts metrics                               │  │  │
│  │  │  └─> Remote Write → Prometheus                         │  │  │
│  │  │                                                        │  │  │
│  │  │  Logs Collection:                                      │  │  │
│  │  │  • Tail /var/log/pods (all pod logs)                   │  │  │
│  │  │  • Parse CRI/Docker formats                            │  │  │
│  │  │  └─> Push → Loki                                       │  │  │
│  │  │                                                        │  │  │
│  │  │  Traces Collection:                                    │  │  │
│  │  │  • OTLP Receiver (gRPC :4317, HTTP :4318)              │  │  │
│  │  │  └─> Forward → Jaeger                                  │  │  │
│  │  └────────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐               │
│  │ Prometheus  │   │    Loki     │   │   Jaeger    │               │
│  │  (Metrics)  │   │   (Logs)    │   │  (Traces)   │               │
│  └─────────────┘   └─────────────┘   └─────────────┘               │
│         ↓                  ↓                  ↓                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    Grafana (Visualization)                   │  │
│  │  • Dashboards  • Explore  • Alerting  • Correlation          │  │
│  └──────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

## 🗂️ Modular Installation Scripts

The observability stack is split into modular components for easy management and updates:

### Core Components

| Script | Component | Purpose |
|--------|-----------|---------|
| `6A-1-install-prometheus.sh` | Prometheus - kube-state-metrics | Metrics database with remote write receiver |
| `6A-2-install-loki.sh` | Loki | Logs database with filesystem storage |
| `6A-3-install-grafana.sh` | Grafana | Visualization UI with pre-configured datasources |
| `6A-4-install-alloy.sh` | Grafana Alloy | Unified observability agent (DaemonSet) |
| `6A-5-install-jaeger.sh` | Jaeger | Distributed tracing backend |
### Deprecated Master Script

**`OLD-install-alloy-observability.sh`** - Orchestrates installation of all components in the correct order.


### Dashboard Scripts

| Script | Purpose |
|--------|---------|
| `6B-create-production-dashboard.sh` | Production application health dashboard with logs |
| `6C-create-staging-dashboard.sh` | Staging application health dashboard with logs|

---

## 🔍 Component Details

### 1. Prometheus (Metrics Database)

**Configuration Highlights:**
- **Remote Write Receiver**: Enabled to accept metrics from Alloy agents
- **Persistent Storage**: 10Gi local-path volume
- **Minimal Scraping**: Only self-monitors (Alloy handles all collection)

**Why Remote Write?**
- Decoupled collection: Alloy scrapes, Prometheus stores
- Better scalability: Multiple agents, single database
- Unified agent: Same DaemonSet for metrics, logs, traces

**Key Configuration:**
```yaml
server:
  extraArgs:
    web.enable-remote-write-receiver: ""  # CRITICAL for Alloy
```

### 2. Loki (Logs Database)

**Configuration Highlights:**
- **SingleBinary Mode**: All components in one pod (simple deployment)
- **Filesystem Storage**: Local storage (no S3/object store needed)
- **Schema v13**: Latest stable with TSDB index

**Critical Configuration Fix:**
```yaml
loki:
  storage:
    filesystem:
      chunks_directory: /var/loki/chunks  # Note the 's' - common mistake!
  schemaConfig:
    configs:
      - object_store: filesystem  # MUST match storage.type
```

**Common Error Prevented:**
- ❌ `bucketNames required` error → Fixed by matching object_store type
- ❌ `unknown field chunk_directory` → Fixed by using `chunks_directory`

### 3. Grafana Alloy (Unified Agent)

**Deployment Type:** DaemonSet (one pod per node)

**Why DaemonSet?**
- **Metrics**: Access to node's `/proc`, `/sys`, `/root` filesystems
- **Logs**: Access to node's `/var/log/pods` directory
- **Traces**: Distributed receivers across nodes for resilience

**Host Mounts:**
```yaml
volumes:
  - /proc → /host/proc        # Node system metrics
  - /sys → /host/sys          # Node system metrics
  - / → /host/root            # Filesystem metrics
  - /var/log → /var/log       # Pod logs
```

**Alloy Configuration Components:**

#### Metrics Collection (4 Sources)

1. **Unix Exporter** (Node-level)
   - Replaces `node_exporter`
   - Collects: CPU, memory, disk, network
   - Metrics prefix: `node_*`

2. **Kubelet cAdvisor** (Container-level)
   - Endpoint: `https://<node>:10250/metrics/cadvisor`
   - Collects: Container CPU, memory, network, filesystem
   - Metrics prefix: `container_*`

3. **Pod Discovery** (Application-level)
   - Discovers pods with `prometheus.io/scrape: "true"` annotation
   - Collects: Application-specific metrics
   - Dynamic discovery via Kubernetes API

4. **kube-state-metrics** (Cluster state)
   - Discovered via pod annotations (`prometheus.io/scrape: "true"`)
   - Endpoint: `kube-state-metrics.observability.svc.cluster.local:8080`
   - Metrics prefix: `kube_*`

5. **Argo Rollouts** (Static target)
   - Endpoint: `argo-rollouts-metrics.argo-rollouts.svc.cluster.local:8090`
   - Metrics prefix: `argo_rollouts_*`

**All metrics → Remote Write → Prometheus**

**Application Metrics - Required Helm Chart Configuration:**

To enable Alloy to discover and scrape your application metrics, add these annotations to your Pod/Deployment template:

```yaml
# Helm values.yaml or deployment manifest
template:
  metadata:
    annotations:
      prometheus.io/scrape: "true"     # REQUIRED: Enable metric scraping
      prometheus.io/port: "8080"       # Optional: Custom metrics port (default: container port)
      prometheus.io/path: "/metrics"   # Optional: Custom path (default: /metrics)
```

#### Logs Collection (6-Step Pipeline)

1. **Discovery**: Find all pods via Kubernetes API
2. **Relabel**: Extract namespace, pod, container labels + build log file path
3. **File Match**: Resolve wildcards (`/var/log/pods/*/container/*.log`)
4. **File Tail**: Read log files in real-time
5. **Parse**: Extract timestamp, stream (stdout/stderr), message
   - Containerd: CRI format parser
   - Docker: JSON format parser
6. **Write**: Push to Loki with labels

**Log File Path Pattern:**
```
/var/log/pods/<namespace>_<pod>_<uid>/<container>/0.log
```

**Resulting Loki Labels:**
- `namespace`: Kubernetes namespace
- `pod`: Pod name
- `container`: Container name
- `stream`: stdout or stderr
- `job`: namespace/pod

#### Traces Collection (OTLP Receiver)

- **gRPC Endpoint**: `:4317`
- **HTTP Endpoint**: `:4318`
- **Protocol**: OpenTelemetry Protocol (OTLP)
- **Forwarding**: `jaeger-collector.observability.svc.cluster.local:4317`

**Application Configuration - Required Helm Chart Settings:**

To send traces from your application to Alloy → Jaeger, add these environment variables to your container:

```yaml
# Helm values.yaml
env:
  # REQUIRED: Alloy OTLP endpoint
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://alloy.observability.svc.cluster.local:4318"
  
  # REQUIRED: Protocol (http/protobuf recommended for performance)
  - name: OTEL_EXPORTER_OTLP_PROTOCOL
    value: "http/protobuf"
  
  # REQUIRED: Service name (appears in Jaeger)
  - name: OTEL_SERVICE_NAME
    value: "user-service"
  
  # Optional: Resource attributes (version, environment, etc.)
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "service.namespace=staging,service.version={{ .Values.image.tag }},deployment.environment=staging"
  
  # Optional: Exporter type (default: otlp)
  - name: OTEL_TRACES_EXPORTER
    value: "otlp"
```
**Application Code - Python Example:**

```python
# requirements.txt
opentelemetry-api==1.28.2
opentelemetry-sdk==1.28.2
opentelemetry-exporter-otlp==1.28.2
opentelemetry-instrumentation-fastapi==0.49b2
opentelemetry-instrumentation-psycopg2==0.49b2

# app.py
import os
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.psycopg2 import Psycopg2Instrumentor

# Configure SDK (reads OTEL_* env vars automatically)
resource = Resource.create({
    "service.name": os.getenv("OTEL_SERVICE_NAME", "user-service"),
})
trace.set_tracer_provider(TracerProvider(resource=resource))
otlp_exporter = OTLPSpanExporter()  # Uses OTEL_EXPORTER_OTLP_ENDPOINT
span_processor = BatchSpanProcessor(otlp_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

# Instrument libraries BEFORE app initialization
Psycopg2Instrumentor().instrument()

app = FastAPI()
FastAPIInstrumentor.instrument_app(app)
```

**Critical Configuration Notes:**
1. **SDK Setup Required**: Auto-instrumentation alone won't export traces without TracerProvider + Exporter
2. **Instrumentation Order**: Call `Psycopg2Instrumentor().instrument()` BEFORE creating database connections
3. **Environment Variables**: OpenTelemetry SDK reads `OTEL_*` variables automatically (no code changes needed)

### Prometheus Metrics (Python)

To expose detailed **Backend Application Latency** (processing time within FastAPI, excluding network/proxy overhead) with custom buckets:

```python
from prometheus_fastapi_instrumentator import Instrumentator, metrics

Instrumentator().add(
    metrics.latency(buckets=[0.1, 0.5, 1.0, 2.5, 5.0, 10.0])
).instrument(app).expose(app)
```

**Why Custom Buckets?**
Prometheus Histograms count requests in specific "buckets" (e.g., "requests faster than 0.1s").
- **Default Buckets**: Often too wide, making it impossible to distinguish between fast (0.2s) and slow (4.9s) requests.
- **Custom Buckets**: Essential for accurate **Quantiles** (p95, p99).
  - **p95 (95th Percentile)**: "95% of requests are faster than X".
  - To accurately measure if p95 is < 250ms, you **must** have a bucket boundary near 0.25s. Without it, Prometheus interpolates (guesses) the value, leading to inaccurate graphs.

### 4. kube-state-metrics

**Purpose:** Kubernetes API object metrics (not container runtime metrics)

**Metrics Examples:**
- `kube_pod_info`: Pod metadata
- `kube_deployment_status_replicas`: Deployment replica counts
- `kube_node_status_condition`: Node health status

**Discovery Method:** Annotation-based
```yaml
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
```

**Difference from Kubelet Metrics:**
- **Kubelet**: Container resource usage (CPU, memory)
- **kube-state-metrics**: Kubernetes desired vs actual state

### 5. Jaeger (Distributed Tracing)

**Deployment:** All-in-one mode

**Features:**
- OTLP collector (receives from Alloy)
- In-memory storage (development setup)
- Query service + UI

**Trace Flow:**
```
Python App (OTel SDK) → Alloy (OTLP) → Jaeger Collector → Jaeger UI
```

**Application Instrumentation:**
```python
# Library instrumentation (automatic spans)
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.psycopg2 import Psycopg2Instrumentor

Psycopg2Instrumentor().instrument()  # Before app init
FastAPIInstrumentor.instrument_app(app)
```

---

## 📊 Pre-Built Dashboards

### Staging Environment - Elite Troubleshooting Dashboard

**Script:** `6C-create-staging-dashboard.sh`

**Purpose:** Comprehensive staging environment monitoring with ROOT CAUSE ANALYSIS workflow for rapid troubleshooting.

**Dashboard Structure (16 Panels):**

#### 🔥 At-a-Glance Health (Top Row - 3 Panels)
Instant system health check in one glance:

1. **Overall Error Rate (5xx)** - Is anything broken right now?
   - Green (< 0.1 req/s): Healthy
   - Yellow (0.1-1 req/s): Warning
   - Red (> 1 req/s): Critical

2. **Total Request Rate** - How much traffic is the system handling?
   - Shows requests per second across all services

3. **Worst Latency (p99)** - What's the slowest response time?
   - Green (< 0.5s): Fast
   - Yellow (0.5-1s): Slow
   - Red (> 1s): Very Slow

#### 🔄 Pod Health Investigation (Row 2 - 2 Panels)
Answers "WHY are things broken?"

4. **Pod Restart Rate (Last 5m)** - Bar chart showing **WHAT** is restarting
   - Visual spike = problem pod identified

5. **Pod Status Events Table** - Shows **WHY** pods are restarting
   - 🔴 **OOMKilled** → Memory limit too low
   - 🟠 **CrashLoopBackOff** → Application crash (check logs)
   - 🟡 **ImagePullBackOff** → Image not found/registry issue
   - 🟣 **Evicted** → Node resource pressure
   - 🔵 **FailedScheduling** → No resources available

#### 📱 Frontend Service (Row 3 - 3 Panels)

6. **Rollout Status** - Available vs Desired replicas
7. **CPU & Memory Usage** - Resource consumption over time
8. **Logs** - Live log stream from Loki

#### 👤 User Service (Rows 4-5 - 6 Panels)
Dependency layer - problems here cascade to frontend

9. **Rollout Status** - Pod availability
10. **HTTP Rate by Status** - 2xx (success), 4xx (client errors), 5xx (server errors)
11. **Latency Percentiles** - p50/p95/p99 response times
12. **Error Rate (5xx)** - Server error trend
13. **CPU & Memory** - Resource usage
14. **Logs** - Live log stream

#### 📝 Todo Service (Rows 6-7 - 6 Panels)
Root cause layer - problems start here

15-20. **Same structure as User Service** - Status, HTTP rate, latency, errors, resources, logs

#### 🖥️ Node Infrastructure (Bottom Row - 2 Panels)

21. **Node CPU Usage (%)** - Host CPU saturation per node
22. **Node Memory Usage (%)** - Host memory pressure per node

**Troubleshooting Workflow (Bottom-Up Analysis):**

```
1. Check At-a-Glance Row
   └─ Is overall error rate high? → YES: Continue investigation
   
2. Check Pod Restart Rate + Status Events
   └─ Which pod is restarting? → Identify problem service
   └─ Why is it restarting? → Check event reason
   
3. Read Services BOTTOM-UP (Todo → User → Frontend)
   
   Step 1: Check Todo Service (Root Cause Layer)
   ├─ Error Rate 5xx HIGH? → Root cause found!
   ├─ Latency p99 HIGH? → Database/query issue
   └─ Logs showing errors? → Application bug
   
   Step 2: Todo Service GREEN? Check User Service
   ├─ Error Rate 5xx HIGH? → Problem in User Service
   ├─ Latency HIGH? → Waiting for Todo Service response
   └─ Logs showing errors? → User Service bug
   
   Step 3: Both GREEN? Check Frontend
   ├─ Error Rate HIGH? → Frontend issue
   └─ Logs showing errors? → Browser/client issue
   
4. Check Node Infrastructure (if all services look healthy)
   ├─ Node CPU > 80%? → Host CPU saturation
   ├─ Node Memory > 80%? → Host memory pressure
   └─ Pod Evicted events? → Node resource exhaustion
```

**Common Patterns & Solutions:**

| Pattern | Root Cause | Solution |
|---------|-----------|----------|
| Pod Restart + OOMKilled | Memory limit too low | Increase `resources.limits.memory` in Helm values |
| Pod Restart + CrashLoopBackOff | Application crash | Check logs for stack traces, fix code bug |
| Pod Restart + ImagePullBackOff | Image not found | Verify image name, tag, and registry credentials |
| Todo Service 5xx + Latency HIGH | Database slow queries | Check database connections, add indexes |
| User Service 5xx + Todo GREEN | User Service bug | Check User Service logs for errors |
| All Services GREEN + Node CPU HIGH | Host saturation | Scale cluster (add nodes) or reduce pod resources |

**Key Features:**
- ✅ **Root Cause Isolation**: Bottom-up analysis finds the failing service quickly
- ✅ **Event Correlation**: Pod restarts linked to specific reasons (OOM, crash, etc.)
- ✅ **Latency Breakdown**: p50/p95/p99 shows if it's a few slow requests or systemic issue
- ✅ **Log Integration**: One-click from metrics to logs for the same pod
- ✅ **Argo Rollouts Support**: Shows canary/stable replica status during deployments

---

### Global SRE Overview - Cluster Health & Service Status

**Script:** `6E-create-global-sre-overview-dashboard.sh`

**Purpose:** High-level cluster monitoring dashboard for SRE teams. Provides instant cluster health status and enables drill-down into individual services.

**Dashboard Structure (9 Panels):**

#### 🎯 Global KPIs (Top Row - 4 Panels)
Instant cluster-wide health metrics:

1. **Global Success Rate (%)** - Overall cluster health indicator
   - Red (< 95%): Critical issues across cluster
   - Yellow (95-99%): Some services degraded
   - Green (> 99%): Healthy cluster

2. **Global Traffic (RPS)** - Total request volume across all services
   - Shows cluster-wide traffic patterns

3. **Global Error Rate (5xx)** - Total server errors across cluster
   - Green (< 0.1 req/s): Healthy
   - Yellow (0.1-1 req/s): Warning
   - Red (> 1 req/s): Critical

4. **Global P95 Latency** - Worst-case performance across cluster
   - Identifies performance bottlenecks

#### 🔥 Error Analysis (Row 2 - 2 Panels)

5. **Top 5 Error Generators (5xx Rate)** - Which services produce most errors?
   - Table showing namespace, service, pod, and error rate
   - Sorted by error rate (highest first)
   - Color-coded thresholds

6. **Service Traffic Distribution (RPS)** - Traffic breakdown by service
   - Top 10 services by request volume
   - Time series showing traffic patterns

#### 🏥 Service Health Grid (Drill-Down Enabled)
**The core panel for service discovery and drill-down**

7. **Service Health Grid** - Comprehensive service health table
   - **Namespace** - Environment (staging, production)
   - **Service** - Service name (clickable for drill-down)
   - **Total RPS** - Total request rate
   - **Success RPS** - 2xx response rate
   - **Error RPS** - 5xx error rate (color-coded)
   - **P95 Latency (s)** - 95th percentile response time
   - **Success Rate** - Calculated success percentage

**Drill-Down Feature:**
- Click any service name → Navigate to Microservice Detail Dashboard
- URL parameters automatically passed: `?var-namespace=<namespace>&var-service=<service>`
- Enables quick deep-dive from cluster overview to service details

#### 📈 Trend Analysis (Bottom Row - 2 Panels)

8. **Global Success Rate Trend** - Historical success rate over time
   - Shows if cluster health is improving or degrading
   - Color-coded thresholds (red < 95%, yellow 95-99%, green > 99%)

9. **Global Error Rate Trend (5xx)** - Historical error rate over time
   - Identifies error rate spikes and patterns

**Key Features:**
- ✅ **Namespace Filtering**: Dropdown to filter by namespace (staging, production, or All)
- ✅ **Drill-Down Navigation**: One-click from service health grid to detailed service analysis
- ✅ **Color-Coded Health**: Visual indicators for quick health assessment
- ✅ **Top-Down View**: Start here, drill down to service details when needed

**Usage Pattern:**
```
1. Open Global SRE Overview Dashboard
   └─ Check Global KPIs → Is cluster healthy?
   
2. High error rate detected?
   └─ Check Top 5 Error Generators → Which service?
   └─ Check Service Health Grid → Find the problematic service
   
3. Click service name in Service Health Grid
   └─ Drill down to Microservice Detail Dashboard
   └─ Analyze RED metrics, logs, and traces
```

---

### Infrastructure & Cluster - Node & Pod Resource Analysis

**Script:** `6F-create-infrastructure-cluster-dashboard.sh`

**Purpose:** Infrastructure-level monitoring for identifying resource bottlenecks, noisy neighbors, and cluster capacity issues.

**Dashboard Structure (12 Panels):**

#### 🖥️ Cluster-Wide Saturation (Top Row - 4 Panels)
Overall resource utilization across the cluster:

1. **Cluster CPU Saturation (%)** - Average CPU usage across all nodes
   - Green (< 70%): Healthy
   - Yellow (70-85%): High usage
   - Red (> 85%): Critical saturation

2. **Cluster Memory Saturation (%)** - Average memory usage across all nodes
   - Green (< 75%): Healthy
   - Yellow (75-90%): High usage
   - Red (> 90%): Critical saturation

3. **Cluster Disk Usage (%)** - Disk space utilization
   - Green (< 80%): Healthy
   - Yellow (80-90%): High usage
   - Red (> 90%): Critical - action required

4. **Network Traffic (In/Out)** - Cluster-wide network throughput (MB/s)
   - Shows receive and transmit rates

#### 🔍 Node Detail Section (Variable: $node)
**Filterable by node** - Select specific node or "All" from dropdown

5. **Node CPU Usage (%)** - Per-node CPU utilization over time
   - Filtered by `$node` variable
   - Shows which node is CPU-saturated

6. **Node Memory Usage (%)** - Per-node memory utilization over time
   - Filtered by `$node` variable
   - Identifies memory pressure per node

7. **Node Disk I/O (Read/Write MB/s)** - Disk throughput per node
   - Filtered by `$node` variable
   - Detects disk bottlenecks

8. **Node Network Traffic (MB/s)** - Network throughput per node
   - Filtered by `$node` variable
   - Shows receive/transmit rates per node

#### 🏆 Noisy Neighbor Analysis (Middle Section - 2 Tables)

9. **Top 15 Memory Consumers** - Which pods use most RAM?
   - Node, Namespace, Pod, Memory (MB)
   - Sorted by memory usage (highest first)
   - Color-coded: 100MB+ (orange), 500MB+ (red)

10. **Top 15 CPU Consumers** - Which pods use most CPU?
    - Node, Namespace, Pod, CPU (cores)
    - Sorted by CPU usage (highest first)
    - Color-coded: 0.5+ cores (orange), 1+ cores (red)

#### ⚠️ Problematic Pod Events (Bottom Section - 2 Panels)

11. **Problematic Pod Events Table** - Critical pod status issues
    - 🔴 **OOMKilled** → Memory limit exceeded
    - 🟠 **CrashLoopBackOff** → Application repeatedly crashing
    - 🟡 **ImagePullBackOff/ErrImagePull** → Image not found
    - 🟣 **Evicted** → Node resource pressure forced eviction
    - 🔵 **FailedScheduling** → No resources available for scheduling

12. **Pod Restart Rate (Last 5m)** - Top 10 restarting pods
    - Bar chart showing restart rate per pod/container
    - Spikes indicate instability

**Key Features:**
- ✅ **Node Filtering**: `$node` variable to focus on specific nodes
- ✅ **Noisy Neighbor Detection**: Identify resource-hogging pods quickly
- ✅ **Root Cause Analysis**: Link pod events to resource exhaustion
- ✅ **Capacity Planning**: Understand cluster resource utilization

**Troubleshooting Workflow:**
```
1. Check Cluster-Wide Saturation
   └─ High CPU/Memory? → Capacity issue or noisy neighbor
   
2. Select specific node from $node dropdown
   └─ Check Node CPU/Memory/Disk/Network panels
   └─ Which node is saturated?
   
3. Check Noisy Neighbor Tables
   └─ Which pod is consuming excessive resources?
   └─ Is it expected (batch job) or unexpected (memory leak)?
   
4. Check Problematic Pod Events
   └─ OOMKilled? → Increase memory limits
   └─ Evicted? → Node pressure, scale cluster or reduce pod resources
   └─ CrashLoopBackOff? → Application bug, check logs
```

---

### Microservice Detail - RED Method Analysis

**Script:** `6G-create-microservice-detail-dashboard.sh`

**Purpose:** Deep-dive service analysis using RED Method (Rate, Errors, Duration). Provides comprehensive service health monitoring with logs and tracing integration.

**Dashboard Structure (13 Panels):**

#### 🎯 RED Method KPIs (Top Row - 4 Panels)
Instant service health status:

1. **Rollout Status** - Argo Rollouts replica availability
   - Shows Available vs Desired replicas
   - Red (< 1): Service down
   - Green (≥ 1): Service healthy

2. **📊 Rate - Request Rate (RPS)** - Current request volume
   - Total requests per second to this service

3. **🔥 Errors - Error Rate (5xx)** - Server error rate
   - Green (< 0.01 req/s): Healthy
   - Yellow (0.01-0.1 req/s): Warning
   - Red (> 0.1 req/s): Critical

4. **⏱️ Duration - P95 Latency** - 95th percentile response time
   - Green (< 0.5s): Fast
   - Yellow (0.5-1s): Slow
   - Red (> 1s): Very slow

#### 📈 RED Method Details (Rows 2-3)

5. **Rate - Request Rate Over Time** - Request volume trend per pod
   - Shows traffic distribution across pods
   - Identifies load balancing issues

6. **Errors - HTTP Status Code Distribution** - Status code breakdown
   - 2xx (green): Success
   - 4xx (yellow): Client errors
   - 5xx (red): Server errors

7. **Duration - Latency Percentiles (p50/p95/p99)** - Full latency distribution
   - p50: Median response time (typical user experience)
   - p95: 95th percentile (slowest 5% of requests)
   - p99: 99th percentile (tail latency)

#### 💻 Resources (Row 4 - 2 Panels)

8. **CPU Usage by Pod** - CPU consumption per pod
   - Identifies CPU-heavy pods
   - Shows CPU spikes during load

9. **Memory Usage by Pod** - Memory consumption per pod
   - Identifies memory leaks
   - Shows memory growth patterns

#### 📝 Logs & Tracing (Row 5 - 2 Panels)

10. **Service Logs (Loki)** - Real-time log stream
    - Filtered by namespace and service
    - Shows timestamps, log levels, and messages
    - Searchable and filterable

11. **Tracing - Jaeger Link** - Distributed tracing integration
    - Direct link to Jaeger UI for this service
    - Pre-filtered by service name
    - Enables trace analysis for slow requests

#### ⚠️ Health Indicators (Bottom Row - 2 Panels)

12. **Pod Restart Rate** - Pod restart frequency
    - Detects pod instability
    - Shows which pods are restarting frequently

13. **Pod Status Events** - Critical pod status issues
    - 🔴 **OOMKilled** → Increase memory limits
    - 🟠 **CrashLoopBackOff** → Check logs for crashes
    - 🟡 **ImagePullBackOff** → Verify image name/registry
    - 🔴 **Error** → Pod terminated with error

**Key Features:**
- ✅ **RED Method Compliance**: Industry-standard service monitoring (Rate, Errors, Duration)
- ✅ **Variable Driven**: `$namespace` and `$service` variables for dynamic filtering
- ✅ **Log Integration**: Direct access to service logs via Loki
- ✅ **Trace Integration**: One-click to Jaeger for distributed tracing
- ✅ **Resource Correlation**: Link service performance to resource usage
- ✅ **Drill-Down Target**: Designed to receive drill-down from Global SRE Dashboard

**Variable Usage:**
- **$namespace**: Select target namespace (staging, production, etc.)
- **$service**: Select target service (auto-populated from Argo Rollouts)

**Troubleshooting Workflow:**
```
1. Arrived from Global SRE Dashboard drill-down
   └─ Namespace and service already selected
   
2. Check RED Method KPIs (Top Row)
   └─ High error rate? → Check "Errors - HTTP Status Code Distribution"
   └─ High latency? → Check "Duration - Latency Percentiles"
   
3. High error rate detected?
   └─ Check "Service Logs" panel
   └─ Search for error messages, stack traces
   
4. High latency detected?
   └─ Click "Jaeger Link" → Analyze slow traces
   └─ Check "CPU Usage" → Is service CPU-saturated?
   
5. Check "Pod Restart Rate" + "Pod Status Events"
   └─ OOMKilled? → Increase memory limits
   └─ CrashLoopBackOff? → Application bug in logs
```

**Integration with Global SRE Dashboard:**
- URL: `/d/microservice-detail?var-namespace=<namespace>&var-service=<service>`
- Automatically receives namespace and service parameters from drill-down
- Enables seamless navigation from cluster overview to service details

---

## 🏗️ Architecture Decisions

### Why Grafana Alloy Instead of Separate Agents?

**Traditional Stack:**
- Prometheus Node Exporter (metrics)
- Promtail (logs)
- OpenTelemetry Collector (traces)
- = 3+ DaemonSets

**Our Stack:**
- Grafana Alloy (all three)
- = 1 DaemonSet

**Benefits:**
- ✅ Reduced resource usage (fewer pods)
- ✅ Unified configuration (single ConfigMap)
- ✅ Consistent labeling across signals
- ✅ Easier troubleshooting (one agent to debug)

### Why Remote Write for Metrics?

**Traditional:** Prometheus scrapes targets directly

**Our Setup:** Alloy scrapes → Prometheus receives via remote write

**Benefits:**
- ✅ Decoupled collection from storage
- ✅ Alloy handles service discovery complexity
- ✅ Better scalability (stateless agents)
- ✅ Simplified RBAC (only Alloy needs cluster permissions)

### Why DaemonSet for Alloy?

**Alternatives:** Deployment, StatefulSet

**Why DaemonSet:**
- ✅ Node-level metrics need host filesystem access
- ✅ Logs are stored per-node (local file tailing)
- ✅ Distributed trace collection (resilience)
- ✅ Automatic scaling (new nodes get agent automatically)

### Why Filesystem Storage for Loki?

**Alternatives:** S3, GCS, Azure Blob

**Why Filesystem:**
- ✅ Simple setup (no external dependencies)
- ✅ Good for dev/small clusters
- ✅ No cloud costs
- ✅ Fast local I/O

**Production Consideration:** Switch to object storage for multi-node Loki deployments

### Why Annotation-Based Pod Discovery?

**Alternatives:** ServiceMonitor (Prometheus Operator), PodMonitor

**Why Annotations:**
- ✅ No operator dependency
- ✅ Simple opt-in model (`prometheus.io/scrape: "true"`)
- ✅ Works with any deployment tool
- ✅ Standard pattern across ecosystem