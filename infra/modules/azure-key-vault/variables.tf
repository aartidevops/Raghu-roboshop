# modules/azure-keyvault/variables.tf
variable "env"                 { type = string }
variable "location"            { type = string }
variable "resource_group_name" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

# modules/azure-keyvault/outputs.tf
output "key_vault_id"   { value = azurerm_key_vault.roboshop.id }
output "key_vault_uri"  { value = azurerm_key_vault.roboshop.vault_uri }
output "key_vault_name" { value = azurerm_key_vault.roboshop.name }