#!/bin/bash
# destroy.sh — run this to tear down everything
set -euo pipefail

echo "=== Step 1: Destroying platform tools ==="
cd platform/
terraform destroy -var-file=terraform.tfvars -auto-approve

echo ""
echo "=== Step 2: Destroying infra ==="
cd ../infra/
terraform destroy -var-file=terraform.tfvars -auto-approve

echo ""
echo "=== All destroyed ==="