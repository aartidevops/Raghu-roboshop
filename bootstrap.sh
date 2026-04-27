#!/bin/bash
# Run this manually once to create the remote state storage
# az login first, then: bash bootstrap.sh

set -euo pipefail

LOCATION="UK West"
TF_RG="rg-roboshop-tfstate"
TF_SA="roboshoptfstate"  # unique name
TF_CONTAINER="tfstate"

echo "Creating terraform state storage..."
az group create --name $TF_RG --location "$LOCATION"
az storage account create \
  --name $TF_SA \
  --resource-group $TF_RG \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --allow-blob-public-access false \
  --min-tls-version TLS1_2

az storage container create \
  --name $TF_CONTAINER \
  --account-name $TF_SA

echo ""
echo "Copy these values into backend.tf:"
echo "  storage_account_name = \"$TF_SA\""
echo "  resource_group_name  = \"$TF_RG\""
echo "  container_name       = \"$TF_CONTAINER\""