# Resource Groups
module "resource-group" {
  for_each = var.resource_groups
  source   = "./modules/resource-group"
  location = each.value["location"]
  name     = each.value["name"]
}

# Virtual Network
module "vnet" {
  for_each      = var.vnets
  source        = "./modules/vnet"
  rg_name       = module.resource-group["main"].name
  rg_location   = module.resource-group["main"].location
  address_space = each.value["address_space"]
  env           = var.env
  subnets       = each.value["subnets"]
}

# Azure Container Registry — stores all RoboShop Docker images
module "acr" {
  source              = "./modules/acr"
  acr_name            = var.acr_name
  resource_group_name = module.resource-group["main"].name
  location            = module.resource-group["main"].location
  env                 = var.env
}

# AKS Cluster — runs all RoboShop services
module "aks" {
  source              = "./modules/aks"
  cluster_name        = var.aks.cluster_name
  location            = module.resource-group["main"].location
  resource_group_name = module.resource-group["main"].name
  kubernetes_version  = var.aks.kubernetes_version
  system_node_count   = var.aks.system_node_count
  system_node_size    = var.aks.system_node_size
  workload_node_size  = var.aks.workload_node_size
  workload_min_count  = var.aks.workload_min_count
  workload_max_count  = var.aks.workload_max_count
  acr_id              = module.acr.acr_id
  env                 = var.env

  depends_on = [module.vnet]
}

# Outputs — you'll use these in later phases
output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "acr_login_server" {
  value = module.acr.acr_login_server
}

output "connect_to_aks" {
  value = "az aks get-credentials --name ${module.aks.cluster_name} --resource-group ${module.resource-group["main"].name}"
}