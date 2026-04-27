# modules/azure-keyvault/main.tf
# Azure Key Vault — survives terraform destroy
# Stores Vault init keys so you don't lose them

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "roboshop" {
  name                = "kv-roboshop-${var.env}"   # must be globally unique, 3-24 chars
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"   # free tier is standard

  # Soft delete — secrets recoverable for 7 days after delete
  soft_delete_retention_days = 7
  purge_protection_enabled   = false   # allow purge for dev (cost saving)

  # Allow your own Azure account to manage secrets
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore", "Purge"
    ]
  }

  tags = var.tags

  # NEVER destroy this — it holds your Vault keys
  lifecycle {
    prevent_destroy = true
  }
}

# Pre-create placeholder secrets
# Terraform will update these with real values after Vault init
resource "azurerm_key_vault_secret" "vault_root_token" {
  name         = "vault-root-token"
  value        = "placeholder"   # updated by null_resource after Vault init
  key_vault_id = azurerm_key_vault.roboshop.id

  lifecycle {
    # Don't overwrite real values with placeholder on re-apply
    ignore_changes = [value]
  }
}

resource "azurerm_key_vault_secret" "vault_unseal_key" {
  name         = "vault-unseal-key"
  value        = "placeholder"
  key_vault_id = azurerm_key_vault.roboshop.id

  lifecycle {
    ignore_changes = [value]
  }
}