output "storage_account_id" {
  value       = azurerm_storage_account.adls.id
  description = "ARM resource ID of the ADLS Gen2 storage account"
}

output "storage_account_name" {
  value       = azurerm_storage_account.adls.name
  description = "Storage account name"
}

output "primary_dfs_endpoint" {
  value       = azurerm_storage_account.adls.primary_dfs_endpoint
  description = "Primary DFS (abfss://) endpoint"
}

output "storage_account_principal_id" {
  value       = azurerm_storage_account.adls.identity[0].principal_id
  description = "System-assigned managed identity principal ID of the storage account"
}
