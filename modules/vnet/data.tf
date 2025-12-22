data "azurerm_resource_group" "project" {
  name = "project-setup-1"
}

data "azurerm_virtual_network" "project" {
  name                = "main"
  resource_group_name = data.azurerm_resource_group.project.name
}