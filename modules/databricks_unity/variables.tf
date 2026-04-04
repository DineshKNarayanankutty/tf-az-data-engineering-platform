variable "environment" {
  type        = string
  description = "Deployment environment (dev / staging / prod)"
}

variable "storage_account_name" {
  type        = string
  description = "ADLS Gen2 storage account name"
}

variable "databricks_connector_id" {
  type        = string
  description = "ARM resource ID of the Databricks Access Connector"
}

variable "catalog_name" {
  type        = string
  description = "Unity Catalog catalog name (e.g. dataplatform_dev)"
}

variable "data_engineers_group" {
  type        = string
  description = "Databricks group name for data engineers"
}

variable "data_readers_group" {
  type        = string
  description = "Databricks group name for data readers"
}

variable "create_example_external_table" {
  type        = bool
  default     = false
  description = "Whether to create an example external Delta table for validation"
}

variable "spark_version" {
  type        = string
  description = "Databricks Runtime version string (e.g. 15.4.x-scala2.12)"
}

variable "dev_node_type" {
  type        = string
  description = "VM SKU for dev single-node interactive cluster"
}

variable "prod_node_type" {
  type        = string
  description = "VM SKU for prod/staging job clusters"
}

variable "pool_max_capacity" {
  type        = number
  description = "Maximum instances in the prod instance pool"
}

variable "job_min_workers" {
  type        = number
  description = "Minimum autoscale workers for ETL job clusters"
}

variable "job_max_workers" {
  type        = number
  description = "Maximum autoscale workers for ETL job clusters"
}

variable "job_notebook_path" {
  type        = string
  description = "Workspace path where the ETL notebook will be deployed"
}

# New required vars added in this fix
variable "metastore_id" {
  type        = string
  description = "Unity Catalog metastore ID to assign to this workspace"
}

variable "databricks_workspace_numeric_id" {
  type        = string
  description = "Numeric workspace ID (azurerm_databricks_workspace.workspace_id, not ARM resource ID)"
}

variable "cluster_single_user_name" {
  type        = string
  default     = null
  description = "Service principal or user email to bind the dev single-user cluster to"
}

variable "rbac_propagation_trigger" {
  type        = any
  default     = null
  description = "Pass any RBAC role assignment resource ID here to create an implicit depends_on for RBAC propagation"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags"
}
