# StatefulSet ve Ingress Migration - Service-Based Pattern

## 📋 Yapılan Değişiklikler

### 1. **User-Service Chart**
#### Yeni Dosyalar:
- ✅ `helm-charts/user-service/values-staging.yaml` - Staging environment configuration
- ✅ `helm-charts/user-service/values-prod.yaml` - Production environment configuration
- ✅ `helm-charts/user-service/templates/database-statefulset.yaml` - PostgreSQL StatefulSet
- ✅ `helm-charts/user-service/templates/database-service.yaml` - PostgreSQL Headless Service

#### Güncellenen Dosyalar:
- ✅ `helm-charts/user-service/values.yaml` - Database configuration eklendi

**Database Configuration:**
```yaml
database:
  enabled: true
  name: user-db
  image:
    repository: postgres
    tag: "15-alpine"
  env:
    database: userdb
    username: userservice
    password: userpass
  storage: 1Gi  # Staging: 2Gi, Production: 10Gi
```

---

### 2. **Todo-Service Chart**
#### Yeni Dosyalar:
- ✅ `helm-charts/todo-service/values-staging.yaml` - Staging environment configuration
- ✅ `helm-charts/todo-service/values-prod.yaml` - Production environment configuration
- ✅ `helm-charts/todo-service/templates/database-statefulset.yaml` - PostgreSQL StatefulSet
- ✅ `helm-charts/todo-service/templates/database-service.yaml` - PostgreSQL Headless Service

#### Güncellenen Dosyalar:
- ✅ `helm-charts/todo-service/values.yaml` - Database configuration eklendi

**Database Configuration:**
```yaml
database:
  enabled: true
  name: todo-db
  image:
    repository: postgres
    tag: "15-alpine"
  env:
    database: tododb
    username: todoservice
    password: todopass
  storage: 1Gi  # Staging: 2Gi, Production: 10Gi
```

---

### 3. **Frontend Chart**
#### Yeni Dosyalar:
- ✅ `helm-charts/frontend/values-staging.yaml` - Staging environment configuration (including ingress host)
- ✅ `helm-charts/frontend/values-prod.yaml` - Production environment configuration (including ingress host)
- ✅ `helm-charts/frontend/templates/ingress.yaml` - Nginx Ingress resource

#### Güncellenen Dosyalar:
- ✅ `helm-charts/frontend/values.yaml` - Ingress configuration eklendi

**Ingress Configuration:**
```yaml
ingress:
  enabled: true
  className: nginx
  host: todo-app.local  # Overridden by environment values
  annotations:
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS"
```

**Staging:** `todo-app-staging.192.168.0.111.nip.io`
**Production:** `todo-app.192.168.0.111.nip.io`

---

### 4. **GitOps Manifests (gitops-copy/)**
#### Güncellenen Dosyalar:
- ✅ `staging-user-service.yaml` - valueFiles'a `values-staging.yaml` eklendi
- ✅ `staging-todo-service.yaml` - valueFiles'a `values-staging.yaml` eklendi
- ✅ `staging-frontend.yaml` - valueFiles'a `values-staging.yaml` eklendi
- ✅ `production-user-service.yaml` - valueFiles'a `values-prod.yaml` eklendi
- ✅ `production-todo-service.yaml` - valueFiles'a `values-prod.yaml` eklendi
- ✅ `production-frontend.yaml` - valueFiles'a `values-prod.yaml` eklendi

**Önceki Yapı (❌ Kaldırıldı):**
```yaml
helm:
  valueFiles:
    - values.yaml
  parameters:
    - name: deployment.replicas
      value: '1'
    - name: resources.requests.cpu
      value: '100m'
    # ... many parameters
```

**Yeni Yapı (✅ Daha Temiz):**
```yaml
helm:
  valueFiles:
    - values.yaml
    - values-staging.yaml  # or values-prod.yaml
  parameters:
    - name: image.tag
      value: 'latest'  # Only managed by CI/CD
```

---

## 🎯 Mikroservis Mimarisi: Her Servis Kendi Kaynağını Yönetir

### **Eski Umbrella Chart Yapısı:**
```
helm-charts/todo-app/
  ├── templates/
  │   ├── ingress.yaml                  # ❌ Tüm servisleri expose ediyordu
  │   ├── user-db-statefulset.yaml      # ❌ Merkezi database
  │   ├── todo-db-statefulset.yaml      # ❌ Merkezi database
  │   ├── user-service-deployment.yaml
  │   └── todo-service-deployment.yaml
  └── values.yaml
```

**Problem:** Bir servisin database'inde değişiklik yapmak için tüm umbrella chart'ı redeploy etmek gerekiyordu!

### **Yeni Service-Based Yapısı:**
```
helm-charts/
  ├── user-service/
  │   ├── templates/
  │   │   ├── deployment.yaml
  │   │   ├── service.yaml
  │   │   ├── database-statefulset.yaml  # ✅ User-service kendi DB'sini yönetir
  │   │   └── database-service.yaml
  │   ├── values.yaml
  │   ├── values-staging.yaml
  │   └── values-prod.yaml
  │
  ├── todo-service/
  │   ├── templates/
  │   │   ├── deployment.yaml
  │   │   ├── service.yaml
  │   │   ├── database-statefulset.yaml  # ✅ Todo-service kendi DB'sini yönetir
  │   │   └── database-service.yaml
  │   ├── values.yaml
  │   ├── values-staging.yaml
  │   └── values-prod.yaml
  │
  └── frontend/
      ├── templates/
      │   ├── deployment.yaml
      │   ├── service.yaml
      │   └── ingress.yaml               # ✅ Frontend dış dünyaya açılır
      ├── values.yaml
      ├── values-staging.yaml
      └── values-prod.yaml
```

