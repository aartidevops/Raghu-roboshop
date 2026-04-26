output "cluster_name" {
  value = azurerm_kubernetes_cluster.roboshop.name
}

output "cluster_id" {
  value = azurerm_kubernetes_cluster.roboshop.id
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.roboshop.kube_config_raw
  sensitive = true   # won't show in terminal output
}

output "kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.roboshop.kubelet_identity[0].object_id
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.roboshop.oidc_issuer_url
}