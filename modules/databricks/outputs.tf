output "workspace_id" {
  value = azurerm_databricks_workspace.main.id
}

output "workspace_url" {
  value = azurerm_databricks_workspace.main.workspace_url
}

output "workspace_numeric_id" {
  value       = azurerm_databricks_workspace.main.workspace_id
  description = "Numeric workspace ID (required for metastore assignment)"
}
