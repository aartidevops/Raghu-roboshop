output "argocd_url" {
  value = "https://argocd.${var.domain}"
}

output "vault_url" {
  value = "https://vault.${var.domain}"
}

output "grafana_url" {
  value = "https://grafana.${var.domain}"
}

output "get_nginx_ip" {
  value = "kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
}

output "get_argocd_password" {
  value = "kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d"
}

output "next_steps" {
  value = <<-EOT
    1. Get nginx IP:    kubectl get svc ingress-nginx-controller -n ingress-nginx
    2. Add DNS A record: *.skilltechnology.online → <nginx-ip>
       OR add individual records:
         argocd.skilltechnology.online  → <nginx-ip>
         vault.skilltechnology.online   → <nginx-ip>
         grafana.skilltechnology.online → <nginx-ip>
    3. Run vault-init.sh to initialise Vault
    4. Access ArgoCD:  https://argocd.skilltechnology.online
  EOT
}