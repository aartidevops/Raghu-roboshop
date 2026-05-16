#!/bin/bash
# build.sh
set -euo pipefail

CLUSTER_NAME="roboshop-dev-aks"
RG="rg-roboshop-dev"

echo "=== Step 1: Building infra ==="
cd infra/
terraform apply -var-file=terraform.tfvars -auto-approve

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
bash push-secrets.sh

echo ""
echo "=== Step 7: Applying ArgoCD applications ==="
kubectl apply -f ~/Documents/Devops/roboshop-gitops/argocd-apps/
echo "ArgoCD apps registered"

echo ""
echo "=== Step 8: Waiting for MySQL (deployed by platform Terraform) ==="
# MySQL is created by platform/main.tf — just wait for it to be ready
kubectl rollout status deployment/mysql -n roboshop-dev --timeout=300s

echo ""
echo "=== Step 9: Loading MySQL master data ==="
bash load-mysql-data.sh

# roboshop-sa is created by platform Terraform — no manual step needed

NGINX_IP=$(kubectl get svc ingress-nginx-controller \
  -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  BUILD COMPLETE                          ║"
echo "╠══════════════════════════════════════════╣"
echo "  Nginx IP : $NGINX_IP"
echo "  Update DNS to point to this IP!"
echo "  ArgoCD   : https://argocd.skilltechnology.online"
echo "  Vault    : https://vault.skilltechnology.online"
echo "╚══════════════════════════════════════════╝"
