# Observability Stack

This directory contains the scripts to set up a complete observability stack for the Kubernetes cluster using Grafana Alloy, Loki, Prometheus, and Grafana.

## Architecture

The observability stack is designed around Grafana Alloy acting as a unified agent for collecting both metrics and logs from all nodes in the cluster.

- **Metrics Flow**: `Grafana Alloy` -> `Prometheus` -> `Grafana`
- **Logs Flow**: `Grafana Alloy` -> `Loki` -> `Grafana`

This setup simplifies the architecture by replacing the need for separate agents like Promtail (for logs) and Prometheus Node Exporter/kube-state-metrics (for metrics).

---

## Scripts

### 1. `6A-install-alloy-observability.sh`

This script installs and configures the core components of the observability stack.

**Key Steps:**

1.  **Namespace**: Creates the `observability` namespace to house all related components.
2.  **Installs Loki**: Deploys a `loki-stack` via Helm but **disables Promtail**, as Grafana Alloy will be responsible for log collection.
3.  **Installs Prometheus & Grafana**: Deploys the `kube-prometheus-stack` via Helm.
    - It **disables the default metric collectors** (`nodeExporter`, `kubeStateMetrics`) because Alloy will handle metric gathering.
    - It configures Grafana and automatically adds the Loki instance as a data source.
4.  **Installs Grafana Alloy**: Deploys Grafana Alloy using the `k8s-monitoring` Helm chart. Alloy is configured to:
    - Scrape cluster-wide metrics and pod/node logs.
    - Forward metrics to the internal Prometheus service.
    - Forward logs to the internal Loki service.
5.  **Creates Ingress Routes**: If an NGINX Ingress Controller is found, it creates `Ingress` resources to expose the Grafana and Prometheus UIs, making them easily accessible via a browser.

### 2. `6B-create-production-dashboard.sh`

This script automatically provisions a pre-built Grafana dashboard for monitoring the health of the production applications.

**Key Steps:**

1.  **Dashboard as Code**: The dashboard is defined in a JSON format inside a Kubernetes `ConfigMap`. The `grafana_dashboard: "1"` label allows Grafana to automatically discover and load it.
2.  **Dynamic Datasource Linking**: The script intelligently queries the Grafana API to get the unique ID (`uid`) of the Loki datasource and injects it into the dashboard definition. This ensures the log panels work without manual setup.
3.  **Provisions "Production Application Health" Dashboard**: This dashboard includes panels for:
    - **Pod Status**: Desired vs. Available replicas for the frontend, user, and todo services.
    - **CPU & Memory Usage**: Time-series graphs for each service.
    - **Recent Logs**: A live stream of logs for each service, pulled directly from Loki.

---

## Accessing the Services

After running the installation script, you can access the UIs at the following URLs (the IP address will be your NGINX Ingress Load Balancer's public IP):

-   **Grafana**: `http://grafana.<INGRESS_IP>.nip.io`
    -   **Username**: `admin`
    -   **Password**: `admin123`
-   **Prometheus**: `http://prometheus.<INGRESS_IP>.nip.io`

The "Production Application Health" dashboard will be available in Grafana under the "Dashboards" section.
