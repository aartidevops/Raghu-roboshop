#
# resource "azurerm_kubernetes_cluster" "main" {
#   name                = var.name
#   location            = data.azurerm_resource_group.example.location
#   resource_group_name = data.azurerm_resource_group.example.name
#   kubernetes_version  = "1.31.2"
#   dns_prefix          = var.env
#
#   default_node_pool {
#     name       = "default"
#     node_count = 1
#     vm_size    = "Standard_B4ms"
#   }
#
#   identity {
#     type = "SystemAssigned"
#   }
# }

