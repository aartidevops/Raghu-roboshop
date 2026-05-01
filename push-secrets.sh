#!/bin/bash
# push-secrets.sh
# Pushes database connection strings from Terraform outputs into Vault
# Run AFTER vault-init.sh completes successfully
set -euo pipefail

echo "=== Reading database values from Terraform ==="
cd infra/

COSMOS_NAME=$(terraform output -raw cosmos_account_name)
COSMOS_KEY=$(terraform output -raw cosmos_primary_key)
REDIS_DEV_HOST=$(terraform output -raw redis_dev_host)
REDIS_DEV_PASS=$(terraform output -raw redis_dev_password)
REDIS_UAT_HOST=$(terraform output -raw redis_uat_host)
REDIS_UAT_PASS=$(terraform output -raw redis_uat_password)

cd ..

echo "Cosmos account : $COSMOS_NAME"
echo "Redis dev host : $REDIS_DEV_HOST"
echo "Redis uat host : $REDIS_UAT_HOST"
echo ""

echo "=== Logging in to Vault ==="
ROOT_TOKEN=$(cat /tmp/vault-root-token.txt)
kubectl exec -n vault vault-0 -- vault login "$ROOT_TOKEN" > /dev/null
echo "Logged in"

echo ""
echo "=== Writing dev secrets ==="

kubectl exec -n vault vault-0 -- vault kv put secret/roboshop/dev/mongodb \
  uri="mongodb://${COSMOS_NAME}:${COSMOS_KEY}@${COSMOS_NAME}.mongo.cosmos.azure.com:10255/roboshop-dev?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@${COSMOS_NAME}@"

echo "MongoDB dev — done"

kubectl exec -n vault vault-0 -- vault kv put secret/roboshop/dev/redis \
  host="${REDIS_DEV_HOST}" \
  port="6380" \
  password="${REDIS_DEV_PASS}"

echo "Redis dev — done"

echo ""
echo "=== Writing uat secrets ==="

kubectl exec -n vault vault-0 -- vault kv put secret/roboshop/uat/mongodb \
  uri="mongodb://${COSMOS_NAME}:${COSMOS_KEY}@${COSMOS_NAME}.mongo.cosmos.azure.com:10255/roboshop-uat?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@${COSMOS_NAME}@"

echo "MongoDB uat — done"

kubectl exec -n vault vault-0 -- vault kv put secret/roboshop/uat/redis \
  host="${REDIS_UAT_HOST}" \
  port="6380" \
  password="${REDIS_UAT_PASS}"

echo "Redis uat — done"

echo ""
echo "=== Writing prod secrets ==="

kubectl exec -n vault vault-0 -- vault kv put secret/roboshop/prod/mongodb \
  uri="mongodb://${COSMOS_NAME}:${COSMOS_KEY}@${COSMOS_NAME}.mongo.cosmos.azure.com:10255/roboshop-prod?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@${COSMOS_NAME}@"

echo "MongoDB prod — done"

echo ""
echo "=== Verifying secrets ==="
kubectl exec -n vault vault-0 -- vault kv list secret/roboshop/dev/

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  All secrets pushed to Vault             ║"
echo "╚══════════════════════════════════════════╝"