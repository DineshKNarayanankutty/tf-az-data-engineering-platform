terraform {
  required_version = ">= 1.8.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
    azapi = {
      source = "Azure/azapi"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}

# Required when shared keys are disabled, otherwise AzureRM still falls back
# to key-based auth for some storage data-plane reads during refresh.
provider "azurerm" {
  features {}
  use_oidc            = true
  storage_use_azuread = true
}

provider "azapi" {
  enable_preflight = true
}

data "azurerm_client_config" "current" {}

locals {
  storage_account_name = coalesce(
    var.storage_account_name_override,
    substr(
      replace(
        lower(join("", compact(["tfstate", var.name_prefix, var.name_suffix]))),
        "/[^a-z0-9]/",
        ""
      ),
      0,
      24
    )
  )

  backend_states = {
    for environment, config in var.backend_states : environment => {
      container_name = config.container_name
      key            = try(config.key, "terraform.tfstate")
    }
  }

  blob_service_parent_id = "${azurerm_storage_account.tfstate.id}/blobServices/default"

  blob_data_principal_ids = toset(distinct(compact(concat(
    var.blob_data_contributor_principal_ids,
    var.assign_current_client_blob_data_contributor ? [data.azurerm_client_config.current.object_id] : []
  ))))

  blob_data_contributor_assignments = {
    for pair in setproduct(keys(local.backend_states), tolist(local.blob_data_principal_ids)) :
    "${pair[0]}-${pair[1]}" => {
      environment  = pair[0]
      principal_id = pair[1]
    }
  }
}

check "storage_account_name_is_valid" {
  assert {
    condition     = can(regex("^[a-z0-9]{3,24}$", local.storage_account_name))
    error_message = "The computed storage account name must be 3-24 lowercase alphanumeric characters."
  }
}

check "backend_states_are_defined" {
  assert {
    condition     = length(local.backend_states) > 0
    error_message = "At least one backend state definition is required."
  }
}

check "container_names_are_valid" {
  assert {
    condition = alltrue([
      for config in values(local.backend_states) :
      can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", config.container_name)) &&
      !strcontains(config.container_name, "--")
    ])
    error_message = "Each container name must be 3-63 chars, lowercase alphanumeric or hyphen, and cannot contain consecutive hyphens."
  }
}

check "private_endpoint_inputs_are_valid" {
  assert {
    condition     = !var.enable_private_endpoint || var.private_endpoint_subnet_id != null
    error_message = "Set private_endpoint_subnet_id when enable_private_endpoint is true."
  }
}

resource "azurerm_resource_group" "tfstate" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "tfstate" {
  name                              = local.storage_account_name
  resource_group_name               = azurerm_resource_group.tfstate.name
  location                          = azurerm_resource_group.tfstate.location
  account_kind                      = "StorageV2"
  account_tier                      = "Standard"
  account_replication_type          = var.replication_type
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  allow_nested_items_to_be_public   = false
  public_network_access_enabled     = var.public_network_access_enabled
  shared_access_key_enabled         = var.shared_access_key_enabled
  default_to_oauth_authentication   = true
  infrastructure_encryption_enabled = var.infrastructure_encryption_enabled
  cross_tenant_replication_enabled  = false
  local_user_enabled                = false
  sftp_enabled                      = false

  blob_properties {
    change_feed_enabled = var.change_feed_enabled
    versioning_enabled  = true

    delete_retention_policy {
      days = var.blob_soft_delete_retention_days
    }

    container_delete_retention_policy {
      days = var.container_soft_delete_retention_days
    }
  }

  network_rules {
    default_action             = "Deny"
    bypass                     = var.network_bypass
    ip_rules                   = var.allowed_ip_rules
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }

  tags = merge(var.tags, {
    component = "terraform-backend"
  })
}

# Use the ARM control plane for container creation so bootstrap does not depend
# on storage data-plane auth or immediate RBAC propagation.
resource "azapi_resource" "state_containers" {
  for_each = local.backend_states

  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01"
  name      = each.value.container_name
  parent_id = local.blob_service_parent_id

  body = {
    properties = {
      metadata = {
        environment = each.key
        managedby   = "terraform"
      }
      publicAccess = "None"
    }
  }
}

resource "azurerm_role_assignment" "blob_data_contributor" {
  for_each = local.blob_data_contributor_assignments

  scope                = azapi_resource.state_containers[each.value.environment].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value.principal_id
}

# Terraform finishes this bootstrap apply only after a short settle period so
# the next stage has a better chance of succeeding on its first backend init.
resource "time_sleep" "rbac_propagation" {
  count = var.rbac_propagation_wait == "0s" || length(local.blob_data_principal_ids) == 0 ? 0 : 1

  create_duration = var.rbac_propagation_wait
  depends_on      = [azurerm_role_assignment.blob_data_contributor]
}

resource "azurerm_storage_management_policy" "tfstate" {
  count = var.state_version_retention_days > 0 ? 1 : 0

  storage_account_id = azurerm_storage_account.tfstate.id

  rule {
    name    = "prune-old-state-versions"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
      prefix_match = [
        for config in values(local.backend_states) : "${config.container_name}/${config.key}"
      ]
    }

    actions {
      version {
        delete_after_days_since_creation = var.state_version_retention_days
      }
    }
  }
}

resource "azurerm_private_endpoint" "tfstate_blob" {
  count = var.enable_private_endpoint ? 1 : 0

  name                = coalesce(var.private_endpoint_name_override, "pe-${local.storage_account_name}-blob")
  location            = azurerm_resource_group.tfstate.location
  resource_group_name = azurerm_resource_group.tfstate.name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = merge(var.tags, { component = "terraform-backend-private-endpoint" })

  private_service_connection {
    name                           = "psc-${local.storage_account_name}-blob"
    private_connection_resource_id = azurerm_storage_account.tfstate.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  dynamic "private_dns_zone_group" {
    for_each = length(var.private_dns_zone_ids) > 0 ? [1] : []

    content {
      name                 = "blob-dns"
      private_dns_zone_ids = var.private_dns_zone_ids
    }
  }
}
