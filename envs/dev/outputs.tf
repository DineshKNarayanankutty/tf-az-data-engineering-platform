output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "storage_account_name" {
  value = module.storage.storage_account_name
}

output "databricks_workspace_url" {
  value = module.databricks.workspace_url
}

output "unity_catalog_name" {
  value = module.databricks_unity.catalog_name
}

output "key_vault_name" {
  value = module.keyvault.key_vault_name
}

output "adf_name" {
  value = module.adf.adf_name
}
