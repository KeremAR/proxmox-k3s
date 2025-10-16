#!/bin/bash

# ==============================================================================
# OBSERVABILITY STACK - COMPLETE INSTALLATION
# ==============================================================================
# Purpose: Single script to install entire observability stack
# Components: OTEL Operator, Jaeger, Prometheus, Grafana, Loki, Auto-Instrumentation
# ==============================================================================

set -e

echo ""
echo "🌟 STARTING OBSERVABILITY STACK INSTALLATION"
echo "═══════════════════════════════════════════════════════════════"
echo "📊 Components: OpenTelemetry + Jaeger + Prometheus + Grafana + Loki"
echo "🎯 Auto-instrumentation: Zero code changes required"
echo "📱 Target Application: todo-app (Python Flask + React)"
echo ""

# Check if K3s is running
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Kubernetes cluster is not accessible. Please ensure K3s is running."
    exit 1
fi

echo "✅ Kubernetes cluster is accessible"
echo ""

# Step 1: Install OpenTelemetry Operator + Auto-Instrumentation
echo "🚀 STEP 1/7: Installing OpenTelemetry Operator..."
bash ./5A-install-otel-operator.sh
echo ""

# Step 2: Install Jaeger Tracing
echo "🚀 STEP 2/7: Installing Jaeger Tracing..."
bash ./5B-install-jaeger.sh
echo ""

# Step 3: Install Prometheus + Grafana
echo "🚀 STEP 3/7: Installing Prometheus + Grafana..."
bash ./5C-install-prometheus.sh
echo ""

# Step 4: Install Loki Logging
echo "🚀 STEP 4/7: Installing Loki Logging..."
bash ./5D-install-loki.sh
echo ""

# Step 5: Enable Auto-Instrumentation
echo "🚀 STEP 5/7: Enabling Auto-Instrumentation..."
bash ./5E-enable-auto-instrumentation.sh
echo ""

# Step 6: Create Grafana Dashboards
echo "🚀 STEP 6/7: Creating Grafana Dashboards..."
bash ./5F-create-grafana-dashboards.sh
echo ""

# Step 7: Test Everything
echo "🚀 STEP 7/7: Testing Observability Stack..."
bash ./5G-test-observability.sh
echo ""

echo ""
echo "🎉 OBSERVABILITY STACK INSTALLATION COMPLETED!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "🌐 ACCESS POINTS:"
echo "  🔍 Jaeger (Tracing):     http://192.168.0.113:16686"
echo "  📊 Prometheus (Metrics): http://192.168.0.114:9090"
echo "  📈 Grafana (Dashboards): http://192.168.0.115:3000 (admin/admin123)"
echo ""
echo "📱 TODO-APP (Instrumented):"
echo "  🚀 Frontend:              http://192.168.0.111/"
echo "  👤 User Service:          http://192.168.0.111/user-service/"
echo "  📝 Todo Service:          http://192.168.0.111/todo-service/"
echo ""
echo "✨ Features Enabled:"
echo "  🎯 Automatic instrumentation (no code changes)"
echo "  📊 Distributed tracing across microservices"
echo "  📈 Real-time metrics and monitoring"
echo "  📝 Centralized log aggregation"
echo "  🎨 Pre-built Grafana dashboards"
echo ""
echo "🎯 Next: Use the applications to generate telemetry data!"