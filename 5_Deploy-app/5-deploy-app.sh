#!/bin/bash

# Deploy Production Applications via ArgoCD (Apps of Apps pattern)

echo "Enter your GitHub Personal Access Token:"
read -s GITHUB_PAT

kubectl create secret docker-registry github-registry-secret \
  --namespace=production \
  --docker-server=ghcr.io \
  --docker-username=KeremAR \
  --docker-password=$GITHUB_PAT

git clone https://github.com/KeremAR/gitops-epam.git

kubectl apply -n production -f gitops-epam/argocd-manifests/root-application.yaml

FILE="6A-install-alloy-observability.sh"
[ -f "$FILE" ] || curl -sO "https://raw.githubusercontent.com/KeremAR/proxmox-k3s/main/6_Observability-Stack/$FILE" && chmod +x "$FILE"

FILE="6B-create-production-dashboard.sh"
[ -f "$FILE" ] || curl -sO "https://raw.githubusercontent.com/KeremAR/proxmox-k3s/main/6_Observability-Stack/$FILE" && chmod +x "$FILE"


echo ""
echo "Deployment complete! Check ArgoCD UI:"
echo "http://argocd.192.168.0.111.nip.io"