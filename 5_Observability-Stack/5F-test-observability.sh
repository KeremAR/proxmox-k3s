#!/bin/bash

# ==============================================================================
# 5G - Test Observability Stack
# ==============================================================================
# Purpose: Generate telemetry data and verify all components are working
# Components: Load testing, verification scripts, troubleshooting
# ==============================================================================

set -e

echo "🧪 Testing Observability Stack..."

# Function to check service health
check_service() {
    local service_name=$1
    local service_url=$2
    local expected_response=$3
    
    echo "🔍 Checking $service_name at $service_url..."
    
    if curl -s --max-time 10 "$service_url" | grep -q "$expected_response"; then
        echo "✅ $service_name is healthy"
        return 0
    else
        echo "❌ $service_name is not responding correctly"
        return 1
    fi
}

# Check all observability services
echo "📊 Verifying observability services..."

# Check Jaeger
check_service "Jaeger" "http://192.168.0.113:16686" "Jaeger UI"

# Check Prometheus  
check_service "Prometheus" "http://192.168.0.114:9090/-/healthy" "Prometheus"

# Check Grafana
# check_service "Grafana" "http://192.168.0.115:3000/api/health" "ok"

# Check OTEL Collector
echo "🔍 Checking OTEL Collector..."
kubectl get pods -n observability -l app.kubernetes.io/name=otel-collector-collector
if kubectl get pods -n observability -l app.kubernetes.io/name=otel-collector | grep -q "Running"; then
    echo "✅ OTEL Collector is running"
else
    echo "❌ OTEL Collector is not running"
fi

# Generate test traffic to todo-app
echo "🚀 Generating test traffic to create telemetry data..."

# Test frontend
echo "📱 Testing frontend..."
for i in {1..10}; do
    curl -s http://192.168.0.111/ > /dev/null || true
    sleep 1
done

# Test user service health endpoint
echo "👤 Testing user service..."
for i in {1..10}; do
    curl -s http://192.168.0.111/user-service/health > /dev/null || true
    sleep 1
done

# Test todo service health endpoint  
echo "📝 Testing todo service..."
for i in {1..10}; do
    curl -s http://192.168.0.111/todo-service/health > /dev/null || true
    sleep 1
done

# Test with some API calls that might generate traces
echo "🔗 Testing API endpoints..."
for i in {1..5}; do
    # Try to register a test user (will likely fail but generate traces)
    curl -s -X POST http://192.168.0.111/user-service/register \
        -H "Content-Type: application/json" \
        -d '{"username":"test'$i'","email":"test'$i'@example.com","password":"test123"}' > /dev/null || true
    
    # Try to login (will likely fail but generate traces)
    curl -s -X POST http://192.168.0.111/user-service/login \
        -H "Content-Type: application/json" \
        -d '{"username":"test'$i'","password":"test123"}' > /dev/null || true
    
    sleep 2
done

echo "⏳ Waiting 30 seconds for telemetry data to be processed..."
sleep 30

# Check for traces in Jaeger
echo "🔍 Checking for traces in Jaeger..."
JAEGER_TRACES=$(curl -s "http://192.168.0.113:16686/api/traces?service=frontend&limit=10" | jq '.data | length' 2>/dev/null || echo "0")
if [ "$JAEGER_TRACES" -gt 0 ]; then
    echo "✅ Found $JAEGER_TRACES traces in Jaeger"
else
    echo "⚠️  No traces found in Jaeger yet (this might be normal for new setup)"
fi

# Check OTEL Collector metrics
echo "🔍 Checking OTEL Collector metrics..."
if curl -s http://otel-collector.observability.svc.cluster.local:8889/metrics 2>/dev/null | grep -q "otelcol_receiver"; then
    echo "✅ OTEL Collector metrics are available"
else
    echo "⚠️  OTEL Collector metrics not found"
fi

# Check Prometheus targets
echo "🔍 Checking Prometheus targets..."
if curl -s "http://192.168.0.114:9090/api/v1/targets" | grep -q "otel-collector"; then
    echo "✅ OTEL Collector target is configured in Prometheus"
else
    echo "⚠️  OTEL Collector target not found in Prometheus"
fi

# Display pod status
echo ""
echo "📊 Current pod status in production namespace:"
kubectl get pods -n production -o wide

echo ""
echo "📊 Current pod status in observability namespace:"
kubectl get pods -n observability -o wide

echo ""
echo "✅ Observability Stack Testing Completed!"
echo ""
echo "🌟 OBSERVABILITY STACK SUMMARY:"
echo "═══════════════════════════════════════════════════════════════"
echo "🔍 Jaeger (Tracing):     http://192.168.0.113:16686"
echo "📊 Prometheus (Metrics): http://192.168.0.114:9090"  
echo "📈 Grafana (Dashboard):  http://192.168.0.115:3000 (admin/admin123)"
echo "🎯 OTEL Collector:       otel-collector.observability.svc.cluster.local:4317"
echo ""
echo "🚀 TODO-APP ENDPOINTS:"
echo "═══════════════════════════════════════════════════════════════"
echo "📱 Frontend:             http://192.168.0.111/"
echo "👤 User Service:         http://192.168.0.111/user-service/"
echo "📝 Todo Service:         http://192.168.0.111/todo-service/"
echo ""
echo "🎯 NEXT STEPS:"
echo "═══════════════════════════════════════════════════════════════"
echo "1. 🔗 Open Grafana and explore the pre-built dashboards"
echo "2. 📊 Check Prometheus targets and verify OTEL metrics"
echo "3. 🔍 Use Jaeger to view distributed traces from API calls"
echo "4. 🧪 Generate more traffic to see real-time observability data"
echo ""
echo "🎉 OBSERVABILITY STACK INSTALLATION COMPLETE!"