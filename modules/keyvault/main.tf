data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                          = var.key_vault_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "premium"
  enable_rbac_authorization     = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 90
  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    # AzureServices bypass needed for:
    #   - Azure Monitor diagnostic log forwarding
    #   - ARM template deployments referencing KV (ADF ARM deploy)
    bypass = "AzureServices"
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Private Endpoint
# ---------------------------------------------------------------------------
resource "azurerm_private_endpoint" "keyvault" {
  name                = "${local.prefix}-pep-kv"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${local.prefix}-psc-kv"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "kv-dns"
    private_dns_zone_ids = [var.dns_zone_keyvault_id]
  }
}

# ---------------------------------------------------------------------------
# RBAC Assignments
# ---------------------------------------------------------------------------

# Terraform SP/user — needs Secrets Officer to bootstrap secrets during apply
resource "azurerm_role_assignment" "terraform_kv_administrator" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ADF UAMI — read secrets for linked services and pipelines
resource "azurerm_role_assignment" "adf_kv_secrets_user" {
  count = var.adf_principal_id != "" && var.adf_principal_id != null ? 1 : 0

  scope                            = azurerm_key_vault.main.id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = var.adf_principal_id
  skip_service_principal_aad_check = true
}

# Databricks Access Connector — read secrets for secret scopes
resource "azurerm_role_assignment" "databricks_kv_secrets_user" {
  count = var.databricks_connector_principal_id != "" && var.databricks_connector_principal_id != null ? 1 : 0

  scope                            = azurerm_key_vault.main.id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = var.databricks_connector_principal_id
  skip_service_principal_aad_check = true
}

# ---------------------------------------------------------------------------
# Diagnostics
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  name                       = "${var.key_vault_name}-diag"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_log {
    category = "AzurePolicyEvaluationDetails"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
