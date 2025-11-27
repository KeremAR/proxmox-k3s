# Chaos Engineering Experiments

This directory contains the Chaos Engineering experiments for the `todo-service`, implemented using **LitmusChaos** and orchestrated via **Argo Workflows**.

## Overview

The goal of these experiments is to validate the resilience and observability of the application under various failure conditions. Each experiment uses **Prometheus Probes** to verify that the system behaves as expected (e.g., latency increases, alerts fire, pods recover).

## Experiments

### 1. Pod Network Latency (`pod-network-latency-workflow.yaml`)

Simulates network degradation to test the application's behavior under slow network conditions.

*   **Fault:** Injects **2000ms** latency on the `eth0` interface of the `todo-service` pod.
*   **Duration:** 60 seconds.
*   **Validation Probes:**
    *   **HTTP Health Check:** Verifies `/ready` endpoint returns 200.
    *   **P95 Latency:** Checks if application P95 latency stays within acceptable limits (or alerts).
    *   **Error Rate:** Ensures error rate doesn't exceed 1% (5xx errors).
    *   **Network Latency Validation:** Uses **Blackbox Exporter** metrics (`probe_duration_seconds`) to confirm that end-to-end latency actually increased (Expectation: `>= 1.5s`).
    *   **Pod Availability:** Ensures the pod remains `UP` in Prometheus.

> **Note on High Latency (Amplification Effect):**
> You may observe a latency of ~9.5s despite injecting only 2s of delay. This is due to the network chaos applying to the pod interface (`eth0`), affecting **every** packet:
> *   The `/ready` endpoint connects to the Database.
> *   **Outbound DB Connection:** TCP Handshake (SYN, ACK) + Query sending = Multiple packets delayed by 2s each.
> *   **Outbound Probe Response:** The final HTTP response to Blackbox is also delayed by 2s.
> *   **Total:** Accumulation of multiple delayed steps results in ~8-10s total latency.

### 2. Pod CPU Hog (`pod-cpu-hog-workflow.yaml`)

Simulates CPU exhaustion to test resource limits and autoscaling/throttling behavior.

*   **Fault:** Consumes **1 CPU Core** on the `todo-service` pod.
*   **Duration:** 60 seconds.
*   **Validation Probes:**
    *   **HTTP Health Check:** Verifies `/ready` endpoint is responsive.
    *   **P95 Latency:** Checks for performance degradation.
    *   **Error Rate:** Checks for stability.
    *   **CPU Usage Validation:** Uses `container_cpu_usage_seconds_total` to confirm CPU usage spiked (Expectation: `>= 0.05` cores).
    *   **Pod Availability:** Ensures the pod remains `UP`.

### 3. Pod Memory Hog (`pod-memory-hog-workflow.yaml`)

Simulates memory leaks or high memory pressure to test OOM (Out of Memory) handling.

*   **Fault:** Consumes **500MB** of Memory on the `todo-service` pod.
*   **Duration:** 60 seconds.
*   **Validation Probes:**
    *   **HTTP Health Check:** Verifies `/ready` endpoint is responsive.
    *   **P95 Latency:** Checks for performance degradation.
    *   **Error Rate:** Checks for stability.
    *   **Memory Usage Validation:** Uses `container_memory_usage_bytes` to confirm memory usage spiked (Expectation: `>= 200MB`).
    *   **Pod Availability:** Ensures the pod remains `UP`.

### 4. Pod Delete (`pod-delete-workflow.yaml`)

Simulates a crash or eviction of the pod to verify the deployment's self-healing capabilities.

*   **Fault:** Deletes the `todo-service` pod.
*   **Duration:** 30 seconds.
*   **Validation Probes:**
    *   **HTTP Health Check:** Verifies the service recovers and becomes ready again.
    *   **P95 Latency:** Checks impact on latency during recovery.
    *   **Error Rate:** Checks for dropped requests during failover.
    *   **Pod Availability:** Ensures the pod count returns to the expected number (ReplicaSet recovery).

### 5. K6 Load Generation (`pod-k6-loadgen-workflow.yaml`)

Generates HTTP load using k6 to test application behavior and performance under stress.

*   **Load Pattern:** Progressive ramp-up (20 → 50 → 100 users) over 60 seconds.
*   **Duration:** 60 seconds total.
*   **Prerequisites:** K6 script must be stored in a Kubernetes Secret (created from `script.js`)
*   **Test Endpoints:**
    *   `GET /ready` - Health check (no auth)
    *   `GET /todos` - List todos (with JWT auth)
    *   `POST /todos` - Create new todo (with JWT auth)
*   **K6 Thresholds:**
    *   P95 latency < 2000ms
    *   Error rate < 10%
*   **Validation Probes:**
    *   **HTTP Health Check:** Continuous monitoring of `/ready` endpoint.
    *   **P95 Latency:** Checks latency stays under 3s (allowing for load impact).
    *   **Error Rate:** Ensures error rate stays below 10%.
    *   **Request Rate Validation (EOT):** Confirms load was generated using `increase()` - checks ≥300 total requests in last 5 minutes.
    *   **Pod Availability:** Ensures pods remain available under load.

> **Note:** This experiment generates real traffic to test how the application handles load, including database operations. The test automatically creates a test user and obtains JWT token during setup phase.
> 
> **EOT Probes:** Request  probe use `increase()` and `avg_over_time()` with 5-minute windows to capture test activity even after completion, preventing false negatives.

**Setup for K6 Load Test:**
```bash
# 1. Create the k6 script secret from the script.js file
kubectl create secret generic k6-script \
  --from-file=script.js=script.js \
  -n litmus
```
---

## ⚠️ Critical Prerequisite: Kernel Compatibility

The standard Ubuntu Cloud images for KVM (`linux-image-kvm`) are optimized for size and **do not** include the `sch_netem` kernel module, which is required for network emulation (latency, packet loss, etc.).

If you try to run the experiment on a KVM kernel, you will see this error:
> `HELPER_ERROR: failed to create tc rules: Error: Specified qdisc kind is unknown.`

### Solution: Switch to Generic Kernel

We must switch both the **Master** and **Worker** nodes to the standard Ubuntu `generic` kernel.

**Automated Script:**
Run the included script on **ALL** nodes (Master and Workers):

```bash
chmod +x switch-to-generic-kernel.sh
./switch-to-generic-kernel.sh
```

**What this script does:**
1. Installs `linux-generic` (complete kernel stack).
2. Removes conflicting `linux-image-*-kvm` packages to force GRUB to use the new kernel.
3. Updates GRUB.

**After running the script, you MUST reboot:**
```bash
sudo reboot
```

**Verification:**
After reboot, check the kernel version:
```bash
uname -r
# Output should end with "-generic", e.g., "5.15.0-161-generic"
```
Check if the module can be loaded:
```bash
sudo modprobe sch_netem
# Should return no error
```

## Experiment Configuration

The `pod-network-latency-workflow.yaml` has been configured with the following essential settings for K3s:

*   **Socket Path:** `/run/k3s/containerd/containerd.sock` (Required for K3s)
*   **Container Runtime:** `containerd`
*   **Privileged Mode:** `true` (Required for network manipulation)
*   **Capabilities:** `NET_ADMIN`, `SYS_ADMIN`
*   **TC Image:** `gaiadocker/iproute2` (Provides the `tc` command)

## Running the Experiment

Once the kernel is updated on all nodes, run the experiment using the setup script:

```bash
./8B-setup-experiment.sh pod-network-latency-workflow.yaml
```
