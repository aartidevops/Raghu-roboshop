# output "resource_group_name" { value = module.resource_group.name }
# output "aks_cluster_name"    { value = module.aks.cluster_name }
# output "acr_login_server"    { value = module.acr.acr_login_server }
# output "agw_public_ip"       { value = module.app_gateway.public_ip }
# output "oidc_issuer_url"     { value = module.aks.oidc_issuer_url }
#
# output "connect_command" {
#   value = "az aks get-credentials --name ${module.aks.cluster_name} --resource-group ${module.resource_group.name}"
# }
#
# output "dns_instruction" {
#   value = "Create A record: *.${var.domain} → ${module.app_gateway.public_ip}"
# }
//

output "resource_group_name" {
  value = module.resource_group.name
}

output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "acr_login_server" {
  value = module.acr.acr_login_server
}

output "acr_name" {
  value = module.acr.acr_name
}

output "agw_public_ip" {
  value = module.app_gateway.public_ip
}

output "oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}

output "kube_config_host" {
  value     = module.aks.kube_config.host
  sensitive = true
}

output "kube_config_client_certificate" {
  value     = module.aks.kube_config.client_certificate
  sensitive = true
}

output "kube_config_client_key" {
  value     = module.aks.kube_config.client_key
  sensitive = true
}

output "kube_config_cluster_ca_certificate" {
  value     = module.aks.kube_config.cluster_ca_certificate
  sensitive = true
}

output "connect_command" {
  value = "az aks get-credentials --name ${module.aks.cluster_name} --resource-group ${module.resource_group.name} --overwrite-existing"
}

output "dns_instruction" {
  value = "After platform apply: point *.${var.domain} → nginx ingress IP"
}