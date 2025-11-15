# Ingress Conflict Fix - Remove Nginx Traffic Routing from Rollouts

## 🔴 Problem

After migrating to service-based pattern, ArgoCD couldn't create `staging-frontend-ingress` because:

```
admission webhook "validate.nginx.ingress.kubernetes.io" denied the request: 
host "todo-app-staging.192.168.0.111.nip.io" and path "/" is already defined in ingress staging/staging-todo-app
```

**Existing Ingresses in staging namespace:**
```bash
kubectl get ingress -n staging
NAME                                   CLASS   HOSTS                                   AGE
staging-todo-app                       nginx   todo-app-staging.192.168.0.111.nip.io   17d  # ❌ Old umbrella chart
user-service-staging-todo-app-canary   nginx   todo-app-staging.192.168.0.111.nip.io   12d  # Argo Rollouts
todo-service-staging-todo-app-canary   nginx   todo-app-staging.192.168.0.111.nip.io   12d  # Argo Rollouts
frontend-staging-todo-app-canary       nginx   todo-app-staging.192.168.0.111.nip.io   12d  # Argo Rollouts
```

**Root Cause:**
- Old `staging-todo-app` Ingress (from umbrella chart) still exists
- Argo Rollouts was configured with `trafficRouting.nginx.stableIngress: staging-todo-app`
- This created 3 canary Ingresses (one per service)
- New `staging-frontend-ingress` conflicts with same host/path

---

## ✅ Solution: Remove Nginx Traffic Routing

**Why this is correct:**
1. **Frontend has Caddy reverse proxy** → Routes /users* to user-service:8001, /todos* to todo-service:8002
2. **Ingress only routes to frontend** → No need for Ingress-level canary routing
3. **Canary deployments still work** → Service-level canary (user-service + user-service-canary) handles it
4. **AnalysisTemplates still validate** → Health checks run on canary services before promotion

---

## 🔧 Changes Made

### 1. **Removed `trafficRouting.nginx` from all Rollout templates:**

**user-service/templates/deployment.yaml:**
```yaml
# ❌ REMOVED:
      trafficRouting:
        nginx:
          stableIngress: {{ .Values.canary.stableIngress }}
```

**todo-service/templates/deployment.yaml:**
```yaml
# ❌ REMOVED:
      trafficRouting:
        nginx:
          stableIngress: {{ .Values.canary.stableIngress }}
```

**frontend/templates/deployment.yaml:**
```yaml
# ❌ REMOVED:
      trafficRouting:
        nginx:
          stableIngress: {{ .Values.canary.stableIngress }}
```

### 2. **Removed `stableIngress` from values.yaml:**

**user-service/values.yaml:**
```yaml
canary:
  enabled: true
  steps: [...]
  analysisTemplateName: check-pod-readiness
  # stableIngress: staging-todo-app  # ❌ REMOVED
```

**todo-service/values.yaml:**
```yaml
canary:
  enabled: true
  steps: [...]
  analysisTemplateName: check-pod-readiness
  # stableIngress: staging-todo-app  # ❌ REMOVED
```

**frontend/values.yaml:**
```yaml
canary:
  enabled: true
  steps: [...]
  analysisTemplateName: check-frontend-readiness
  # stableIngress: staging-todo-app  # ❌ REMOVED
```

---

## 🚀 Deployment Steps

### 1. **Delete Old Ingresses:**
```bash
# Delete old umbrella chart Ingress
kubectl delete ingress staging-todo-app -n staging

# Delete old canary Ingresses (Argo Rollouts will recreate if needed, but won't because we removed trafficRouting)
kubectl delete ingress user-service-staging-todo-app-canary -n staging
kubectl delete ingress todo-service-staging-todo-app-canary -n staging
kubectl delete ingress frontend-staging-todo-app-canary -n staging
```

