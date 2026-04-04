output "log_analytics_workspace_id" {
  value       = azurerm_log_analytics_workspace.main.id
  description = "Log Analytics workspace ARM resource ID"
}

output "log_analytics_workspace_name" {
  value       = azurerm_log_analytics_workspace.main.name
  description = "Log Analytics workspace name"
}

output "action_group_id" {
  value       = azurerm_monitor_action_group.critical.id
  description = "Monitor action group ARM resource ID"
}
