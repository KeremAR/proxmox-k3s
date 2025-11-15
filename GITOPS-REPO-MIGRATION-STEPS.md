# GitOps Repository Migration Steps

## ⚠️ IMPORTANT: Manual GitOps Repo Update Required

The Jenkins pipeline is looking for the new service-based Application files in your GitOps repository, but they don't exist yet. You need to manually update your `gitops-epam` repository.

## 🔄 Migration Steps for GitOps Repo

### Step 1: Backup Current State
```bash
cd /path/to/gitops-epam
git checkout main
git pull origin main

# Create backup branch
git checkout -b backup-umbrella-pattern
git push origin backup-umbrella-pattern
git checkout main
```

### Step 2: Remove Old Files
```bash
# Delete old umbrella pattern files
rm argocd-manifests/environments/staging.yaml
rm argocd-manifests/environments/production.yaml
```

### Step 3: Create New Directory Structure
```bash
# Create service-based directories
mkdir -p argocd-manifests/environments/staging
mkdir -p argocd-manifests/environments/production
```

### Step 4: Copy Template Files
Copy the following files from `proxmox-k3s/gitops-copy/` to your `gitops-epam` repo:

**Staging Applications:**
- `argocd-manifests/environments/staging/staging-user-service.yaml`
- `argocd-manifests/environments/staging/staging-todo-service.yaml`
- `argocd-manifests/environments/staging/staging-frontend.yaml`

**Production Applications:**
- `argocd-manifests/environments/production/production-user-service.yaml`
- `argocd-manifests/environments/production/production-todo-service.yaml`
- `argocd-manifests/environments/production/production-frontend.yaml`

**Root Application:**
- `argocd-manifests/root-application.yaml` (update existing)

### Step 5: Update root-application.yaml

Replace the content of `argocd-manifests/root-application.yaml` with:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: 'https://github.com/KeremAR/gitops-epam'
    path: argocd-manifests/environments
    targetRevision: HEAD
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Step 6: Commit and Push
```bash
cd /path/to/gitops-epam

git add argocd-manifests/
git status  # Verify changes

git commit -m "refactor: Migrate to service-based App of Apps pattern

- Remove umbrella pattern files (staging.yaml, production.yaml)
- Add service-based Application manifests per environment
- Update root-application.yaml with directory generator
- Enable independent service deployments and rollbacks"

git push origin main
```

### Step 7: Delete Old ArgoCD Applications (Optional)
If old apps still exist in ArgoCD, delete them:

```bash
# Login to ArgoCD
argocd login argocd.192.168.0.111.nip.io --username admin --password <password> --insecure --grpc-web

# Delete old umbrella apps (if they exist)
argocd app delete staging-todo-app --cascade
argocd app delete production-todo-app --cascade

# Sync root app to create new service apps
argocd app sync root-app

# Verify new apps are created
argocd app list | grep staging
# Should show:
# - staging-frontend
# - staging-user-service
# - staging-todo-service
```

## 🎯 Quick Copy-Paste Commands

```bash
# In your local workspace
cd /path/to/gitops-epam

# Remove old files
rm argocd-manifests/environments/staging.yaml
rm argocd-manifests/environments/production.yaml

# Create directories
mkdir -p argocd-manifests/environments/staging
mkdir -p argocd-manifests/environments/production

# Copy files from proxmox-k3s template
cp /path/to/proxmox-k3s/gitops-copy/argocd-manifests/environments/staging/*.yaml \
   argocd-manifests/environments/staging/

cp /path/to/proxmox-k3s/gitops-copy/argocd-manifests/environments/production/*.yaml \
   argocd-manifests/environments/production/

cp /path/to/proxmox-k3s/gitops-copy/argocd-manifests/root-application.yaml \
   argocd-manifests/root-application.yaml

# Commit and push
git add argocd-manifests/
git commit -m "refactor: Migrate to service-based App of Apps pattern"
git push origin main
```

## 🔍 Verification Checklist

After pushing to GitOps repo:

- [ ] Old files deleted: `staging.yaml`, `production.yaml`
- [ ] New directories exist: `staging/`, `production/`
- [ ] 6 service Application files created (3 staging + 3 production)
- [ ] `root-application.yaml` has `directory.recurse: true`
- [ ] Changes committed and pushed to main branch
- [ ] ArgoCD root-app synced successfully
- [ ] New service apps visible in ArgoCD UI

## 📊 Expected ArgoCD App Structure After Migration

```
root-app (watches argocd-manifests/environments/)
├── staging-frontend
├── staging-user-service
├── staging-todo-service
├── production-frontend
├── production-user-service
└── production-todo-service
```

## 🚨 Troubleshooting

### Issue: "staging-user-service not found"
**Solution:** GitOps repo not updated yet. Complete steps above.

### Issue: "permission denied"
**Solution:** Ensure ArgoCD has correct repository credentials and the files exist in the repo.

### Issue: Old apps still showing
**Solution:** Delete old apps manually with `argocd app delete` and sync root-app.

---

**Next Action:** Follow the steps above to update your `gitops-epam` repository, then re-run the Jenkins pipeline.
