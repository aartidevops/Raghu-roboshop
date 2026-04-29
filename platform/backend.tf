terraform {
  backend "azurerm" {
    resource_group_name  = "rg-roboshop-tfstate"
    storage_account_name = "roboshoptfstate"
    container_name       = "tfstate"
    key                  = "dev/platform.tfstate"
    # infra uses dev/infra.tfstate
    # platform uses dev/platform.tfstate
    # Two separate state files — they never interfere
  }
}