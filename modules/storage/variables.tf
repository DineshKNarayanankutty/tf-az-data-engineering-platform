variable "resource_group_name" {
  type        = string
  description = "Resource group name"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "storage_account_name" {
  type        = string
  description = "Storage account name (3-24 lowercase alphanumeric)"
}

variable "replication_type" {
  type        = string
  description = "Storage replication type (LRS / ZRS / GRS / GZRS)"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "GZRS", "RA-GRS", "RA-GZRS"], var.replication_type)
    error_message = "replication_type must be one of: LRS, ZRS, GRS, GZRS, RA-GRS, RA-GZRS"
  }
}

variable "enable_blob_versioning" {
  type        = bool
  default     = true
  description = "Enable blob versioning"
}

variable "delete_retention_days" {
  type        = number
  default     = 7
  description = "Soft-delete retention days for blobs and containers"

  validation {
    condition     = var.delete_retention_days >= 1 && var.delete_retention_days <= 365
    error_message = "delete_retention_days must be between 1 and 365"
  }
}

variable "tier_to_cool_days" {
  type        = number
  default     = 30
  description = "Days since last modification before tiering bronze blobs to Cool"
}

variable "tier_to_archive_days" {
  type        = number
  default     = 90
  description = "Days since last modification before tiering bronze blobs to Archive"
}

variable "delete_after_days" {
  type        = number
  default     = 365
  description = "Days since last modification before deleting blobs"
}

variable "allowed_subnet_ids" {
  type        = list(string)
  default     = []
  description = "Subnet IDs allowed to access the storage account via service endpoints"
}

variable "private_endpoint_subnet_id" {
  type        = string
  description = "Subnet ID for storage private endpoints"
}

variable "dns_zone_storage_blob_id" {
  type        = string
  description = "Private DNS zone ID for privatelink.blob.core.windows.net"
}

variable "dns_zone_storage_dfs_id" {
  type        = string
  description = "Private DNS zone ID for privatelink.dfs.core.windows.net"
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics workspace ID for diagnostic settings"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags"
}