**Avantaj:** Her servis tamamen bağımsız! `user-service` database'inde değişiklik yaparsan sadece `user-service` redeploy olur.

---

## 🚀 GitOps Repo'ya Manuel Deploy Edilmesi Gereken Değişiklikler

**Önemli:** `gitops-copy/` klasöründeki değişiklikleri **gitops-epam** repo'suna manuel olarak kopyalaman gerekiyor!

```bash
# 1. GitOps repo'yu clone et
git clone https://github.com/KeremAR/gitops-epam.git
cd gitops-epam

# 2. Application manifest'leri güncelle
cp ../proxmox-k3s/gitops-copy/argocd-manifests/environments/staging/*.yaml \
   argocd-manifests/environments/staging/

cp ../proxmox-k3s/gitops-copy/argocd-manifests/environments/production/*.yaml \
   argocd-manifests/environments/production/

# 3. Commit ve push
git add argocd-manifests/
git commit -m "feat: Add environment-specific values files to service charts"
git push origin main

# 4. ArgoCD root-app'i sync et
argocd app sync root-app

# 5. Tüm service app'leri sync et
argocd app sync staging-user-service
argocd app sync staging-todo-service
argocd app sync staging-frontend
```

---

## 📊 Environment-Specific Values Dosyası Kullanımı

### **Staging Environment:**
```yaml
# helm-charts/user-service/values-staging.yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "250m"
    memory: "256Mi"

database:
  storage: 2Gi
  resources:
    requests:
      memory: "256Mi"
      cpu: "100m"
```

### **Production Environment:**
```yaml
# helm-charts/user-service/values-prod.yaml
resources:
  requests:
    cpu: "250m"      # 2.5x daha fazla
    memory: "256Mi"  # 2x daha fazla
  limits:
    cpu: "1000m"     # 4x daha fazla
    memory: "1Gi"    # 4x daha fazla

database:
  storage: 10Gi      # 5x daha fazla
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
```

**Avantaj:** Environment-specific ayarlar artık ArgoCD manifest'lerinde değil, Helm chart'ında!

---

## 🔄 Ingress Kullanımı

### **Önceki Yapı (Eski Umbrella Chart):**
```yaml
# helm-charts/todo-app/values-staging.yaml
ingress:
  host: todo-app-staging.192.168.0.111.nip.io

# helm-charts/todo-app/templates/ingress.yaml
rules:
  - host: {{ .Values.ingress.host }}
    http:
      paths:
        - path: /
          service: frontend
          port: 3000
        - path: /register
          service: user-service
          port: 8001
        - path: /todos*
          service: todo-service
          port: 8002
```

### **Yeni Yapı (Frontend Chart):**
```yaml
# helm-charts/frontend/values-staging.yaml
ingress:
  host: todo-app-staging.192.168.0.111.nip.io

# helm-charts/frontend/templates/ingress.yaml
rules:
  - host: {{ .Values.ingress.host }}
    http:
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: frontend
              port:
                number: 3000
```

**Not:** Backend servislere routing artık **Caddy** tarafından yapılıyor (frontend container'ında)!

---

## ✅ Test Checklist

### 1. **Application Repo (proxmox-k3s) Commit:**
```bash
cd proxmox-k3s
git add helm-charts/
git add gitops-copy/
git commit -m "feat: Migrate StatefulSets and Ingress to service-based charts

- Add database StatefulSet to user-service and todo-service
- Add Ingress to frontend chart
- Create environment-specific values files (values-staging.yaml, values-prod.yaml)
- Update GitOps manifests to use environment-specific values
- Each service now manages its own database independently"
git push origin main
```

### 2. **GitOps Repo (gitops-epam) Update:**
```bash
cd gitops-epam
# Copy updated manifests
git add argocd-manifests/environments/
git commit -m "feat: Use environment-specific Helm values files"
git push origin main
```

### 3. **ArgoCD Sync:**
```bash
# Sync root-app (will discover updated manifests)
argocd app sync root-app

# Wait for all apps to sync
argocd app wait staging-user-service --health
argocd app wait staging-todo-service --health
argocd app wait staging-frontend --health
```

### 4. **Verify Resources:**
```bash
# Check databases are running
kubectl get statefulsets -n staging
# Expected: user-db, todo-db

kubectl get pvc -n staging
# Expected: postgres-storage-user-db-0, postgres-storage-todo-db-0

# Check ingress
kubectl get ingress -n staging
# Expected: staging-frontend-ingress

# Test ingress
curl http://todo-app-staging.192.168.0.111.nip.io
# Expected: Frontend HTML response
```

---

## 🎯 Sonuç

### Önceki Durum:
- ❌ Ingress ve StatefulSet'ler eski umbrella chart'ta kalmıştı
- ❌ Environment-specific ayarlar ArgoCD manifest'lerinde yönetiliyordu (çok parametreli)
- ❌ Her servis bağımsız değildi

### Şu Anki Durum:
- ✅ Her servis kendi database'ini yönetiyor (user-service → user-db, todo-service → todo-db)
- ✅ Frontend kendi Ingress'ini yönetiyor
- ✅ Environment-specific ayarlar Helm chart'larında (`values-staging.yaml`, `values-prod.yaml`)
- ✅ ArgoCD manifest'leri minimal (sadece image.tag parametresi)
- ✅ Tam mikroservis mimarisi: Her servis tamamen bağımsız deploy edilebilir!

**Önemli Not:** Bu değişikliklerden sonra ilk deployment'ta database'ler sıfırdan oluşturulacak (PVC creation). Eğer mevcut data'yı migrate etmek istersen, önce database dump alman gerekir!
