variable "resource_group_name" {
  type        = string
  description = "Resource group to deploy ADF into"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "adf_name" {
  type        = string
  description = "ADF instance name"
}

variable "adf_user_assigned_identity_id" {
  type        = string
  description = "ARM resource ID of the ADF User-Assigned Managed Identity"
}

variable "storage_account_id" {
  type        = string
  description = "ARM resource ID of the ADLS Gen2 storage account"
}

variable "storage_dfs_endpoint" {
  type        = string
  description = "Primary DFS endpoint URL (e.g. https://<name>.dfs.core.windows.net/)"
}

variable "storage_account_name" {
  type        = string
  description = "Storage account name (used as pipeline parameter)"
}

variable "key_vault_id" {
  type        = string
  description = "ARM resource ID of the Key Vault for linked service"
}

variable "databricks_workspace_url" {
  type        = string
  description = "Databricks workspace URL (without https://)"
}

variable "databricks_workspace_id" {
  type        = string
  description = "ARM resource ID of the Databricks workspace"
}

variable "databricks_cluster_node_type" {
  type        = string
  description = "VM SKU for ADF-triggered Databricks job clusters"
}

variable "databricks_cluster_version" {
  type        = string
  description = "Databricks Runtime version string"
}

variable "databricks_cluster_workers" {
  type        = number
  description = "Min workers for ADF-triggered job cluster"
}

variable "private_endpoint_subnet_id" {
  type        = string
  description = "Subnet ID for the ADF private endpoint"
}

variable "dns_zone_adf_id" {
  type        = string
  description = "Private DNS zone ID for privatelink.datafactory.azure.net"
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics workspace ID for diagnostic settings"
}

# Pipeline-specific parameters
variable "http_source_base_url" {
  type        = string
  default     = "https://people.sc.fsu.edu"
  description = "Base URL for the HTTP source linked service"
}

variable "http_source_relative_url" {
  type        = string
  default     = "/~jburkardt/data/csv/addresses.csv"
  description = "Relative path appended to the base URL for the source dataset"
}

variable "etl_notebook_path" {
  type        = string
  default     = "/Shared/pipelines/bronze_to_silver_gold"
  description = "Databricks notebook path triggered after Copy activity"
}

variable "environment_name" {
  type        = string
  default     = "dev"
  description = "Environment name passed as notebook base parameter"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags"
}
