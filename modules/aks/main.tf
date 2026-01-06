
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks"
  location            = data.azurerm_resource_group.default.location
  resource_group_name = data.azurerm_resource_group.default.name
  kubernetes_version  = "1.33.5"
  dns_prefix          = "dev"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_B4ms"
  }

  identity {
    type = "SystemAssigned"
  }
}

