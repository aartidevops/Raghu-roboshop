# This module creates a complete AKS cluster for RoboShop
# System node pool: runs Kubernetes system components (CoreDNS, etc)
# Workload node pool: runs all RoboShop services

resource "azurerm_kubernetes_cluster" "roboshop" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  # System node pool — always on, never scales to zero
  default_node_pool {
    name                        = "system"
    node_count                  = var.system_node_count
    vm_size                     = var.system_node_size
    only_critical_addons_enabled = true   # only K8s system pods run here

    upgrade_settings {
      max_surge = "33%"
    }
  }

  # Use system-assigned identity — simpler for learning
  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"     # pods get real VNet IPs
    network_policy = "calico"    # enables NetworkPolicy objects
    service_cidr   = "172.16.0.0/16"
    dns_service_ip = "172.16.0.10"
  }

  # Enable OIDC — needed for Workload Identity (Vault, ArgoCD auth)
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  tags = {
    Environment = var.env
    ManagedBy   = "Terraform"
    Project     = "RoboShop"
  }
}

# Workload node pool — runs all RoboShop microservices
# Separate from system pool so K8s system pods are never evicted
resource "azurerm_kubernetes_cluster_node_pool" "workload" {
  name                  = "workload"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.roboshop.id
  vm_size               = var.workload_node_size
  enable_auto_scaling   = true
  min_count             = var.workload_min_count
  max_count             = var.workload_max_count
  mode                  = "User"   # user pool = for application workloads

  upgrade_settings {
    max_surge = "33%"
  }

  tags = {
    Environment = var.env
    Pool        = "workload"
  }
}

# Give AKS permission to pull from ACR — no credentials needed
# AKS uses its managed identity to authenticate to ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.roboshop.kubelet_identity[0].object_id
}