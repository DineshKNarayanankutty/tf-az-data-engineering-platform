variable "resource_group_name" {
  type = string
}

variable "resource_group_id" {
  type = string
}

variable "location" {
  type = string
}

variable "storage_account_id" {
  type = string
}

variable "connector_name" {
  type = string
}

variable "adf_uami_name" {
  type = string
}

variable "existing_databricks_access_connector_name" {
  type    = string
  default = null
}

variable "existing_databricks_access_connector_resource_group_name" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
