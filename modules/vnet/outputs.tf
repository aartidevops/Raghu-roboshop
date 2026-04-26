# output "subnet_ids" {
#   value = azurerm_subnet.main.*.id
# }

output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "subnet_ids" {
  value = {
    for k, v in azurerm_subnet.main : k => v.id
  }
}