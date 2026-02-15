#!/bin/bash

# Deploy Production Applications via ArgoCD (Apps of Apps pattern)

echo "Enter your GitHub Personal Access Token:"
read -s GITHUB_PAT

kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret docker-registry github-registry-secret \
  --namespace=production \
  --docker-server=ghcr.io \
  --docker-username=KeremAR \
  --docker-password=$GITHUB_PAT

  kubectl create secret docker-registry github-registry-secret \
  --namespace=staging \
  --docker-server=ghcr.io \
  --docker-username=KeremAR \
  --docker-password=$GITHUB_PAT

git clone https://github.com/KeremAR/gitops-epam.git

kubectl apply -n argocd -f gitops-epam/argocd-manifests/root-application.yaml

echo "wait 10 seconds"
sleep 10
echo "Syncing ArgoCD Application..."

argocd app sync root-app
argocd app wait root-app --health --timeout 600

FILE="6A-1-install-prometheus.sh"
[ -f "$FILE" ] || curl -sO "https://raw.githubusercontent.com/KeremAR/proxmox-k3s/main/6_Observability-Stack/$FILE" && chmod +x "$FILE"

FILE="6A-2-install-loki.sh"
[ -f "$FILE" ] || curl -sO "https://raw.githubusercontent.com/KeremAR/proxmox-k3s/main/6_Observability-Stack/$FILE" && chmod +x "$FILE"

FILE="6A-3-install-grafana.sh"
[ -f "$FILE" ] || curl -sO "https://raw.githubusercontent.com/KeremAR/proxmox-k3s/main/6_Observability-Stack/$FILE" && chmod +x "$FILE"

FILE="6A-4-install-alloy.sh"
[ -f "$FILE" ] || curl -sO "https://raw.githubusercontent.com/KeremAR/proxmox-k3s/main/6_Observability-Stack/$FILE" && chmod +x "$FILE"

FILE="6A-5-install-jaeger.sh"
[ -f "$FILE" ] || curl -sO "https://raw.githubusercontent.com/KeremAR/proxmox-k3s/main/6_Observability-Stack/$FILE" && chmod +x "$FILE"

FILE="6D-create-memory-dashboard.sh"
[ -f "$FILE" ] || curl -sO "https://raw.githubusercontent.com/KeremAR/proxmox-k3s/main/6_Observability-Stack/$FILE" && chmod +x "$FILE"

FILE="6E-create-global-sre-overview-dashboard.sh"
[ -f "$FILE" ] || curl -sO "https://raw.githubusercontent.com/KeremAR/proxmox-k3s/main/6_Observability-Stack/$FILE" && chmod +x "$FILE"

FILE="6F-create-infrastructure-cluster-dashboard.sh"
[ -f "$FILE" ] || curl -sO "https://raw.githubusercontent.com/KeremAR/proxmox-k3s/main/6_Observability-Stack/$FILE" && chmod +x "$FILE"

FILE="6G-create-microservice-detail-dashboard.sh"
[ -f "$FILE" ] || curl -sO "https://raw.githubusercontent.com/KeremAR/proxmox-k3s/main/6_Observability-Stack/$FILE" && chmod +x "$FILE"

echo ""
echo "Deployment complete! Check ArgoCD UI:"
echo "http://argocd.192.168.0.111.nip.io"
