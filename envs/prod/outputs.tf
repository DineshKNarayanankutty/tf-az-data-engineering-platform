output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "Deployed resource group name"
}

output "storage_account_name" {
  value       = module.storage.storage_account_name
  description = "ADLS Gen2 storage account name"
}

output "databricks_workspace_url" {
  value       = module.databricks.workspace_url
  description = "Databricks workspace URL"
}

output "key_vault_name" {
  value       = module.naming.names.kv
  description = "Key Vault name"
}

output "adf_name" {
  value       = module.naming.names.adf
  description = "ADF instance name"
}

output "log_analytics_workspace_id" {
  value       = module.monitoring.log_analytics_workspace_id
  description = "Log Analytics workspace ID"
}

output "unity_catalog_name" {
  value       = "${var.project}_${var.environment}"
  description = "Unity Catalog catalog name"
}

output "dev_cluster_id" {
  value       = module.databricks_unity.dev_cluster_id
  description = "Dev single-node cluster ID (null for staging/prod)"
}

output "etl_job_id" {
  value       = module.databricks_unity.etl_job_id
  description = "ETL job ID (null for dev)"
}
