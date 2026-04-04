variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "workspace_name" {
  type = string
}

variable "managed_resource_group_name" {
  type = string
}

variable "vnet_id" {
  type = string
}

variable "host_subnet_name" {
  type = string
}

variable "container_subnet_name" {
  type = string
}

variable "host_subnet_nsg_association_id" {
  type = string
}

variable "container_subnet_nsg_association_id" {
  type = string
}

variable "private_endpoint_subnet_id" {
  type = string
}

variable "dns_zone_databricks_id" {
  type = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
