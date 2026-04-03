variable "org" {
  type        = string
  description = "Organization short name used in resource naming"
}

variable "project" {
  type        = string
  description = "Project name used in resource naming"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev / staging / prod)"
}

variable "location" {
  type        = string
  description = "Azure region (e.g. East US 2)"
}

variable "location_short" {
  type        = string
  description = "Short location code for naming (e.g. eus2)"
}

variable "owner" {
  type        = string
  description = "Team / person responsible for this deployment"
}

variable "cost_center" {
  type        = string
  description = "Cost center code for billing tags"
}

variable "repository" {
  type        = string
  description = "Source repository name for tags"
}

variable "alert_email" {
  type        = string
  description = "Email address for monitoring alerts"
}

# Networking
variable "vnet_cidr" {
  type        = string
  description = "CIDR block for the main VNet"
}

variable "databricks_host_cidr" {
  type        = string
  description = "CIDR for the Databricks host (public) subnet"
}

variable "databricks_container_cidr" {
  type        = string
  description = "CIDR for the Databricks container (private) subnet"
}

variable "private_endpoint_cidr" {
  type        = string
  description = "CIDR for the private endpoint subnet"
}

# Storage
variable "replication_type" {
  type        = string
  description = "Storage replication type (LRS / ZRS / GRS / GZRS)"
}

variable "enable_blob_versioning" {
  type        = bool
  description = "Enable blob versioning on the ADLS account"
}

variable "delete_retention_days" {
  type        = number
  description = "Soft-delete retention days for blobs and containers"
}

variable "tier_to_cool_days" {
  type        = number
  description = "Days since last modification before tiering bronze blobs to Cool"
}

variable "tier_to_archive_days" {
  type        = number
  description = "Days since last modification before tiering bronze blobs to Archive"
}

variable "delete_after_days" {
  type        = number
  description = "Days since last modification before deleting blobs"
}

# Databricks / Unity Catalog
variable "data_engineers_group" {
  type        = string
  description = "Databricks group name for data engineers"
}

variable "data_readers_group" {
  type        = string
  description = "Databricks group name for data readers (read-only)"
}

variable "create_example_external_table" {
  type        = bool
  default     = false
  description = "Whether to create an example external Delta table for validation"
}

variable "spark_version" {
  type        = string
  description = "Databricks Runtime version (e.g. 15.4.x-scala2.12)"
}

variable "dev_node_type" {
  type        = string
  description = "VM SKU for the dev single-node interactive cluster"
}

variable "prod_node_type" {
  type        = string
  description = "VM SKU for prod / staging job clusters and the ADF new-cluster config"
}

variable "pool_max_capacity" {
  type        = number
  description = "Max capacity of the prod instance pool"
}

variable "job_min_workers" {
  type        = number
  description = "Minimum autoscale workers for the ETL job cluster"
}

variable "job_max_workers" {
  type        = number
  description = "Maximum autoscale workers for the ETL job cluster"
}

variable "job_notebook_path" {
  type        = string
  description = "Workspace path where the ETL notebook is deployed"
}

# Unity Catalog — metastore binding
variable "metastore_id" {
  type        = string
  description = "Unity Catalog metastore ID to assign to this workspace. Find with: databricks metastores list"
}

variable "cluster_single_user_name" {
  type        = string
  default     = null
  description = "Service principal application ID or user email to bind to the dev single-user cluster (required for SINGLE_USER data security mode)"
}

# Access Connector — optional existing connector passthrough
# Set these if Databricks auto-created an Access Connector in the managed RG.
variable "existing_databricks_access_connector_name" {
  type        = string
  default     = null
  description = "Name of an existing Databricks Access Connector to use (leave null to create a new one)"
}

variable "existing_databricks_access_connector_resource_group_name" {
  type        = string
  default     = null
  description = "Resource group of the existing Access Connector (leave null to create a new one)"
}

# ADF
variable "adf_databricks_cluster_workers" {
  type        = number
  default     = 2
  description = "Number of workers for ADF new-cluster config"
}

# Governance / Budget
variable "enable_budget" {
  type        = bool
  default     = false
  description = "Whether to create a subscription budget alert"
}

variable "budget_name" {
  type        = string
  default     = ""
  description = "Name of the consumption budget"
}

variable "subscription_id" {
  type        = string
  default     = ""
  description = "Subscription ID for the budget scope"
}

variable "budget_amount" {
  type        = number
  default     = 0
  description = "Monthly budget amount in USD"
}

variable "budget_start_date" {
  type        = string
  default     = "2026-01-01T00:00:00Z"
  description = "Budget start date (RFC3339)"
}

variable "budget_end_date" {
  type        = string
  default     = "2027-01-01T00:00:00Z"
  description = "Budget end date (RFC3339)"
}

variable "budget_contact_emails" {
  type        = list(string)
  default     = []
  description = "Email addresses for budget threshold notifications"
}
