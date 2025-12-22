
terraform {
  backend "azurerm" {}

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "3.21.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}


provider "vault" {
  address = "http://vault-internal.azdevopsb82.online:8200"
  token   = var.token
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "grafana" {
  url  = "http://grafana-${var.env}.azdevopsb82.online/"
  auth = data.vault_generic_secret.k8s.data["grafana_auth"]
}