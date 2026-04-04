variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "environment" {
  type = string
}

variable "project" {
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

variable "tags" {
  type    = map(string)
  default = {}
}
