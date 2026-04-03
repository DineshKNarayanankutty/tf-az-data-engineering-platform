variable "resource_group_name" {
  description = "Resource group that hosts the remote state storage account."
  type        = string
  default     = "rg-terraform-state"
}

variable "location" {
  description = "Azure region for the backend resources."
  type        = string
  default     = "eastus2"
}

variable "name_prefix" {
  description = "Prefix used to derive the storage account name when no override is provided."
  type        = string
  default     = "dataplatform"
}

variable "name_suffix" {
  description = "Suffix used to keep the storage account name globally unique when no override is provided."
  type        = string
  default     = "dkn"
}

variable "storage_account_name_override" {
  description = "Optional explicit storage account name. When null, Terraform derives one from the prefix and suffix."
  type        = string
  default     = null

  validation {
    condition     = var.storage_account_name_override == null || can(regex("^[a-z0-9]{3,24}$", var.storage_account_name_override))
    error_message = "storage_account_name_override must be 3-24 lowercase alphanumeric characters."
  }
}

variable "backend_states" {
  description = "Per-environment backend container names and state blob keys."
  type = map(object({
    container_name = string
    key            = optional(string, "terraform.tfstate")
  }))

  default = {
    dev = {
      container_name = "dev"
    }
    stage = {
      container_name = "stage"
    }
    prod = {
      container_name = "prod"
    }
  }
}

variable "replication_type" {
  description = "Storage replication tier for the remote state account."
  type        = string
  default     = "GRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "RAGRS", "GZRS", "RAGZRS"], var.replication_type)
    error_message = "replication_type must be one of LRS, ZRS, GRS, RAGRS, GZRS, or RAGZRS."
  }
}

variable "public_network_access_enabled" {
  description = "Set to true only when you intentionally allow access through explicit IP or subnet rules."
  type        = bool
  default     = false
}

variable "allowed_ip_rules" {
  description = "Optional public IP allow list used only when public network access is enabled."
  type        = list(string)
  default     = []
}

variable "allowed_subnet_ids" {
  description = "Optional subnet allow list for service endpoint access."
  type        = list(string)
  default     = []
}

variable "network_bypass" {
  description = <<-EOT
    Storage network ACL bypass list.

    Azure's platform default for new storage accounts is ["AzureServices"], which allows:
      - Azure Monitor to export diagnostic logs
      - ARM deployments to access the account
      - Trusted Microsoft services (Defender, Backup, etc.)

    Setting this to [] causes a perpetual Terraform diff because Azure writes
    "AzureServices" into the resource on creation even if you didn't request it.

    For a Terraform state backend specifically, "AzureServices" is correct — you
    want Azure Monitor able to read metrics, and ARM able to manage the account.
    Only set to [] if you are enforcing an Azure Policy that explicitly denies it
    AND you have confirmed the account was created with that restriction already applied.
  EOT
  type        = list(string)
  default     = ["AzureServices"]
}

variable "shared_access_key_enabled" {
  description = "Break-glass option for key-based access. Keep false for Azure AD only access."
  type        = bool
  default     = false
}

variable "infrastructure_encryption_enabled" {
  description = "Enable infrastructure encryption in addition to service-side encryption. Turn this on for greenfield backends because enabling it later forces replacement."
  type        = bool
  default     = false
}

variable "change_feed_enabled" {
  description = "Enable blob change feed for additional audit history."
  type        = bool
  default     = false
}

variable "blob_soft_delete_retention_days" {
  description = "Retention period for deleted blob versions."
  type        = number
  default     = 30

  validation {
    condition     = var.blob_soft_delete_retention_days >= 1 && var.blob_soft_delete_retention_days <= 365
    error_message = "blob_soft_delete_retention_days must be between 1 and 365."
  }
}

variable "container_soft_delete_retention_days" {
  description = "Retention period for deleted containers."
  type        = number
  default     = 30

  validation {
    condition     = var.container_soft_delete_retention_days >= 1 && var.container_soft_delete_retention_days <= 365
    error_message = "container_soft_delete_retention_days must be between 1 and 365."
  }
}

variable "state_version_retention_days" {
  description = "Delete old blob versions after this many days. Set to 0 to disable lifecycle pruning."
  type        = number
  default     = 90

  validation {
    condition     = var.state_version_retention_days >= 0
    error_message = "state_version_retention_days must be zero or greater."
  }
}

variable "assign_current_client_blob_data_contributor" {
  description = "Grant the current Terraform identity Storage Blob Data Contributor on each backend container."
  type        = bool
  default     = true
}

variable "blob_data_contributor_principal_ids" {
  description = "Additional Microsoft Entra object IDs that should receive Storage Blob Data Contributor on each backend container."
  type        = list(string)
  default     = []
}

variable "rbac_propagation_wait" {
  description = "Optional settle delay between RBAC creation and the next pipeline stage."
  type        = string
  default     = "90s"

  validation {
    condition     = can(timeadd(timestamp(), var.rbac_propagation_wait))
    error_message = "rbac_propagation_wait must be a valid Terraform duration like 0s, 30s, or 2m."
  }
}

variable "enable_private_endpoint" {
  description = "Create a private endpoint for the blob service. Recommended when public network access is disabled."
  type        = bool
  default     = false
}

variable "private_endpoint_subnet_id" {
  description = "Subnet that hosts the storage account private endpoint."
  type        = string
  default     = null
}

variable "private_dns_zone_ids" {
  description = "Optional private DNS zones to attach to the private endpoint, such as privatelink.blob.core.windows.net."
  type        = list(string)
  default     = []
}

variable "private_endpoint_name_override" {
  description = "Optional explicit private endpoint name."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to backend resources."
  type        = map(string)
  default = {
    managed_by = "terraform-bootstrap"
    workload   = "terraform-backend"
  }
}
