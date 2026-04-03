output "storage_account_name" {
  value       = azurerm_storage_account.tfstate.name
  description = "Terraform state storage account name"
}

output "storage_account_id" {
  value       = azurerm_storage_account.tfstate.id
  description = "Terraform state storage account ARM resource ID"
}

output "resource_group_name" {
  value       = azurerm_resource_group.tfstate.name
  description = "Resource group holding the Terraform state backend"
}

output "container_names" {
  value       = { for k, v in azapi_resource.state_containers : k => v.name }
  description = "Map of environment → blob container name"
}

output "backend_config_snippet" {
  value = {
    for env, config in var.backend_states : env => {
      resource_group_name  = azurerm_resource_group.tfstate.name
      storage_account_name = azurerm_storage_account.tfstate.name
      container_name       = config.container_name
      key                  = try(config.key, "terraform.tfstate")
      use_oidc             = true
      use_azuread_auth     = true
    }
  }
  description = "Backend config values to paste into backend-config/*.hcl files"
}
