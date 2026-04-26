output "resource_group_name" { value = module.resource_group.name }
output "aks_cluster_name"    { value = module.aks.cluster_name }
output "acr_login_server"    { value = module.acr.acr_login_server }
output "agw_public_ip"       { value = module.app_gateway.public_ip }
output "oidc_issuer_url"     { value = module.aks.oidc_issuer_url }

output "connect_command" {
  value = "az aks get-credentials --name ${module.aks.cluster_name} --resource-group ${module.resource_group.name}"
}

output "dns_instruction" {
  value = "Create A record: *.${var.domain} → ${module.app_gateway.public_ip}"
}