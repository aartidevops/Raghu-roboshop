env = "dev"
# components = {
#
#   frontend = {
#     name      = "frontend"
#     vm_size   = "Standard_DS1_v2"
#     container = true
#   }
#
#   mongodb = {
#     name      = "mongodb"
#     vm_size   = "Standard_DS1_v2"
#     container = false
#   }
#
#   catalogue = {
#     name      = "catalogue"
#     vm_size   = "Standard_DS1_v2"
#     container = true
#   }
#
#   user = {
#     name      = "user"
#     vm_size   = "Standard_DS1_v2"
#     container = true
#   }
#
#   cart = {
#     name      = "cart"
#     vm_size   = "Standard_DS1_v2"
#     container = true
#   }
#
#   mysql = {
#     name      = "mysql"
#     vm_size   = "Standard_DS1_v2"
#     container = false
#   }
#
#   shipping = {
#     name      = "shipping"
#     vm_size   = "Standard_DS1_v2"
#     container = true
#   }
#
#   payment = {
#     name      = "payment"
#     vm_size   = "Standard_DS1_v2"
#     container = true
#   }
#
#   rabbitmq = {
#     name      = "rabbitmq"
#     vm_size   = "Standard_DS1_v2"
#     container = false
#   }
#
#   redis = {
#     name      = "redis"
#     vm_size   = "Standard_DS1_v2"
#     container = false
#   }
# }

databases = {

  mongodb = {
    name      = "mongodb"
    vm_size   = "Standard_B4ms"
    container = false
    port      = 27017
  }

  mysql = {
    name      = "mysql"
    vm_size   = "Standard_B4ms"
    container = false
    port      = 3306
  }

  rabbitmq = {
    name      = "rabbitmq"
    vm_size   = "Standard_B4ms"
    container = false
    port      = 5672
  }

  redis = {
    name      = "redis"
    vm_size   = "Standard_D2as_v4"
    container = false
    port      = 6379
  }

}

resource_groups = {
  main = {
    name     = "dev"
    location = "UK West"
  }
}

vnets = {
  main = {
    address_space = ["10.1.0.0/16"]
    subnets       = ["10.1.1.0/24"]
  }
}

aks = {
  main = {

  }
}
#
#
# bastion_node = ["10.1.0.4/32", "10.1.0.7/32"]