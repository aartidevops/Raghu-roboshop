env = "dev"

resource_groups = {
  main = {
    name     = "rg-roboshop-dev"
    location = "East US"
  }
}

vnets = {
  main = {
    address_space = ["10.0.0.0/16"]
    subnets = {
      aks-system   = { cidr = "10.0.1.0/24" }
      aks-workload = { cidr = "10.0.2.0/23" }  # /23 = 512 IPs for pods
    }
  }
}

aks = {
  cluster_name       = "roboshop-dev-aks"
  kubernetes_version = "1.30.2"
  system_node_count  = 2
  system_node_size   = "Standard_B2s"     # cheap for dev
  workload_min_count = 2
  workload_max_count = 5
  workload_node_size = "Standard_B4ms"    # enough for all 10 services
}

acr_name = "roboshopdevacr"  # change to something unique — no hyphens allowed