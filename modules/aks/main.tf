# provider "azurerm" {
#   features {}
#   subscription_id = var.subscription_id
#   client_id       = var.client_id
#   client_secret   = var.client_secret
#   tenant_id       = var.tenant_id
# }

resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = "aks-cluster"
  location            = data.azurerm_resource_group.example.location
  resource_group_name = data.azurerm_resource_group.example.name
  dns_prefix          = "akscluster"

  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_B4ms"
  }

  identity {
    type = "SystemAssigned"
  }
}


