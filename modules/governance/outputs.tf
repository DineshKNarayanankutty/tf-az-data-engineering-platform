output "budget_id" {
  value       = var.enable_budget ? azurerm_consumption_budget_subscription.main[0].id : null
  description = "Consumption budget ARM resource ID (null if budget disabled)"
}