### 2. **Commit and Push Changes:**
```powershell
cd C:\Users\kerem\Documents\proxmox-k3s

git add helm-charts/
git commit -m "fix: Remove Nginx traffic routing from Rollouts

- Remove trafficRouting.nginx from all Rollout templates
- Remove stableIngress configuration from values.yaml
- Ingress-level canary routing not needed (Caddy handles backend routing)
- Service-level canary still works (stable + canary services)
- Fixes Ingress conflict: staging-frontend-ingress can now be created"

git push origin main
```

### 3. **Sync ArgoCD:**
```bash
# Sync all services (this will update Rollouts and create new Ingress)
argocd app sync staging-user-service
argocd app sync staging-todo-service
argocd app sync staging-frontend

# Wait for sync
argocd app wait staging-frontend --health
```

### 4. **Verify New Ingress:**
```bash
kubectl get ingress -n staging
# Expected: Only staging-frontend-ingress

kubectl describe ingress staging-frontend-ingress -n staging
# Should show: todo-app-staging.192.168.0.111.nip.io → frontend:3000
```

### 5. **Test Application:**
```bash
curl http://todo-app-staging.192.168.0.111.nip.io
# Should return frontend HTML

curl http://todo-app-staging.192.168.0.111.nip.io/users/health
# Should return user-service health (routed by Caddy)

curl http://todo-app-staging.192.168.0.111.nip.io/todos/health
# Should return todo-service health (routed by Caddy)
```

---

## 📊 Traffic Flow (After Fix)

### **Old Pattern (With Nginx Traffic Routing):**
```
Internet → Nginx Ingress (staging-todo-app) → [Canary Ingress Logic] → user-service/todo-service/frontend
                                                     ↓
                                        Creates 3 canary Ingresses
```

### **New Pattern (Without Nginx Traffic Routing):**
```
Internet → Nginx Ingress (staging-frontend-ingress) → frontend:3000 (Caddy)
                                                           ↓
                                          Caddy reverse proxy routes:
                                          - /users* → user-service:8001
                                          - /todos* → todo-service:8002
                                          - /* → Static files
```

**Canary Deployment Still Works:**
```
Rollout creates:
  - user-service (stable)     ← 80% traffic
  - user-service-canary       ← 20% traffic

Kubernetes Service-level routing handles canary split!
```

---

## ✅ Benefits

1. **No Ingress conflicts** → Only 1 Ingress (`staging-frontend-ingress`)
2. **Simpler architecture** → Caddy handles all routing
3. **Canary still works** → Service-level canary (not Ingress-level)
4. **Less K8s resources** → No canary Ingresses per service
5. **Easier to debug** → Single entry point, clear traffic flow

---

## 🎯 Verification Checklist

- [ ] Old `staging-todo-app` Ingress deleted
- [ ] Old canary Ingresses deleted (user-service-*, todo-service-*, frontend-*)
- [ ] New `staging-frontend-ingress` created successfully
- [ ] Ingress routes to `frontend:3000`
- [ ] Frontend Caddy routes to backend services correctly
- [ ] Canary deployments still trigger (setWeight: 20, 40, 60)
- [ ] AnalysisTemplates still run health checks
- [ ] Application accessible via `http://todo-app-staging.192.168.0.111.nip.io`

---

## 📝 Notes

**Why we don't need Ingress-level canary routing:**

1. **Backend services are not exposed via Ingress** → They're ClusterIP services
2. **Frontend is the only public entry point** → Caddy proxies to backends
3. **Service-level canary is sufficient** → Kubernetes handles traffic split between stable and canary services
4. **AnalysisTemplates validate health** → Health checks ensure canary is ready before promotion

**If we wanted Ingress-level canary (not recommended for this architecture):**
- Would need to expose user-service and todo-service via Ingress paths
- Would need `stableIngress: staging-frontend-ingress` in all Rollouts
- Would create 3 canary Ingresses again (defeating the purpose of single Ingress)
