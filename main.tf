# Resource group
module "resource_group" {
  source   = "./modules/resource-group"
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Networking
module "vnet" {
  source              = "./modules/vnet"
  project             = var.project
  env                 = var.env
  location            = var.location
  resource_group_name = module.resource_group.name
  vnet_cidr           = var.vnet_cidr
  aks_subnet_cidr     = var.aks_subnet_cidr
  agw_subnet_cidr     = var.agw_subnet_cidr
  tags                = var.tags
}

# Container Registry
module "acr" {
  source              = "./modules/acr"
  acr_name            = var.acr_name
  resource_group_name = module.resource_group.name
  location            = var.location
  tags                = var.tags
}

# AKS Cluster
module "aks" {
  source              = "./modules/aks"
  cluster_name        = var.aks_cluster_name
  location            = var.location
  resource_group_name = module.resource_group.name
  kubernetes_version  = var.kubernetes_version
  system_node_count   = var.system_node_count
  system_node_size    = var.system_node_size
  workload_node_size  = var.workload_node_size
  workload_min_count  = var.workload_min_count
  workload_max_count  = var.workload_max_count
  acr_id              = module.acr.acr_id
  tags                = var.tags
  depends_on          = [module.vnet]
}

# Application Gateway
module "app_gateway" {
  source              = "./modules/app-gateway"
  project             = var.project
  env                 = var.env
  location            = var.location
  resource_group_name = module.resource_group.name
  agw_subnet_id       = module.vnet.agw_subnet_id
  tags                = var.tags
}

# Add to your existing main.tf — keep all existing modules, add these

# Azure Key Vault — survives destroy, stores Vault keys
module "azure_keyvault" {
  source              = "./modules/azure-key-vault"
  env                 = var.env
  location            = var.location
  resource_group_name = module.resource_group.name
  tags                = var.tags
}

# Platform tools — all installed via Helm
module "platform" {
  source = "./modules/platform"

  domain              = var.domain
  email               = var.email
  azure_keyvault_id   = module.azure_keyvault.key_vault_id
  azure_keyvault_name = module.azure_keyvault.key_vault_name
  mongodb_password    = var.mongodb_password
  mysql_password      = var.mysql_password
  rabbitmq_password   = var.rabbitmq_password
  grafana_password    = var.grafana_password
  stripe_key          = var.stripe_key

  depends_on = [module.aks]
  # CRITICAL: platform depends on AKS existing first
  # Helm and Kubernetes providers need AKS to be Ready
}