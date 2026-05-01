#!/bin/bash
# vault-init.sh
# Run once after terraform apply
# Save the output — you need it every time you recreate

set -euo pipefail

echo "=== Waiting for vault-0 pod ==="
kubectl wait --for=condition=Ready pod/vault-0 \
  -n vault --timeout=300s 2>/dev/null || true

echo ""
echo "=== Vault Status ==="
kubectl exec -n vault vault-0 -- vault status 2>/dev/null || true

# Check if already initialised
INITIALIZED=$(kubectl exec -n vault vault-0 -- \
  vault status -format=json 2>/dev/null \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['initialized'])" \
  2>/dev/null || echo "false")

if [ "$INITIALIZED" = "True" ]; then
  echo ""
  echo "Vault already initialised."
  echo "Enter your unseal key to unseal:"
  read -s -p "Unseal key: " KEY
  echo ""
  kubectl exec -n vault vault-0 -- vault operator unseal "$KEY"
  echo "Vault unsealed."
  exit 0
fi

echo ""
echo "=== Initialising Vault ==="
INIT=$(kubectl exec -n vault vault-0 -- \
  vault operator init \
  -key-shares=1 \
  -key-threshold=1 \
  -format=json)

UNSEAL_KEY=$(echo "$INIT" | python3 -c \
  "import sys,json; print(json.load(sys.stdin)['unseal_keys_b64'][0])")
ROOT_TOKEN=$(echo "$INIT" | python3 -c \
  "import sys,json; print(json.load(sys.stdin)['root_token'])")

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   SAVE THESE — NEEDED EVERY RESTART             ║"
echo "╠══════════════════════════════════════════════════╣"
echo "  Unseal Key : $UNSEAL_KEY"
echo "  Root Token : $ROOT_TOKEN"
echo "╚══════════════════════════════════════════════════╝"
echo ""

echo "$UNSEAL_KEY" > /tmp/vault-unseal-key.txt
echo "$ROOT_TOKEN" > /tmp/vault-root-token.txt
echo "Also saved to /tmp/vault-unseal-key.txt and /tmp/vault-root-token.txt"

echo ""
echo "=== Unsealing ==="
kubectl exec -n vault vault-0 -- vault operator unseal "$UNSEAL_KEY"

echo ""
echo "=== Logging in ==="
kubectl exec -n vault vault-0 -- vault login "$ROOT_TOKEN"

echo ""
echo "=== Enabling KV v2 secrets engine ==="
kubectl exec -n vault vault-0 -- vault secrets enable -path=secret kv-v2

echo ""
echo "=== Enabling Kubernetes auth ==="
kubectl exec -n vault vault-0 -- vault auth enable kubernetes

kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc.cluster.local:443"

echo ""
echo "=== Creating policies per environment ==="

# Dev policy
kubectl exec -n vault vault-0 -- vault policy write roboshop-dev - <<'EOF'
path "secret/data/roboshop/dev/*" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF

# UAT policy
kubectl exec -n vault vault-0 -- vault policy write roboshop-uat - <<'EOF'
path "secret/data/roboshop/uat/*" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF

# Prod policy
kubectl exec -n vault vault-0 -- vault policy write roboshop-prod - <<'EOF'
path "secret/data/roboshop/prod/*" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF

echo ""
echo "=== Creating K8s auth roles per environment ==="

# Each environment namespace gets its own role
# bound to its own service account and its own policy
# This means dev pods CANNOT read prod secrets — isolation by design

kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/roboshop-dev \
  bound_service_account_names="roboshop-sa" \
  bound_service_account_namespaces="roboshop-dev" \
  policies="roboshop-dev" \
  ttl="24h"

kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/roboshop-uat \
  bound_service_account_names="roboshop-sa" \
  bound_service_account_namespaces="roboshop-uat" \
  policies="roboshop-uat" \
  ttl="24h"

kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/roboshop-prod \
  bound_service_account_names="roboshop-sa" \
  bound_service_account_namespaces="roboshop-prod" \
  policies="roboshop-prod" \
  ttl="24h"

echo ""
echo "=== Storing secrets per environment ==="
# Separate secrets per env — dev has dev DB, prod has prod DB
# In real project: prod secrets are stored manually by ops team
# never in scripts — but for lab this is fine

# Dev secrets
kubectl exec -n vault vault-0 -- vault kv put secret/roboshop/dev/mongodb \
  uri="mongodb://mongoadmin:DevMongo@123@roboshop-dev-cosmos.mongo.cosmos.azure.com:10255/catalogue?ssl=true&replicaSet=globaldb"

kubectl exec -n vault vault-0 -- vault kv put secret/roboshop/dev/redis \
  host="roboshop-dev-redis.redis.cache.windows.net" \
  port="6380" \
  password="REPLACE_WITH_DEV_REDIS_KEY"

# UAT secrets
kubectl exec -n vault vault-0 -- vault kv put secret/roboshop/uat/mongodb \
  uri="mongodb://mongoadmin:UatMongo@123@roboshop-uat-cosmos.mongo.cosmos.azure.com:10255/catalogue?ssl=true&replicaSet=globaldb"

kubectl exec -n vault vault-0 -- vault kv put secret/roboshop/uat/redis \
  host="roboshop-uat-redis.redis.cache.windows.net" \
  port="6380" \
  password="REPLACE_WITH_UAT_REDIS_KEY"

# Prod secrets
kubectl exec -n vault vault-0 -- vault kv put secret/roboshop/prod/mongodb \
  uri="mongodb://mongoadmin:ProdMongo@123@roboshop-prod-cosmos.mongo.cosmos.azure.com:10255/catalogue?ssl=true&replicaSet=globaldb"

kubectl exec -n vault vault-0 -- vault kv put secret/roboshop/prod/redis \
  host="roboshop-prod-redis.redis.cache.windows.net" \
  port="6380" \
  password="REPLACE_WITH_PROD_REDIS_KEY"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   VAULT SETUP COMPLETE                          ║"
echo "╠══════════════════════════════════════════════════╣"
echo "  UI:         https://vault.skilltechnology.online"
echo "  Login:      Token method"
echo "  Token:      $ROOT_TOKEN"
echo "  Unseal key: $UNSEAL_KEY"
echo "╚══════════════════════════════════════════════════╝"