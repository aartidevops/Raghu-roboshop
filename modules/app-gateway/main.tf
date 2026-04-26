resource "azurerm_public_ip" "agw" {
  name                = "pip-agw-${var.env}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_application_gateway" "this" {
  name                = "agw-${var.project}-${var.env}"
  resource_group_name = var.resource_group_name
  location            = var.location

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1   # fixed capacity for dev (cheaper than autoscale min)
  }

  gateway_ip_configuration {
    name      = "gw-ip-config"
    subnet_id = var.agw_subnet_id
  }

  frontend_port {
    name = "port-80"
    port = 80
  }

  frontend_port {
    name = "port-443"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "public-ip-config"
    public_ip_address_id = azurerm_public_ip.agw.id
  }

  # Placeholder backend pool — AGIC will manage all routing after this
  # We need at least one valid backend/listener/rule for Terraform to create AGW
  backend_address_pool {
    name = "placeholder-pool"
  }

  backend_http_settings {
    name                  = "placeholder-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
  }

  http_listener {
    name                           = "placeholder-listener"
    frontend_ip_configuration_name = "public-ip-config"
    frontend_port_name             = "port-80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "placeholder-rule"
    rule_type                  = "Basic"
    http_listener_name         = "placeholder-listener"
    backend_address_pool_name  = "placeholder-pool"
    backend_http_settings_name = "placeholder-settings"
    priority                   = 1000
  }

  waf_configuration {
    enabled          = true
    firewall_mode    = "Detection"  # use Prevention in prod
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }

  # CRITICAL: AGIC manages all routing config after initial creation
  # Without ignore_changes, Terraform fights AGIC on every plan
  lifecycle {
    ignore_changes = [
      backend_address_pool,
      backend_http_settings,
      http_listener,
      request_routing_rule,
      probe,
      url_path_map,
      redirect_configuration,
      ssl_certificate,
      tags,
    ]
  }

  tags = var.tags
}