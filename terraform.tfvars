env                = "dev"
location           = "UK West"
project            = "roboshop"
resource_group_name = "rg-roboshop-dev"
acr_name           = "roboshopdevacr"      # must be globally unique
aks_cluster_name   = "roboshop-dev-aks"
kubernetes_version = "1.35.1"
system_node_size   = "Standard_B2s"
system_node_count  = 2
workload_node_size = "Standard_B4ms"
workload_min_count = 2
workload_max_count = 6
domain             = "roboshop.skilltechnology.online"# change this


# New values — add these
domain           = "roboshop.skilltechnology.online"  # CHANGE THIS to your real domain
email            = "aartichaple2124@gmail.com"
mongodb_password  = "Mongo@Roboshop123"
mysql_password    = "MySQL@Roboshop123"
rabbitmq_password = "RabbitMQ@Roboshop123"
grafana_password  = "Grafana@Roboshop123"
stripe_key        = "sk_test_placeholder"