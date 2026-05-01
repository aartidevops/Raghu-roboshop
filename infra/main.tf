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




# ─────────────────────────────────────────────────────────────
# COSMOS DB (MongoDB API)
# One account, three databases (dev/uat/prod)
# Real project pattern: separate accounts per env for prod
# For lab: one account, separate databases per env (cost saving)
# ─────────────────────────────────────────────────────────────

resource "azurerm_cosmosdb_account" "roboshop" {
  name                = "cosmos-roboshop-${var.env}"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  offer_type          = "Standard"
  kind                = "MongoDB"
  free_tier_enabled   = true
  # ↑ renamed from enable_free_tier in azurerm 4.x

  mongo_server_version = "4.2"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = module.resource_group.location
    failover_priority = 0
  }

  capabilities {
    name = "EnableMongo"
  }

  capabilities {
    name = "mongoEnableDocLevelTTL"
  }

  capabilities {
    name = "EnableServerless"
    # Serverless = pay per request, no minimum cost
    # Better than provisioned throughput for dev/lab
    # Remove this for prod and set throughput instead
  }

  tags = var.tags
}

# Three databases — one per environment
resource "azurerm_cosmosdb_mongo_database" "dev" {
  name                = "roboshop-dev"
  resource_group_name = module.resource_group.name
  account_name        = azurerm_cosmosdb_account.roboshop.name
}

resource "azurerm_cosmosdb_mongo_database" "uat" {
  name                = "roboshop-uat"
  resource_group_name = module.resource_group.name
  account_name        = azurerm_cosmosdb_account.roboshop.name
}

resource "azurerm_cosmosdb_mongo_database" "prod" {
  name                = "roboshop-prod"
  resource_group_name = module.resource_group.name
  account_name        = azurerm_cosmosdb_account.roboshop.name
}

# Collections inside each database
resource "azurerm_cosmosdb_mongo_collection" "catalogue_dev" {
  name                = "products"
  resource_group_name = module.resource_group.name
  account_name        = azurerm_cosmosdb_account.roboshop.name
  database_name       = azurerm_cosmosdb_mongo_database.dev.name
  shard_key           = "_id"
}

resource "azurerm_cosmosdb_mongo_collection" "catalogue_uat" {
  name                = "products"
  resource_group_name = module.resource_group.name
  account_name        = azurerm_cosmosdb_account.roboshop.name
  database_name       = azurerm_cosmosdb_mongo_database.uat.name
  shard_key           = "_id"
}

resource "azurerm_cosmosdb_mongo_collection" "catalogue_prod" {
  name                = "products"
  resource_group_name = module.resource_group.name
  account_name        = azurerm_cosmosdb_account.roboshop.name
  database_name       = azurerm_cosmosdb_mongo_database.prod.name
  shard_key           = "_id"
}

# ─────────────────────────────────────────────────────────────
# AZURE CACHE FOR REDIS
# One instance per environment (C0 basic tier for dev/uat)
# Cart service uses Redis for session storage
# ─────────────────────────────────────────────────────────────

resource "azurerm_redis_cache" "dev" {
  name                = "redis-roboshop-dev-${random_string.suffix.result}"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  capacity            = 0
  family              = "C"
  sku_name            = "Basic"
  # Basic C0 = cheapest, enough for dev/lab
  # For prod: use Standard or Premium with replication

  redis_configuration {}

  tags = var.tags
}

resource "azurerm_redis_cache" "uat" {
  name                = "redis-roboshop-uat-${random_string.suffix.result}"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  capacity            = 0
  family              = "C"
  sku_name            = "Basic"

  redis_configuration {}

  tags = var.tags
}

# Random suffix so names are globally unique
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}