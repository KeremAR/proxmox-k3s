#!/bin/bash

# ==============================================================================
# 5E - Enable Auto-Instrumentation for Todo-App
# ==============================================================================
# Purpose: Zero-code instrumentation activation for existing applications
# Components: Patch deployments with instrumentation annotations
# ==============================================================================

set -e

echo "🎯 Enabling auto-instrumentation for todo-app..."

# Patch frontend deployment with Node.js instrumentation
echo "🟢 Adding Node.js auto-instrumentation to frontend..."
kubectl patch deployment frontend -n production -p '{
  "spec": {
    "template": {
      "metadata": {
        "annotations": {
          "instrumentation.opentelemetry.io/inject-nodejs": "production/nodejs-instrumentation"
        }
      }
    }
  }
}'

# Patch user-service deployment with Python instrumentation  
echo "🐍 Adding Python auto-instrumentation to user-service..."
kubectl patch deployment user-service -n production -p '{
  "spec": {
    "template": {
      "metadata": {
        "annotations": {
          "instrumentation.opentelemetry.io/inject-python": "production/python-instrumentation"
        }
      }
    }
  }
}'

# Patch todo-service deployment with Python instrumentation
echo "🐍 Adding Python auto-instrumentation to todo-service..."
kubectl patch deployment todo-service -n production -p '{
  "spec": {
    "template": {
      "metadata": {
        "annotations": {
          "instrumentation.opentelemetry.io/inject-python": "production/python-instrumentation"
        }
      }
    }
  }
}'

# Wait for rollouts to complete
echo "⏳ Waiting for deployments to rollout with instrumentation..."
kubectl rollout status deployment/frontend -n production --timeout=300s
kubectl rollout status deployment/user-service -n production --timeout=300s  
kubectl rollout status deployment/todo-service -n production --timeout=300s

# Verify pods are running with OTEL sidecars
echo "🔍 Verifying instrumentation is active..."
sleep 30

echo ""
echo "📊 Checking frontend pod for OTEL environment variables..."
FRONTEND_POD=$(kubectl get pods -n production -l app=frontend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n production $FRONTEND_POD -- env | grep OTEL || echo "⚠️  OTEL env vars not found"

echo ""  
echo "📊 Checking user-service pod for OTEL environment variables..."
USER_POD=$(kubectl get pods -n production -l app=user-service -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n production $USER_POD -- env | grep OTEL || echo "⚠️  OTEL env vars not found"

echo ""
echo "📊 Checking todo-service pod for OTEL environment variables..."
TODO_POD=$(kubectl get pods -n production -l app=todo-service -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n production $TODO_POD -- env | grep OTEL || echo "⚠️  OTEL env vars not found"

echo ""
echo "✅ Auto-instrumentation activation completed!"
echo ""
echo "🎯 Testing endpoints to generate telemetry data..."
echo "📱 Frontend: http://192.168.0.111/"
echo "👤 User Service Health: http://192.168.0.111/user-service/health"  
echo "📝 Todo Service Health: http://192.168.0.111/todo-service/health"
echo ""
echo "🔍 View telemetry data:"
echo "📊 Jaeger Traces: http://192.168.0.113:16686"
echo "📈 Prometheus Metrics: http://192.168.0.114:9090"
echo "📝 Grafana Dashboard: http://192.168.0.115:3000"
echo ""
echo "🎯 Next Step: Run 5F-create-grafana-dashboards.sh to create observability dashboards"