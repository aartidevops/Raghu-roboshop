variable "env" {
  type    = string
  default = "dev"
}

variable "location" {
  type    = string
  default = "UK West"
}

variable "project" {
  type    = string
  default = "roboshop"
}

variable "resource_group_name" {
  type    = string
  default = "rg-roboshop-dev"
}

variable "vnet_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "aks_subnet_cidr" {
  type    = string
  default = "10.0.0.0/22"
}

variable "agw_subnet_cidr" {
  type    = string
  default = "10.0.8.0/24"
}

variable "acr_name" {
  type        = string
  description = "Globally unique. No hyphens. Max 50 chars."
  default     = "roboshopdevacr"
}

variable "aks_cluster_name" {
  type    = string
  default = "roboshop-dev-aks"
}

variable "kubernetes_version" {
  type    = string
  default = "1.35.2"
}

variable "system_node_size" {
  type    = string
  default = "Standard_B2s"
}

variable "system_node_count" {
  type    = number
  default = 2
}

variable "workload_node_size" {
  type    = string
  default = "Standard_B4ms"
}

variable "workload_min_count" {
  type    = number
  default = 2
}

variable "workload_max_count" {
  type    = number
  default = 6
}

variable "domain" {
  type        = string
  description = "Your base domain e.g. roboshop.example.com"
  default     = "roboshop.skilltechnology.online"
}

variable "tags" {
  type = map(string)
  default = {
    Project   = "roboshop"
    ManagedBy = "Terraform"
  }
}

