variable "org" {
  type = string
}

variable "project" {
  type = string
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "location" {
  type = string
}

variable "location_short" {
  type = string
}

variable "owner" {
  type = string
}

variable "cost_center" {
  type = string
}

variable "repository" {
  type = string
}

variable "alert_email" {
  type = string
}

variable "vnet_cidr" {
  type = string
}

variable "databricks_host_cidr" {
  type = string
}

variable "databricks_container_cidr" {
  type = string
}

variable "private_endpoint_cidr" {
  type = string
}

variable "replication_type" {
  type = string
}

variable "enable_blob_versioning" {
  type = bool
}

variable "delete_retention_days" {
  type = number
}

variable "tier_to_cool_days" {
  type = number
}

variable "tier_to_archive_days" {
  type = number
}

variable "delete_after_days" {
  type = number
}

variable "data_engineers_group" {
  type = string
}

variable "data_readers_group" {
  type = string
}

variable "create_example_external_table" {
  type    = bool
  default = false
}

variable "spark_version" {
  type = string
}

variable "dev_node_type" {
  type = string
}

variable "prod_node_type" {
  type = string
}

variable "pool_max_capacity" {
  type = number
}

variable "job_min_workers" {
  type = number
}

variable "job_max_workers" {
  type = number
}

variable "job_notebook_path" {
  type = string
}

variable "adf_databricks_cluster_workers" {
  type    = number
  default = 2
}

variable "enable_budget" {
  type    = bool
  default = false
}

variable "budget_name" {
  type    = string
  default = ""
}

variable "subscription_id" {
  type    = string
  default = ""
}

variable "budget_amount" {
  type    = number
  default = 0
}

variable "budget_start_date" {
  type    = string
  default = "2026-01-01T00:00:00Z"
}

variable "budget_end_date" {
  type    = string
  default = "2027-01-01T00:00:00Z"
}

variable "budget_contact_emails" {
  type    = list(string)
  default = []
}
