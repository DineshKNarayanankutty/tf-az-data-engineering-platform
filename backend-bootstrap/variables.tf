variable "resource_group_name" {
  type    = string
  default = "rg-terraform-state"
}

variable "location" {
  type    = string
  default = "eastus2"
}

variable "storage_account_name" {
  type    = string
  default = "tfstatedataplatform"
}

variable "container_name" {
  type    = string
  default = "tfstate"
}

variable "replication_type" {
  type    = string
  default = "GRS"
}

variable "public_network_access_enabled" {
  type    = bool
  default = false
}

variable "allowed_ip_rules" {
  type    = list(string)
  default = []
}

variable "tags" {
  type = map(string)
  default = {
    managed_by = "terraform-bootstrap"
  }
}
