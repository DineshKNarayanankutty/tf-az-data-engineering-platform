resource "azurerm_storage_account" "adls" {
  name                              = var.storage_account_name
  resource_group_name               = var.resource_group_name
  location                          = var.location
  account_tier                      = "Standard"
  account_replication_type          = var.replication_type
  account_kind                      = "StorageV2"
  is_hns_enabled                    = true # ADLS Gen2 — CRITICAL: cannot be changed after creation
  min_tls_version                   = "TLS1_2"
  allow_nested_items_to_be_public   = false
  public_network_access_enabled     = false
  shared_access_key_enabled         = false
  default_to_oauth_authentication   = true
  infrastructure_encryption_enabled = true
  cross_tenant_replication_enabled  = false
  local_user_enabled                = false

  blob_properties {
    versioning_enabled = var.enable_blob_versioning

    delete_retention_policy {
      days = var.delete_retention_days
    }

    container_delete_retention_policy {
      days = var.delete_retention_days
    }

    last_access_time_enabled = true

    change_feed_enabled           = true
    change_feed_retention_in_days = 7
  }

  network_rules {
    default_action = "Deny"
    # AzureServices is required for:
    #   - Azure Monitor diagnostic exports
    #   - ADF managed virtual network private link approval
    #   - Trusted Azure service bypass
    # "None" here would break diagnostics and ADF managed endpoints.
    bypass = ["AzureServices"]

    virtual_network_subnet_ids = var.allowed_subnet_ids
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Lifecycle Management Policy
# ---------------------------------------------------------------------------
resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.adls.id

  rule {
    name    = "bronze-tiering"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["bronze/"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = var.tier_to_cool_days
        tier_to_archive_after_days_since_modification_greater_than = var.tier_to_archive_days
        delete_after_days_since_modification_greater_than          = var.delete_after_days
      }
      snapshot {
        delete_after_days_since_creation_greater_than = 30
      }
      version {
        delete_after_days_since_creation = 60
      }
    }
  }

  rule {
    name    = "silver-tiering"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["silver/"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = var.tier_to_cool_days * 2
        tier_to_archive_after_days_since_modification_greater_than = var.tier_to_archive_days * 2
        delete_after_days_since_modification_greater_than          = var.delete_after_days
      }
      snapshot {
        delete_after_days_since_creation_greater_than = 60
      }
    }
  }

  rule {
    name    = "gold-retention"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["gold/"]
    }

    actions {
      base_blob {
        # Gold data is aggregated business layer — keep hot for longer
        tier_to_cool_after_days_since_modification_greater_than    = var.tier_to_cool_days * 4
        tier_to_archive_after_days_since_modification_greater_than = var.tier_to_archive_days * 3
        delete_after_days_since_modification_greater_than          = var.delete_after_days * 2
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Containers  (bronze / silver / gold / unity-catalog)
# unity-catalog container is required as the catalog storage root
# ---------------------------------------------------------------------------
resource "azurerm_storage_container" "containers" {
  for_each              = toset(["bronze", "silver", "gold", "unity-catalog"])
  name                  = each.value
  storage_account_name  = azurerm_storage_account.adls.name
  container_access_type = "private"
}

# ---------------------------------------------------------------------------
# Private Endpoints
# ---------------------------------------------------------------------------
resource "azurerm_private_endpoint" "blob" {
  name                = "${var.storage_account_name}-pep-blob"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.storage_account_name}-psc-blob"
    private_connection_resource_id = azurerm_storage_account.adls.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "blob-dns"
    private_dns_zone_ids = [var.dns_zone_storage_blob_id]
  }
}

resource "azurerm_private_endpoint" "dfs" {
  name                = "${var.storage_account_name}-pep-dfs"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.storage_account_name}-psc-dfs"
    private_connection_resource_id = azurerm_storage_account.adls.id
    subresource_names              = ["dfs"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dfs-dns"
    private_dns_zone_ids = [var.dns_zone_storage_dfs_id]
  }
}

# ---------------------------------------------------------------------------
# Diagnostics
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "storage" {
  name                       = "${var.storage_account_name}-diag"
  target_resource_id         = "${azurerm_storage_account.adls.id}/blobServices/default"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
    enabled  = true
  }
}
