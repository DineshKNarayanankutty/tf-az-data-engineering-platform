# ---------------------------------------------------------------------------
# Azure Data Factory
# ---------------------------------------------------------------------------
resource "azurerm_data_factory" "main" {
  name                            = var.adf_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  public_network_enabled          = false
  managed_virtual_network_enabled = true
  tags                            = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [var.adf_user_assigned_identity_id]
  }
}

# ---------------------------------------------------------------------------
# Linked Services
# ---------------------------------------------------------------------------

# ADLS Gen2 — authenticated via ADF User-Assigned Managed Identity
resource "azurerm_data_factory_linked_service_data_lake_storage_gen2" "adls" {
  name                 = "ls_adls_gen2_mi"
  data_factory_id      = azurerm_data_factory.main.id
  url                  = var.storage_dfs_endpoint
  use_managed_identity = true
}

# Key Vault — secrets consumed by pipelines
resource "azurerm_data_factory_linked_service_key_vault" "kv" {
  name            = "ls_key_vault"
  data_factory_id = azurerm_data_factory.main.id
  key_vault_id    = var.key_vault_id
}

# Azure Databricks — MSI auth avoids PAT tokens (production best practice)
resource "azurerm_data_factory_linked_service_azure_databricks" "dbw" {
  name                       = "ls_databricks_mi"
  data_factory_id            = azurerm_data_factory.main.id
  adb_domain                 = "https://${var.databricks_workspace_url}"
  msi_work_space_resource_id = var.databricks_workspace_id

  new_cluster_config {
    node_type             = var.databricks_cluster_node_type
    cluster_version       = var.databricks_cluster_version
    min_number_of_workers = var.databricks_cluster_workers
    max_number_of_workers = var.databricks_cluster_workers * 2

    spark_config = {
      "spark.sql.shuffle.partitions" = "auto"
    }

    custom_tags = {
      ManagedBy = "adf-terraform"
    }
  }
}

# HTTP linked service — anonymous, for public data sources
resource "azurerm_data_factory_linked_service_web" "http_source" {
  name            = "ls_http_public"
  data_factory_id = azurerm_data_factory.main.id
  url             = var.http_source_base_url

  authentication_type = "Anonymous"
}

# ---------------------------------------------------------------------------
# Datasets
# ---------------------------------------------------------------------------

# Bronze sink — schema omitted (None) so Copy creates file fresh.
# Avoids PathNotFound on first run (documented in learning notes).
resource "azurerm_data_factory_dataset_delimited_text" "bronze_sink" {
  name                = "DS_ADLS_Bronze"
  data_factory_id     = azurerm_data_factory.main.id
  linked_service_name = azurerm_data_factory_linked_service_data_lake_storage_gen2.adls.name

  azure_blob_fs_location {
    file_system = "bronze"
    path        = "adf-ingest"
    filename    = "data.csv"
  }

  column_delimiter    = ","
  row_delimiter       = "\n"
  first_row_as_header = true
}

# HTTP source dataset
resource "azurerm_data_factory_dataset_http" "http_source" {
  name                = "DS_HTTP_Source"
  data_factory_id     = azurerm_data_factory.main.id
  linked_service_name = azurerm_data_factory_linked_service_web.http_source.name

  relative_url   = var.http_source_relative_url
  request_method = "GET"
}

# ---------------------------------------------------------------------------
# Pipeline: pl_ingest_to_bronze
# Native Terraform resource — replaces the previous ARM template deployment.
# ARM template deployments have no drift detection and opaque error messages.
# ---------------------------------------------------------------------------
resource "azurerm_data_factory_pipeline" "ingest_to_bronze" {
  name            = "pl_ingest_to_bronze"
  data_factory_id = azurerm_data_factory.main.id
  description     = "HTTP → bronze (Copy), then bronze → silver → gold (Databricks notebook)"

  activities_json = jsonencode([
    {
      name      = "Copy_HTTP_to_Bronze"
      type      = "Copy"
      dependsOn = []
      policy = {
        timeout                = "0.02:00:00"
        retry                  = 1
        retryIntervalInSeconds = 30
        secureOutput           = false
        secureInput            = false
      }
      typeProperties = {
        source = {
          type = "DelimitedTextSource"
          storeSettings = {
            type          = "HttpReadSettings"
            requestMethod = "GET"
          }
          formatSettings = {
            type = "DelimitedTextReadSettings"
          }
        }
        sink = {
          type = "DelimitedTextSink"
          storeSettings = {
            type = "AzureBlobFSWriteSettings"
          }
          formatSettings = {
            type         = "DelimitedTextWriteSettings"
            quoteAllText = false
            fileExtension = ".csv"
          }
        }
        enableStaging = false
      }
      inputs = [{
        referenceName = azurerm_data_factory_dataset_http.http_source.name
        type          = "DatasetReference"
      }]
      outputs = [{
        referenceName = azurerm_data_factory_dataset_delimited_text.bronze_sink.name
        type          = "DatasetReference"
      }]
    },
    {
      name = "Trigger_Databricks_ETL"
      type = "DatabricksNotebook"
      dependsOn = [{
        activity             = "Copy_HTTP_to_Bronze"
        dependencyConditions = ["Succeeded"]
      }]
      policy = {
        timeout                = "0.12:00:00"
        retry                  = 1
        retryIntervalInSeconds = 30
      }
      linkedServiceName = {
        referenceName = azurerm_data_factory_linked_service_azure_databricks.dbw.name
        type          = "LinkedServiceReference"
      }
      typeProperties = {
        notebookPath = var.etl_notebook_path
        baseParameters = {
          env             = var.environment_name
          storage_account = var.storage_account_name
        }
      }
    }
  ])
}

# ---------------------------------------------------------------------------
# Managed Private Endpoints (ADF Managed VNet → private resources)
# ---------------------------------------------------------------------------
resource "azurerm_data_factory_managed_private_endpoint" "storage_dfs" {
  name               = "mpe-storage-dfs"
  data_factory_id    = azurerm_data_factory.main.id
  target_resource_id = var.storage_account_id
  subresource_name   = "dfs"
}

resource "azurerm_data_factory_managed_private_endpoint" "keyvault" {
  name               = "mpe-keyvault"
  data_factory_id    = azurerm_data_factory.main.id
  target_resource_id = var.key_vault_id
  subresource_name   = "vault"
}

# ---------------------------------------------------------------------------
# Private Endpoint (inbound to ADF control plane)
# ---------------------------------------------------------------------------
resource "azurerm_private_endpoint" "adf" {
  name                = "${var.adf_name}-pep"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.adf_name}-psc"
    private_connection_resource_id = azurerm_data_factory.main.id
    subresource_names              = ["datafactory"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "adf-dns"
    private_dns_zone_ids = [var.dns_zone_adf_id]
  }
}

# ---------------------------------------------------------------------------
# Diagnostics
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "adf" {
  name                       = "${var.adf_name}-diag"
  target_resource_id         = azurerm_data_factory.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
