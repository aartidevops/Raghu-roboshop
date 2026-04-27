variable "domain" {
  type        = string
  description = "Base domain e.g. roboshop.yourdomain.com"
}

variable "email" {
  type        = string
  description = "Email for Let's Encrypt cert notifications"
}

variable "azure_keyvault_id" {
  type        = string
  description = "Azure Key Vault resource ID for storing Vault init keys"
}

variable "azure_keyvault_name" {
  type        = string
  description = "Azure Key Vault name"
}

variable "mongodb_password" {
  type      = string
  sensitive = true
  default   = "Mongo@Roboshop123"
}

variable "mysql_password" {
  type      = string
  sensitive = true
  default   = "MySQL@Roboshop123"
}

variable "rabbitmq_password" {
  type      = string
  sensitive = true
  default   = "RabbitMQ@Roboshop123"
}

variable "stripe_key" {
  type      = string
  sensitive = true
  default   = "sk_test_placeholder"
}

variable "grafana_password" {
  type      = string
  sensitive = true
  default   = "Grafana@Roboshop123"
}