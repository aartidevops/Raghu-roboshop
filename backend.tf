terraform {
  backend "azurerm" {
    resource_group_name  = "rg-roboshop-tfstate"
    storage_account_name = "roboshoptfstateXXXX"  # paste from bootstrap.sh output
    container_name       = "tfstate"
    key                  = "dev/roboshop.tfstate"
  }
}