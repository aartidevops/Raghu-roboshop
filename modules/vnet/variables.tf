# variable "rg_name" {}
# variable "rg_location" {}
# variable "address_space" {}
# variable "env" {}
# variable "subnets" {}




variable "env" {
  type = string
}

variable "rg_name" {
  type = string
}

variable "rg_location" {
  type = string
}

variable "vnet_config" {
  type = object({
    address_space = list(string)

    subnets = map(object({
      cidr = string
    }))
  })
}