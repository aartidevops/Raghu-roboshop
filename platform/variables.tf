
variable "domain" {
  type    = string
  default = "skilltechnology.online"
}

variable "email" {
  type    = string
  default = "aartichaple2124@gmail.com"
}

# Environment toggle — drives sizing across ALL tools
variable "environment" {
  type    = string
  default = "dev"
  # dev  = minimal resources, 1 replica everywhere
  # prod = HA resources, 3 replicas, larger nodes
}

# Vault replicas — change to 3 for HA prod
variable "vault_replicas" {
  type    = number
  default = 1
  # 1 = standalone dev
  # 3 = HA Raft prod (3 pods across 3 AZs)
}

# Nginx replicas
variable "nginx_replicas" {
  type    = number
  default = 1
  # prod = 2
}

# ArgoCD HA
variable "argocd_ha_enabled" {
  type    = bool
  default = false
  # prod = true
}