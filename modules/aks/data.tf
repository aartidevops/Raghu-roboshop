data "azurerm_resource_group" "example" {
  name = "RG"
}

# data "azurerm_subnet" "example" {
#   name                 = "snet-ukwest-1"
#   virtual_network_name = "vnet-ukwest"
#   resource_group_name  = data.azurerm_resource_group.example.name
# }
