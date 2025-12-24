data "azurerm_resource_group" "default" {
  name = "RG"
}


data "azurerm_virtual_network" "project" {
  name                = "vault-vnet"
  resource_group_name = data.azurerm_resource_group.default.name
}