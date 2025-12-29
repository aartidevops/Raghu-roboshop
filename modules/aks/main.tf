# provider "azurerm" {
#   features {}
#   subscription_id = var.subscription_id
#   client_id       = var.client_id
#   client_secret   = var.client_secret
#   tenant_id       = var.tenant_id
# }

resource "azurerm_kubernetes_cluster" "main" {
  name                = var.name
  location            = data.azurerm_resource_group.example.location
  resource_group_name = data.azurerm_resource_group.example.name
  kubernetes_version  = "1.31.2"
  dns_prefix          = var.env

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_B4ms"
  }

  identity {
    type = "SystemAssigned"
  }
}


# resource "azurerm_kubernetes_cluster" "main" {
#   name                = var.name
#   location            = data.azurerm_resource_group.main.location
#   resource_group_name = data.azurerm_resource_group.main.name
#   kubernetes_version  = "1.31.2"
#   dns_prefix          = var.env
#
#   default_node_pool {
#     name                 = "p20250131"
#     node_count           = 1
#     vm_size              = "Standard_D4_v2"
#     auto_scaling_enabled = false
#     vnet_subnet_id       = var.subnet_ids[0]
#   }
#
#
#
#   aci_connector_linux {
#     subnet_name = var.subnet_ids[0]
#   }
#
#
#   network_profile {
#     network_plugin = "azure"
#     service_cidr   = "10.100.0.0/24"
#     dns_service_ip = "10.100.0.100"
#   }
#
#   identity {
#     type = "SystemAssigned"
#
#   }


