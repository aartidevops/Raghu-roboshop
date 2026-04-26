resource "azurerm_container_registry" "roboshop" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"   # Basic is fine for dev, Premium for prod
  admin_enabled       = false     # use managed identity, not admin user

  tags = {
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}