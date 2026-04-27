output "nginx_ingress_ip" {
  description = "Public IP of nginx ingress — point DNS records here"
  value       = "Run: kubectl get svc ingress-nginx-controller -n ingress-nginx"
}

output "argocd_url" {
  value = "https://argocd.${var.domain}"
}

output "vault_url" {
  value = "https://vault.${var.domain}"
}

output "grafana_url" {
  value = "https://grafana.${var.domain}"
}