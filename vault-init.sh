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

# ─────────────────────────────────────────────────────────────
# Check if already initialised
# vault status exits 0 (unsealed), 1 (error), or 2 (sealed)
# Even when sealed, -format=json outputs valid JSON with initialized=true
# We suppress the exit code with ||true and parse stdout separately
# ─────────────────────────────────────────────────────────────
VAULT_STATUS_JSON=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null || true)

INITIALIZED="false"
if [ -n "$VAULT_STATUS_JSON" ]; then
  INITIALIZED=$(echo "$VAULT_STATUS_JSON" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print('true' if d.get('initialized') else 'false')" \
    2>/dev/null || echo "false")
fi

if [ "$INITIALIZED" = "true" ]; then
  echo ""
  echo "Vault already initialised."
  echo "Enter your unseal key to unseal:"
  read -s -p "Unseal key: " KEY
  echo ""
  kubectl exec -n vault vault-0 -- vault operator unseal "$KEY"
  echo "Vault unsealed."

  # Log in for the rest of the script
  if [ -f /tmp/vault-root-token.txt ]; then
    ROOT_TOKEN=$(cat /tmp/vault-root-token.txt)
    kubectl exec -n vault vault-0 -- vault login "$ROOT_TOKEN" > /dev/null
    echo "Logged in with saved root token."
  else
    echo "No saved root token found at /tmp/vault-root-token.txt"
    echo "Enter root token to configure Vault:"
    read -s -p "Root token: " ROOT_TOKEN
    echo ""
    kubectl exec -n vault vault-0 -- vault login "$ROOT_TOKEN" > /dev/null
    echo "$ROOT_TOKEN" > /tmp/vault-root-token.txt
  fi

  # Idempotent: enable secrets/auth only if not already enabled
  echo ""
  echo "=== Ensuring Vault engines enabled (idempotent) ==="
  kubectl exec -n vault vault-0 -- vault secrets enable -path=secret kv-v2 2>/dev/null || echo "  kv-v2 already enabled"
  kubectl exec -n vault vault-0 -- vault auth enable kubernetes 2>/dev/null || echo "  kubernetes auth already enabled"

  kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc.cluster.local:443" 2>/dev/null || true

  echo "Vault ready — run push-secrets.sh to populate secrets."
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
echo "=== Enabling KV v2 secrets engine (idempotent) ==="
kubectl exec -n vault vault-0 -- vault secrets enable -path=secret kv-v2 2>/dev/null || echo "  kv-v2 already enabled"

echo ""
echo "=== Enabling Kubernetes auth (idempotent) ==="
kubectl exec -n vault vault-0 -- vault auth enable kubernetes 2>/dev/null || echo "  kubernetes auth already enabled"

kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc.cluster.local:443"

echo ""
echo "=== Creating policies per environment ==="

cat > /tmp/policy-dev.hcl <<'EOF'
path "secret/data/roboshop/dev/*" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF

cat > /tmp/policy-uat.hcl <<'EOF'
path "secret/data/roboshop/uat/*" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF

cat > /tmp/policy-prod.hcl <<'EOF'
path "secret/data/roboshop/prod/*" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF

kubectl cp /tmp/policy-dev.hcl  vault/vault-0:/tmp/policy-dev.hcl
kubectl cp /tmp/policy-uat.hcl  vault/vault-0:/tmp/policy-uat.hcl
kubectl cp /tmp/policy-prod.hcl vault/vault-0:/tmp/policy-prod.hcl

kubectl exec -n vault vault-0 -- vault policy write roboshop-dev  /tmp/policy-dev.hcl
kubectl exec -n vault vault-0 -- vault policy write roboshop-uat  /tmp/policy-uat.hcl
kubectl exec -n vault vault-0 -- vault policy write roboshop-prod /tmp/policy-prod.hcl

echo "Policies created"

echo ""
echo "=== Creating K8s auth roles per environment ==="

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
echo "╔══════════════════════════════════════════════════╗"
echo "║   VAULT SETUP COMPLETE                          ║"
echo "╠══════════════════════════════════════════════════╣"
echo "  UI:         https://vault.skilltechnology.online"
echo "  Login:      Token method"
echo "  Token:      $ROOT_TOKEN"
echo "  Unseal key: $UNSEAL_KEY"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "Next: run bash push-secrets.sh to push DB secrets from Terraform outputs"
