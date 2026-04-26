variable "env" {
  description = "Environment name — dev, staging, prod"
  type        = string
  default     = "dev"
}

variable "resource_groups" {
  description = "Map of resource groups to create"
  type = map(object({
    name     = string
    location = string
  }))
}

variable "vnets" {
  description = "Map of VNets to create"
  type = map(object({
    address_space = list(string)
    subnets = map(object({
      cidr = string
    }))
  }))
}

variable "aks" {
  description = "AKS cluster configuration"
  type = object({
    cluster_name        = string
    kubernetes_version  = string
    system_node_count   = number
    system_node_size    = string
    workload_min_count  = number
    workload_max_count  = number
    workload_node_size  = string
  })
}

variable "acr_name" {
  description = "Azure Container Registry name — must be globally unique"
  type        = string
}