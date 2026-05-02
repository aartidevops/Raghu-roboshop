# modules/aks/outputs.tf

output "cluster_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "cluster_id" {
  value = azurerm_kubernetes_cluster.this.id
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

# output "kubelet_identity_object_id" {
#   value = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
# }

output "node_resource_group" {
  value = azurerm_kubernetes_cluster.this.node_resource_group
}

# Expose individual kubeconfig fields for providers
# Do NOT expose as a single raw string in outputs — security risk
output "kube_config" {
  sensitive = true
  value = {
    host                   = azurerm_kubernetes_cluster.this.kube_config[0].host
    client_certificate     = azurerm_kubernetes_cluster.this.kube_config[0].client_certificate
    client_key             = azurerm_kubernetes_cluster.this.kube_config[0].client_key
    cluster_ca_certificate = azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate
  }
}

output "kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}