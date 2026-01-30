resource "null_resource" "kubeconfig" {
  depends_on = [azurerm_kubernetes_cluster.main]
  provisioner "local-exec" {
    command = <<EOF
az aks get-credentials --resource-group ${data.azurerm_resource_group.default.name} --name aks --overwrite-existing
EOF
  }
}

resource "helm_release" "external-secrets" {
  depends_on = [null_resource.kubeconfig]
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = "kube-system"

  set = [
    {
      name  = "installCRDs"
      value = "true"
    }
  ]
}

# resource "null_resource" "external-secrets" {
#   depends_on = [helm_release.external-secrets]
#   provisioner "local-exec" {
#     command = <<EOF
# kubectl apply -f /opt/vault-token.yml
# kubectl apply -f ${path.module}/files/secretStore.yaml
# EOF
#   }
# }

resource "null_resource" "external-secrets" {
  depends_on = [helm_release.external-secrets]

  provisioner "local-exec" {
    command = <<EOF
echo "Waiting for External Secrets CRDs..."
kubectl wait --for=condition=Established crd/secretstores.external-secrets.io --timeout=120s
kubectl wait --for=condition=Established crd/clustersecretstores.external-secrets.io --timeout=120s

echo "Applying Vault token and SecretStore"
kubectl apply -f /opt/vault-token.yml
kubectl apply -f modules/aks/files/secretStore.yaml
EOF
  }
}
