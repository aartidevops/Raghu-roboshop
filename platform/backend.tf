terraform {
  backend "azurerm" {
    resource_group_name  = "rg-roboshop-tfstate"
    storage_account_name = "roboshoptfstate"  # same storage account
    container_name       = "tfstate"
    key                  = "dev/platform.tfstate" # different key — separate state
  }
}