terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "azurerm" {
  features {}
}

# Read infra state to get AKS connection details
# This is how platform/ knows the AKS cluster details without hardcoding
data "terraform_remote_state" "infra" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-roboshop-tfstate"
    storage_account_name = "roboshoptfstateXXXX"  # same storage account
    container_name       = "tfstate"
    key                  = "dev/infra.tfstate"
  }
}

# Helm provider — connects to AKS using outputs from infra state
provider "helm" {
  kubernetes {
    host = data.terraform_remote_state.infra.outputs.kube_config_host
    client_certificate = base64decode(
      data.terraform_remote_state.infra.outputs.kube_config_client_certificate
    )
    client_key = base64decode(
      data.terraform_remote_state.infra.outputs.kube_config_client_key
    )
    cluster_ca_certificate = base64decode(
      data.terraform_remote_state.infra.outputs.kube_config_cluster_ca_certificate
    )
  }
}

# Kubernetes provider — same connection details
provider "kubernetes" {
  host = data.terraform_remote_state.infra.outputs.kube_config_host
  client_certificate = base64decode(
    data.terraform_remote_state.infra.outputs.kube_config_client_certificate
  )
  client_key = base64decode(
    data.terraform_remote_state.infra.outputs.kube_config_client_key
  )
  cluster_ca_certificate = base64decode(
    data.terraform_remote_state.infra.outputs.kube_config_cluster_ca_certificate
  )
}

# kubectl provider — better for applying raw YAML manifests
# Used for ClusterIssuer which kubectl provider handles better than kubernetes_manifest
provider "kubectl" {
  host = data.terraform_remote_state.infra.outputs.kube_config_host
  client_certificate = base64decode(
    data.terraform_remote_state.infra.outputs.kube_config_client_certificate
  )
  client_key = base64decode(
    data.terraform_remote_state.infra.outputs.kube_config_client_key
  )
  cluster_ca_certificate = base64decode(
    data.terraform_remote_state.infra.outputs.kube_config_cluster_ca_certificate
  )
  load_config_file = false
}