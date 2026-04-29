output "verify_commands" {
  value = <<-EOT
    # Check cert-manager
    kubectl get pods -n cert-manager
    kubectl get clusterissuer letsencrypt-prod

    # Check nginx
    kubectl get pods -n ingress-nginx
    kubectl get svc ingress-nginx-controller -n ingress-nginx

    # Get nginx public IP (set this as DNS A record)
    kubectl get svc ingress-nginx-controller -n ingress-nginx \
      -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
  EOT
}