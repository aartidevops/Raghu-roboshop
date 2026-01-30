resource "azurerm_virtual_network" "main" {
  name                = "${var.rg_name}-vnet"
  location            = var.rg_location
  resource_group_name = var.rg_name
  address_space       = var.address_space

  tags = {
    environment = var.env
  }
}

resource "azurerm_subnet" "main" {
  count                = length(var.subnets)
  name                 = "${var.rg_name}-vnet-subnet-${count.index + 1}"
  virtual_network_name = azurerm_virtual_network.main.name
  resource_group_name  = var.rg_name
  address_prefixes     = [var.subnets[count.index]]
}

resource "azurerm_virtual_network_peering" "main-to-project" {
  name                      = "${var.rg_name}-to-project"
  resource_group_name       = var.rg_name
  virtual_network_name      = azurerm_virtual_network.main.name
  remote_virtual_network_id = data.azurerm_virtual_network.project.id
}

resource "azurerm_virtual_network_peering" "project-to-main" {
  name                      = "project-to-${var.rg_name}"
  resource_group_name       = data.azurerm_resource_group.default.name
  virtual_network_name      = data.azurerm_virtual_network.project.name
  remote_virtual_network_id = azurerm_virtual_network.main.id
}