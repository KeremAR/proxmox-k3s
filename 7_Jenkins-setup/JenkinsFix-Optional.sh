
# ============================================
# Step 2: Create PVC Cleaner Pod
# ============================================

echo "Step 2: Creating PVC cleaner pod..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pvc-cleaner
  namespace: jenkins
spec:
  containers:
  - name: cleaner
    image: busybox
    command: ["sh", "-c", "rm -rf /jenkins-home/plugins/* && echo 'Plugins cleaned' && sleep 3600"]
    volumeMounts:
    - name: jenkins-home
      mountPath: /jenkins-home
  volumes:
  - name: jenkins-home
    persistentVolumeClaim:
      claimName: jenkins
EOF

echo "✅ PVC cleaner pod created"
echo ""

# ============================================
# Step 3: Wait for Cleanup
# ============================================

echo "Step 3: Waiting for cleanup to complete..."
echo ""

# Wait for pod to be running
kubectl wait --for=condition=ready pod/pvc-cleaner -n jenkins --timeout=60s 2>/dev/null || true

# Wait a bit for cleanup to finish
sleep 5

# Check logs
echo "Cleanup logs:"
kubectl logs -n jenkins pvc-cleaner 2>/dev/null || echo "⚠️  Could not retrieve logs"
echo ""

# ============================================
# Step 4: Delete Cleaner Pod
# ============================================

echo "Step 4: Removing cleaner pod..."

kubectl delete pod pvc-cleaner -n jenkins --force --grace-period=0 2>/dev/null || true

echo "✅ Cleaner pod removed"
echo ""

# ============================================
# Step 5: Restart Jenkins Pod
# ============================================

echo "Step 5: Restarting Jenkins pod..."

kubectl delete pod jenkins-0 -n jenkins

echo "✅ Jenkins pod deleted, Kubernetes will recreate it"
echo ""

# ============================================
# Step 6: Wait for Jenkins to Start
# ============================================

echo "Step 6: Waiting for Jenkins to start..."
echo ""

# Wait for new pod to be created
sleep 10

echo "Current pods in jenkins namespace:"
kubectl get pods -n jenkins
echo ""

echo "✅ Jenkins restart initiated"
echo ""

# ============================================
# Final Instructions
# ============================================

echo "=== Next Steps ==="
echo ""
echo "Monitor Jenkins startup:"
echo "  kubectl get pods -n jenkins -w"
echo ""
echo "Check Jenkins logs:"
echo "  kubectl logs -n jenkins jenkins-0 -c jenkins -f"
echo ""
echo "Get Jenkins URL:"
INGRESS_IP=$(kubectl get service nginx-ingress-loadbalancer -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
if [ -n "$INGRESS_IP" ]; then
    echo "  http://jenkins.${INGRESS_IP}.nip.io"
fi
echo ""
echo "✅ Done!"
