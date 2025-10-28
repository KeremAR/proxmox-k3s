#!/bin/bash

# ============================================
# Jenkins Destruction Script
# ============================================
# This script removes all Kubernetes resources created by the 7B-jenkins.sh script.
# Usage: ./destroy-jenkins.sh [namespace]
# Default namespace is 'jenkins'.
# ============================================

set -e # Exit immediately if a command exits with a non-zero status.

# Namespace can be overridden by the first argument
NAMESPACE=${1:-jenkins}

echo "--- Starting Jenkins Destruction for namespace: $NAMESPACE ---"
echo ""

# Step 1: Uninstall the Jenkins Helm release
# This removes deployments, services, and other namespaced resources managed by Helm.
echo "Step 1: Uninstalling Jenkins Helm release..."
if helm status jenkins -n "$NAMESPACE" &> /dev/null; then
    helm uninstall jenkins --namespace "$NAMESPACE"
    echo "✅ Jenkins Helm release uninstalled from namespace '$NAMESPACE'."
else
    echo "ℹ️ Jenkins Helm release not found in namespace '$NAMESPACE', skipping."
fi
echo ""

# Step 2: Delete the ClusterRoleBinding
# This is a cluster-scoped resource and is not removed by deleting the namespace.
CRB_NAME="jenkins-cluster-admin-binding-$NAMESPACE"
echo "Step 2: Deleting Jenkins ClusterRoleBinding '$CRB_NAME'..."
if kubectl get clusterrolebinding "$CRB_NAME" &> /dev/null; then
    kubectl delete clusterrolebinding "$CRB_NAME"
    echo "✅ ClusterRoleBinding '$CRB_NAME' deleted."
else
    echo "ℹ️ ClusterRoleBinding '$CRB_NAME' not found, skipping."
fi
echo ""

# Step 3: Delete the Jenkins namespace
# This removes all remaining resources within the namespace (PVCs, Secrets, ServiceAccount).
echo "Step 3: Deleting '$NAMESPACE' namespace..."
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    kubectl delete namespace "$NAMESPACE"
    echo "✅ '$NAMESPACE' namespace deleted."
    echo "Waiting for namespace to be fully terminated..."
    kubectl wait --for=delete namespace/"$NAMESPACE" --timeout=2m || echo "⚠️ Namespace '$NAMESPACE' did not terminate within 2 minutes. It might be stuck."
else
    echo "ℹ️ '$NAMESPACE' namespace not found, skipping."
fi
echo ""


echo "--- Jenkins Destruction Complete for namespace: $NAMESPACE ---"
