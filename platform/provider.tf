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
      # gavinbunney/kubectl handles raw YAML manifests without schema validation
      # This is what fixes the "cannot create REST client" error
      # kubernetes_manifest validates CRDs at plan time — fails when cluster is new
      # kubectl provider applies YAML without that validation — always works
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}

provider "azurerm" {
  features {}
}

# This reads the outputs from your infra/ terraform state
# So platform knows the AKS cluster credentials
# You never hardcode any connection details
data "terraform_remote_state" "infra" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-roboshop-tfstate"
    storage_account_name = "roboshoptfstate"
    container_name       = "tfstate"
    key                  = "dev/roboshop.tfstate"
    # This reads infra state — NOT platform state
  }
}

# Helm provider uses AKS creds from infra state
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

# Kubernetes provider — same creds, used for namespaces and service accounts
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

# kubectl provider — same creds, used for raw YAML like ClusterIssuer
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