output "cert_manager_status" {
  value = "cert-manager installed in namespace: cert-manager"
}

output "verify_commands" {
  value = <<-EOT
    # Run these after apply to verify cert-manager is working:

    # 1. Check all 3 pods are Running
    kubectl get pods -n cert-manager

    # 2. Check ClusterIssuer is Ready (READY column = True)
    kubectl get clusterissuer letsencrypt-prod

    # 3. Describe issuer if Ready=False
    kubectl describe clusterissuer letsencrypt-prod
  EOT
}