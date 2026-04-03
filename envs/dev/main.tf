module "naming" {
  source = "../../modules/naming"

  org            = var.org
  project        = var.project
  environment    = var.environment
  location_short = var.location_short
  owner          = var.owner
  cost_center    = var.cost_center
  repository     = var.repository
}

resource "azurerm_resource_group" "main" {
  name     = module.naming.names.rg
  location = var.location
  tags     = module.naming.tags
}

module "monitoring" {
  source = "../../modules/monitoring"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  environment         = var.environment
  project             = var.project
  alert_email         = var.alert_email
  tags                = module.naming.tags
}

module "networking" {
  source = "../../modules/networking"

  resource_group_name       = azurerm_resource_group.main.name
  location                  = var.location
  environment               = var.environment
  project                   = var.project
  vnet_cidr                 = var.vnet_cidr
  databricks_host_cidr      = var.databricks_host_cidr
  databricks_container_cidr = var.databricks_container_cidr
  private_endpoint_cidr     = var.private_endpoint_cidr
  tags                      = module.naming.tags
}

module "storage" {
  source = "../../modules/storage"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.location
  storage_account_name       = module.naming.names.stg
  replication_type           = var.replication_type
  enable_blob_versioning     = var.enable_blob_versioning
  delete_retention_days      = var.delete_retention_days
  tier_to_cool_days          = var.tier_to_cool_days
  tier_to_archive_days       = var.tier_to_archive_days
  delete_after_days          = var.delete_after_days
  allowed_subnet_ids         = [module.networking.databricks_host_subnet_id, module.networking.databricks_container_subnet_id, module.networking.private_endpoint_subnet_id]
  private_endpoint_subnet_id = module.networking.private_endpoint_subnet_id
  dns_zone_storage_blob_id   = module.networking.dns_zone_storage_blob_id
  dns_zone_storage_dfs_id    = module.networking.dns_zone_storage_dfs_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = module.naming.tags
}

module "security" {
  source = "../../modules/security"

  resource_group_name = azurerm_resource_group.main.name
  resource_group_id   = azurerm_resource_group.main.id
  location            = var.location
  storage_account_id  = module.storage.storage_account_id
  connector_name      = module.naming.names.dbw_connector
  adf_uami_name       = module.naming.names.adf_uami

  # If Databricks auto-created an Access Connector in the managed RG,
  # set these two variables in tfvars instead of leaving null.
  # The module will data-source the existing connector rather than create a new one.
  existing_databricks_access_connector_name                = var.existing_databricks_access_connector_name
  existing_databricks_access_connector_resource_group_name = var.existing_databricks_access_connector_resource_group_name

  tags = module.naming.tags
}

module "keyvault" {
  source = "../../modules/keyvault"

  resource_group_name               = azurerm_resource_group.main.name
  location                          = var.location
  environment                       = var.environment
  project                           = var.project
  key_vault_name                    = module.naming.names.kv
  private_endpoint_subnet_id        = module.networking.private_endpoint_subnet_id
  dns_zone_keyvault_id              = module.networking.dns_zone_keyvault_id
  log_analytics_workspace_id        = module.monitoring.log_analytics_workspace_id
  adf_principal_id                  = module.security.adf_user_assigned_identity_principal_id
  databricks_connector_principal_id = module.security.databricks_connector_principal_id
  tags                              = module.naming.tags
}

module "databricks" {
  source = "../../modules/databricks"

  resource_group_name                 = azurerm_resource_group.main.name
  location                            = var.location
  workspace_name                      = module.naming.names.dbw
  managed_resource_group_name         = "${module.naming.prefix}-dbw-mrg"
  vnet_id                             = module.networking.vnet_id
  host_subnet_name                    = module.networking.databricks_host_subnet_name
  container_subnet_name               = module.networking.databricks_container_subnet_name
  host_subnet_nsg_association_id      = module.networking.databricks_host_subnet_nsg_association_id
  container_subnet_nsg_association_id = module.networking.databricks_container_subnet_nsg_association_id
  private_endpoint_subnet_id          = module.networking.private_endpoint_subnet_id
  dns_zone_databricks_id              = module.networking.dns_zone_databricks_id
  log_analytics_workspace_id          = module.monitoring.log_analytics_workspace_id
  tags                                = module.naming.tags
}

module "databricks_unity" {
  source = "../../modules/databricks_unity"

  providers = {
    databricks = databricks.workspace
  }

  environment                     = var.environment
  storage_account_name            = module.storage.storage_account_name
  databricks_connector_id         = module.security.databricks_connector_id
  catalog_name                    = "${var.project}_${var.environment}"
  data_engineers_group            = var.data_engineers_group
  data_readers_group              = var.data_readers_group
  create_example_external_table   = var.create_example_external_table
  spark_version                   = var.spark_version
  dev_node_type                   = var.dev_node_type
  prod_node_type                  = var.prod_node_type
  pool_max_capacity               = var.pool_max_capacity
  job_min_workers                 = var.job_min_workers
  job_max_workers                 = var.job_max_workers
  job_notebook_path               = var.job_notebook_path
  tags                            = module.naming.tags

  # Metastore + workspace binding (required for Unity Catalog)
  metastore_id                    = var.metastore_id
  databricks_workspace_numeric_id = module.databricks.workspace_numeric_id

  # Dev single-node cluster: bind to this service principal / user
  cluster_single_user_name        = var.cluster_single_user_name

  # Pass RBAC propagation trigger so storage credential validation waits
  # for all 4 role assignments to settle (avoids "File Events" test failure)
  rbac_propagation_trigger        = module.security.rbac_propagation_trigger

  depends_on = [module.security, module.databricks, module.storage]
}

module "adf" {
  source = "../../modules/adf"

  resource_group_name           = azurerm_resource_group.main.name
  location                      = var.location
  adf_name                      = module.naming.names.adf
  adf_user_assigned_identity_id = module.security.adf_user_assigned_identity_id
  storage_account_id            = module.storage.storage_account_id
  storage_dfs_endpoint          = module.storage.primary_dfs_endpoint
  key_vault_id                  = module.keyvault.key_vault_id
  databricks_workspace_url      = module.databricks.workspace_url
  databricks_workspace_id       = module.databricks.workspace_id
  databricks_cluster_node_type  = var.prod_node_type
  databricks_cluster_version    = var.spark_version
  databricks_cluster_workers    = var.adf_databricks_cluster_workers
  storage_account_name          = module.storage.storage_account_name
  environment_name              = var.environment
  private_endpoint_subnet_id    = module.networking.private_endpoint_subnet_id
  dns_zone_adf_id               = module.networking.dns_zone_adf_id
  log_analytics_workspace_id    = module.monitoring.log_analytics_workspace_id
  tags                          = module.naming.tags

  depends_on = [module.databricks_unity, module.keyvault]
}

module "governance" {
  source = "../../modules/governance"

  enable_budget     = var.enable_budget
  budget_name       = var.budget_name
  subscription_id   = var.subscription_id
  budget_amount     = var.budget_amount
  budget_start_date = var.budget_start_date
  budget_end_date   = var.budget_end_date
  contact_emails    = var.budget_contact_emails
}
