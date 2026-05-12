#!/bin/bash
# destroy.sh — tear down everything cleanly
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# PRE-DESTROY CLEANUP
#
# Must run BEFORE terraform destroy because:
#
# 1. ArgoCD Application objects have finalizers:
#    resources-finalizer.argocd.argoproj.io
#    → they block namespace deletion waiting for ArgoCD to clean
#      up live k8s resources. But Terraform is destroying ArgoCD
#      at the same time → deadlock → "context deadline exceeded"
#
# 2. ArgoCD + cert-manager Helm charts mark their CRDs with:
#    helm.sh/resource-policy: keep
#    → Helm intentionally leaves CRDs behind on uninstall
#    → Namespace can't delete while CRD-defined objects exist
#    → Terraform times out waiting for namespace deletion
#
# Fix: strip finalizers → delete ArgoCD apps → delete CRDs
# Then Terraform destroy runs in seconds with no stuck namespaces.
# ─────────────────────────────────────────────────────────────

echo "=== Pre-destroy: Cluster cleanup ==="

# Check if cluster is reachable — skip cleanup if not
if ! kubectl cluster-info &>/dev/null; then
  echo "Cluster not reachable — skipping pre-destroy cleanup"
else

  echo ""
  echo "--- Stripping ArgoCD finalizers from Application objects ---"
  # Finalizer prevents Application deletion without ArgoCD running.
  # patch removes it so kubectl can delete the object immediately.
  kubectl get applications -n argocd \
    -o jsonpath='{.items[*].metadata.name}' 2>/dev/null \
  | tr ' ' '\n' \
  | while read -r app; do
      [ -z "$app" ] && continue
      echo "  Removing finalizer from: $app"
      kubectl patch application "$app" -n argocd \
        --type=json \
        -p='[{"op":"remove","path":"/metadata/finalizers"}]' \
        2>/dev/null || true
    done

  echo ""
  echo "--- Deleting ArgoCD Application and AppProject objects ---"
  kubectl delete applications --all -n argocd --timeout=30s 2>/dev/null || true
  kubectl delete appprojects --all -n argocd --timeout=30s 2>/dev/null || true

  echo ""
  echo "--- Deleting ArgoCD CRDs (kept by Helm resource policy) ---"
  # These are the CRDs Helm leaves behind intentionally.
  # Must delete before namespace can be removed.
  for crd in \
    applications.argoproj.io \
    applicationsets.argoproj.io \
    appprojects.argoproj.io; do
    kubectl delete crd "$crd" --timeout=30s 2>/dev/null && echo "  Deleted: $crd" || echo "  Already gone: $crd"
  done

  echo ""
  echo "--- Deleting cert-manager CRDs (kept by Helm resource policy) ---"
  for crd in \
    certificaterequests.cert-manager.io \
    certificates.cert-manager.io \
    challenges.acme.cert-manager.io \
    clusterissuers.cert-manager.io \
    issuers.cert-manager.io \
    orders.acme.cert-manager.io; do
    kubectl delete crd "$crd" --timeout=30s 2>/dev/null && echo "  Deleted: $crd" || echo "  Already gone: $crd"
  done

  echo ""
  echo "--- Pre-destroy cleanup complete ---"

fi

# ─────────────────────────────────────────────────────────────
# TERRAFORM DESTROY
# ─────────────────────────────────────────────────────────────

echo ""
echo "=== Step 1: Destroying platform tools ==="
cd platform/
terraform destroy -var-file=terraform.tfvars -auto-approve

echo ""
echo "=== Step 2: Destroying infra ==="
cd ../infra/
terraform destroy -var-file=terraform.tfvars -auto-approve

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  DESTROY COMPLETE — see you tomorrow!    ║"
echo "╚══════════════════════════════════════════╝"
