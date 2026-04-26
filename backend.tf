terraform {
  backend "azurerm" {
    resource_group_name  = "rg-roboshop-tfstate"
    storage_account_name = "roboshoptfstate50188763"  # paste from bootstrap.sh output
    container_name       = "tfstate"
    key                  = "dev/roboshop.tfstate"
  }
}