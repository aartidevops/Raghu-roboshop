#!/bin/bash
# build.sh — run every morning to rebuild everything
set -euo pipefail

CLUSTER_NAME="roboshop-dev-aks"
RG="rg-roboshop-dev"

echo "=== Step 1: Building infra (AKS + databases) ==="
cd infra/
terraform apply -var-file=terraform.tfvars -auto-approve
# Note: null_resource vault_secrets will WAIT for vault
# and fail if vault isn't running yet
# That's ok — we handle this in step 4

echo ""
echo "=== Step 2: Getting kubeconfig ==="
az aks get-credentials \
  --name $CLUSTER_NAME \
  --resource-group $RG \
  --overwrite-existing

echo ""
echo "=== Step 3: Waiting for nodes ==="
kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo ""
echo "=== Step 4: Building platform tools ==="
cd ../platform/
terraform apply -var-file=terraform.tfvars -auto-approve

echo ""
echo "=== Step 5: Init and unseal Vault ==="
cd ..
bash vault-init.sh

echo ""
echo "=== Step 6: Push DB secrets to Vault ==="
# Now that vault is running, push the secrets
# null_resource in infra will be re-triggered
cd infra/
terraform apply -var-file=terraform.tfvars -auto-approve
# This time vault is ready so the null_resource succeeds

echo ""
echo "=== Step 7: Verify secrets in Vault ==="
kubectl exec -n vault vault-0 -- vault kv get secret/roboshop/dev/mongodb
kubectl exec -n vault vault-0 -- vault kv get secret/roboshop/dev/redis

echo ""
NGINX_IP=$(kubectl get svc ingress-nginx-controller \
  -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "╔══════════════════════════════════════════╗"
echo "║  BUILD COMPLETE                          ║"
echo "╠══════════════════════════════════════════╣"
echo "  Nginx IP:  $NGINX_IP"
echo "  ArgoCD:    https://argocd.skilltechnology.online"
echo "  Vault:     https://vault.skilltechnology.online"
echo "╚══════════════════════════════════════════╝"