#!/bin/bash
# vault-init.sh
# Run ONCE after platform terraform apply
# Takes ~2 minutes
# SAVE the output — you need unseal key every time you restart Vault

set -euo pipefail

echo ""
echo "══════════════════════════════════════════"
echo "  Vault Initialisation Script"
echo "  Domain: skilltechnology.online"
echo "══════════════════════════════════════════"
echo ""

# Check vault-0 pod exists
echo "[1/7] Waiting for vault-0 pod to be Ready..."
kubectl wait --for=condition=Ready pod/vault-0 \
  -n vault \
  --timeout=300s
echo "      vault-0 is Ready"

# Check if already initialised
echo "[2/7] Checking Vault initialisation status..."
INIT_STATUS=$(kubectl exec -n vault vault-0 -- \
  vault status -format=json 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('initialized', False))" \
  2>/dev/null || echo "False")

if [ "$INIT_STATUS" = "True" ]; then
  echo "      Vault already initialised"
  SEALED=$(kubectl exec -n vault vault-0 -- \
    vault status -format=json 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('sealed', True))")

  if [ "$SEALED" = "True" ]; then
    echo "[!]   Vault is SEALED. Enter your unseal key:"
    read -s -p "Unseal key: " UNSEAL_KEY
    echo ""
    kubectl exec -n vault vault-0 -- vault operator unseal "$UNSEAL_KEY"
    echo "      Vault unsealed successfully"
  else
    echo "      Vault is already unsealed and running"
  fi
  exit 0
fi

# First time init
echo "[3/7] Initialising Vault (first time)..."
INIT_JSON=$(kubectl exec -n vault vault-0 -- \
  vault operator init \
    -key-shares=1 \
    -key-threshold=1 \
    -format=json)

UNSEAL_KEY=$(echo "$INIT_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['unseal_keys_b64'][0])")
ROOT_TOKEN=$(echo "$INIT_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['root_token'])")

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  SAVE THESE — YOU NEED THEM EVERY DAY       ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  Unseal Key: $UNSEAL_KEY"
echo "║  Root Token: $ROOT_TOKEN"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "Saving to /tmp/vault-keys.txt for this session..."
echo "Unseal Key: $UNSEAL_KEY" > /tmp/vault-keys.txt
echo "Root Token: $ROOT_TOKEN" >> /tmp/vault-keys.txt
echo "(Copy these to your notes app NOW)"
echo ""

# Unseal
echo "[4/7] Unsealing Vault..."
kubectl exec -n vault vault-0 -- vault operator unseal "$UNSEAL_KEY"
echo "      Vault unsealed"

# Login
echo "[5/7] Logging in with root token..."
kubectl exec -n vault vault-0 -- vault login "$ROOT_TOKEN" > /dev/null

# Enable secrets engine
echo "[6/7] Configuring Vault (secrets, auth, policies)..."

kubectl exec -n vault vault-0 -- vault secrets enable -path=secret kv-v2
echo "      KV v2 secrets engine enabled at path: secret/"

kubectl exec -n vault vault-0 -- vault auth enable kubernetes
echo "      Kubernetes auth method enabled"

kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc.cluster.local:443"
echo "      Kubernetes auth configured"

# Policy
kubectl exec -n vault vault-0 -- vault policy write roboshop-policy - <<'POLICY'
path "secret/data/roboshop/*" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
POLICY
echo "      roboshop-policy created"

# K8s auth role
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/roboshop \
  bound_service_account_names="roboshop-sa" \
  bound_service_account_namespaces="roboshop" \
  policies="roboshop-policy" \
  ttl="24h"
echo "      Kubernetes auth role created"

# Store secrets
echo "[7/7] Storing RoboShop secrets..."

kubectl exec -n vault vault-0 -- vault kv put secret/roboshop/mongodb \
  username="mongoadmin" \
  password="Mongo@Roboshop123"

kubectl exec -n vault vault-0 -- vault kv put secret/roboshop/mysql \
  username="shipping" \
  password="MySQL@Roboshop123" \
  database="cities" \
  host="mysql.roboshop.svc.cluster.local"

kubectl exec -n vault vault-0 -- vault kv put secret/roboshop/rabbitmq \
  username="roboshop" \
  password="RabbitMQ@Roboshop123" \
  host="rabbitmq.roboshop.svc.cluster.local"

kubectl exec -n vault vault-0 -- vault kv put secret/roboshop/redis \
  host="redis.roboshop.svc.cluster.local" \
  port="6379"

kubectl exec -n vault vault-0 -- vault kv put secret/roboshop/payment \
  stripe_key="sk_test_placeholder"

echo ""
echo "══════════════════════════════════════════"
echo "  Vault setup complete!"
echo "══════════════════════════════════════════"
echo "  UI: https://vault.skilltechnology.online"
echo "  Login: Method=Token, Token=$ROOT_TOKEN"
echo ""
echo "  Keys saved to: /tmp/vault-keys.txt"
echo "══════════════════════════════════════════"