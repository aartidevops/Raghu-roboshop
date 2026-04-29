terraform {
  backend "azurerm" {
    resource_group_name  = "rg-roboshop-tfstate"
    storage_account_name = "roboshoptfstate"
    container_name       = "tfstate"
    key                  = "dev/roboshop.tfstate"
    # infra uses dev/roboshop.tfstate
    # platform uses dev/platform.tfstate
    # Two separate state files — they never interfere
  }
}