output "databricks_connector_id" {
  value = local.databricks_connector_id
}

output "databricks_connector_principal_id" {
  value = local.databricks_connector_principal_id
}

output "adf_user_assigned_identity_id" {
  value = azurerm_user_assigned_identity.adf.id
}

output "adf_user_assigned_identity_principal_id" {
  value = azurerm_user_assigned_identity.adf.principal_id
}

# Exposes any role assignment resource ID as a propagation trigger.
# Pass this to the databricks_unity module to ensure RBAC settles before
# storage credentials are validated.
output "rbac_propagation_trigger" {
  value       = azurerm_role_assignment.uc_blob_data_contributor.id
  description = "A role assignment ID that can be used as a depends_on trigger for RBAC propagation"
}
