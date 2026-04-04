variable "org" {
  type        = string
  description = "Organization short name"
}

variable "project" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
}

variable "location_short" {
  type        = string
  description = "Short location code (e.g. eus2)"
}

variable "owner" {
  type        = string
  description = "Owner team or person"
}

variable "cost_center" {
  type        = string
  description = "Cost center code"
}

variable "repository" {
  type        = string
  description = "Source repository name"
}

variable "extra_tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags to merge into the standard tag set"
}
