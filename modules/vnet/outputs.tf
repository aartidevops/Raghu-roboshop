output "subnet_ids" {
  value = azurerm_subnet.main.*.id
}