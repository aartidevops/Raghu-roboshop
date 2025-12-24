data "azurerm_resource_group" "default" {
  name = "RG"
}

# data "vault_generic_secret" "ssh" {
#   path = "infra/ssh"
# }