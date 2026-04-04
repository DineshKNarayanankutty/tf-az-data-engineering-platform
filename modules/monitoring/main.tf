resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.prefix}-law"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = var.environment == "prod" ? 90 : 30
  daily_quota_gb      = var.environment == "prod" ? -1 : 5
  tags                = var.tags
}

resource "azurerm_monitor_action_group" "critical" {
  name                = "${local.prefix}-ag-critical"
  resource_group_name = var.resource_group_name
  short_name          = substr(replace("${var.environment}crit", "-", ""), 0, 12)
  tags                = var.tags

  email_receiver {
    name                    = "platform-team"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}
