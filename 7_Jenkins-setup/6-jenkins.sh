#!/bin/bash

echo "=== Setting up Jenkins Application Secrets ==="
echo ""
# Create Jenkins namespace if not exists
kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -
# Create Jenkins application secrets


kubectl create secret generic jenkins-app-secrets \
  --from-literal=sonar-token='SENIN_SONARQUBE_TOKENIN' \
  --from-literal=github-username='SENIN_GITHUB_KULLANICI_ADIN' \
  --from-literal=github-token='SENIN_GITHUB_TOKENIN_ (repo, packages scope)' \
  --from-literal=docker-config-json='SENIN_DOCKER_CONFIG_JSON_BASE64_HALI' \
  --from-literal=argocd-user='SENIN_ARGOCD_KULLANICI_ADIN' \
  --from-literal=argocd-pass='SENIN_ARGOCD_SIFREN' \
  -n jenkins


echo "✅ Jenkins application secrets created in 'jenkins' namespace."
echo ""
echo "=== You can now proceed to install Jenkins using Helm with the provided 'jenkins-values
