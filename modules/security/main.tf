# =============================================================================
# MODULE: security
# Purpose: Databricks Access Connector handling, managed identities, RBAC
# =============================================================================

locals {
  use_existing_connector = var.existing_databricks_access_connector_name != null && var.existing_databricks_access_connector_resource_group_name != null
}

data "azurerm_databricks_access_connector" "existing" {
  count = local.use_existing_connector ? 1 : 0

  name                = var.existing_databricks_access_connector_name
  resource_group_name = var.existing_databricks_access_connector_resource_group_name
}

resource "azurerm_databricks_access_connector" "managed" {
  count = local.use_existing_connector ? 0 : 1

  name                = var.connector_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_user_assigned_identity" "adf" {
  name                = var.adf_uami_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

locals {
  databricks_connector_id = coalesce(
    try(data.azurerm_databricks_access_connector.existing[0].id, null),
    try(azurerm_databricks_access_connector.managed[0].id, null)
  )

  databricks_connector_principal_id = coalesce(
    try(data.azurerm_databricks_access_connector.existing[0].identity[0].principal_id, null),
    try(azurerm_databricks_access_connector.managed[0].identity[0].principal_id, null)
  )
}

# Required Unity Catalog + File Events roles at Storage Account scope
resource "azurerm_role_assignment" "uc_blob_data_contributor" {
  scope                            = var.storage_account_id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = local.databricks_connector_principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "uc_storage_account_contributor" {
  scope                            = var.storage_account_id
  role_definition_name             = "Storage Account Contributor"
  principal_id                     = local.databricks_connector_principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "uc_eventgrid_eventsubscription_contributor" {
  scope                            = var.storage_account_id
  role_definition_name             = "EventGrid EventSubscription Contributor"
  principal_id                     = local.databricks_connector_principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "uc_storage_queue_data_contributor" {
  scope                            = var.storage_account_id
  role_definition_name             = "Storage Queue Data Contributor"
  principal_id                     = local.databricks_connector_principal_id
  skip_service_principal_aad_check = true
}

# ADF storage access
resource "azurerm_role_assignment" "adf_storage_blob_data_contributor" {
  scope                            = var.storage_account_id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = azurerm_user_assigned_identity.adf.principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "adf_rg_reader" {
  scope                            = var.resource_group_id
  role_definition_name             = "Reader"
  principal_id                     = azurerm_user_assigned_identity.adf.principal_id
  skip_service_principal_aad_check = true
}
