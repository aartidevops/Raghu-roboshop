module "resource-group" {
  for_each = var.resource_groups
  source   = "./modules/resource-group"
  location = each.value["location"]
  name     = each.value["name"]
}

module "vnet" {
  for_each      = var.vnets
  source        = "./modules/vnet"
  rg_name       = module.resource-group[each.key].name
  rg_location   = module.resource-group[each.key].location
  address_space = each.value["address_space"]
  env           = var.env
  subnets       = each.value["subnets"]
}

module "databases" {
  for_each        = var.databases
  source          = "./modules/vm"
  component       = each.value["name"]
  vm_size         = each.value["vm_size"]
  port            = each.value["port"]
  env             = var.env
  container       = each.value["container"]
  subnet_ids      = module.vnet["main"].subnet_ids
  # subscription_id = var.subscription_id
}

# module "aks" {
#   for_each             = var.aks
#   source               = "./modules/aks"
#   vault_token          = var.token
#   subscription_id      = var.subscription_id
#   virtual_network_name = "main"
#   env                  = var.env
#   name                 = each.key
#   subnet_ids           = module.vnet["main"].subnet_ids
# }

output "x" {
  value = module.vnet["main"].subnet_ids
}