variable "resource_group_name" {
  type        = string
  description = "Resource group name"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "environment" {
  type        = string
  description = "Deployment environment (used in locals prefix)"
}

variable "project" {
  type        = string
  description = "Project name (used in locals prefix)"
}

variable "key_vault_name" {
  type        = string
  description = "Key Vault resource name"
}

variable "private_endpoint_subnet_id" {
  type        = string
  description = "Subnet ID for the Key Vault private endpoint"
}

variable "dns_zone_keyvault_id" {
  type        = string
  description = "Private DNS zone ID for privatelink.vaultcore.azure.net"
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics workspace ID for diagnostic settings"
}

variable "adf_principal_id" {
  type        = string
  default     = null
  description = "ADF User-Assigned Managed Identity principal ID"
}

variable "databricks_connector_principal_id" {
  type        = string
  default     = null
  description = "Databricks Access Connector principal ID"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags"
}
