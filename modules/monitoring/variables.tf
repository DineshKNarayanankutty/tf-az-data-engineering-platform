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
  description = "Deployment environment"
}

variable "project" {
  type        = string
  description = "Project name"
}

variable "alert_email" {
  type        = string
  description = "Email address for alert notifications"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags"
}
