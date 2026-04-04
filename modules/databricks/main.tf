resource "azurerm_databricks_workspace" "main" {
  name                        = var.workspace_name
  resource_group_name         = var.resource_group_name
  location                    = var.location
  sku                         = "premium"
  managed_resource_group_name = var.managed_resource_group_name

  public_network_access_enabled         = false
  network_security_group_rules_required = "AllRules"
  tags                                  = var.tags

  custom_parameters {
    no_public_ip                                         = true
    virtual_network_id                                   = var.vnet_id
    public_subnet_name                                   = var.host_subnet_name
    private_subnet_name                                  = var.container_subnet_name
    public_subnet_network_security_group_association_id  = var.host_subnet_nsg_association_id
    private_subnet_network_security_group_association_id = var.container_subnet_nsg_association_id
  }
}

resource "azurerm_private_endpoint" "databricks_ui_api" {
  name                = "${var.workspace_name}-pep-uiapi"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.workspace_name}-psc-uiapi"
    private_connection_resource_id = azurerm_databricks_workspace.main.id
    subresource_names              = ["databricks_ui_api"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "databricks-dns"
    private_dns_zone_ids = [var.dns_zone_databricks_id]
  }
}

resource "azurerm_monitor_diagnostic_setting" "databricks" {
  name                       = "${var.workspace_name}-diag"
  target_resource_id         = azurerm_databricks_workspace.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
