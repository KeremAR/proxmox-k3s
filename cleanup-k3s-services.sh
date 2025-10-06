#!/bin/bash

# ==============================================================================
# Cleanup Script - Remove All Infrastructure Services
# ==============================================================================
# Purpose: Clean K3s cluster from all previously installed services
# Services: Nginx Ingress, ArgoCD, Custom LoadBalancers, etc.
# ==============================================================================

set -e

echo "🧹 Cleaning K3s cluster from all infrastructure services..."

# Function to safely delete namespace
delete_namespace() {
    local ns=$1
    if kubectl get namespace "$ns" >/dev/null 2>&1; then
        echo "🗑️ Deleting namespace: $ns"
        kubectl delete namespace "$ns" --timeout=60s || true
        
        # Force cleanup if stuck
        kubectl get namespace "$ns" -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - || true
    else
        echo "✅ Namespace $ns already deleted"
    fi
}

# Function to delete custom services
delete_custom_services() {
    echo "🗑️ Deleting custom LoadBalancer services..."
    
    # Delete nginx ingress loadbalancer if exists
    kubectl delete service nginx-ingress-loadbalancer -n ingress-nginx --ignore-not-found=true
    
    # Delete argocd loadbalancer if exists  
    kubectl delete service argocd-loadbalancer -n argocd --ignore-not-found=true
    
    # Delete any custom yaml files applied
    if [ -f "nginx-ingress-loadbalancer.yaml" ]; then
        kubectl delete -f nginx-ingress-loadbalancer.yaml --ignore-not-found=true
    fi
    
    if [ -f "argocd-loadbalancer.yaml" ]; then
        kubectl delete -f argocd-loadbalancer.yaml --ignore-not-found=true
    fi
}

echo "🔍 Current namespaces:"
kubectl get namespaces

echo ""
echo "🗑️ Starting cleanup process..."

# Delete custom services first
delete_custom_services

# Delete ArgoCD namespace
delete_namespace "argocd"

# Delete Nginx Ingress namespace  
delete_namespace "ingress-nginx"

# Delete any other custom namespaces (but keep system ones)
for ns in $(kubectl get namespaces -o name | grep -v "kube-\|default\|cattle-\|local"); do
    namespace_name=$(echo $ns | cut -d'/' -f2)
    if [[ "$namespace_name" != "default" && "$namespace_name" != "kube-system" && "$namespace_name" != "kube-public" && "$namespace_name" != "kube-node-lease" ]]; then
        delete_namespace "$namespace_name"
    fi
done

# Wait for cleanup to complete
echo "⏳ Waiting for cleanup to complete..."
sleep 10

# Check final state
echo ""
echo "✅ Cleanup completed!"
echo "📋 Remaining namespaces:"
kubectl get namespaces

echo ""
echo "📋 Remaining services (should only show system services):"
kubectl get services --all-namespaces

echo ""
echo "🎯 K3s cluster is now clean and ready for fresh installation!"
echo "🚀 Next step: Run the scripts in 4_CloudNative-Infrastructure/"
echo "   1. ./4A-install-nginx-ingress.sh"
echo "   2. ./4B-install-argocd.sh" 