output "agw_id"        { value = azurerm_application_gateway.this.id }
output "agw_name"      { value = azurerm_application_gateway.this.name }
output "public_ip"     { value = azurerm_public_ip.agw.ip_address }
output "public_ip_id"  { value = azurerm_public_ip.agw.id }