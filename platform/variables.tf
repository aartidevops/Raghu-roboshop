variable "domain" {
  type    = string
  default = "skilltechnology.online"
}

variable "email" {
  type    = string
  default = "aartichaple2124@gmail.com"
}

variable "grafana_password" {
  type      = string
  sensitive = true
  default   = "Grafana@Roboshop123"
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