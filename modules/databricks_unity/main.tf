terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.57"
    }
  }
}

locals {
  medallion_layers = toset(["bronze", "silver", "gold"])
}

# ---------------------------------------------------------------------------
# Storage Credential
# ---------------------------------------------------------------------------
resource "databricks_storage_credential" "adls" {
  name = "${var.environment}_uc_cred"

  azure_managed_identity {
    access_connector_id = var.databricks_connector_id
  }

  comment = "Managed identity credential for Unity Catalog — managed by Terraform"

  # Wait for RBAC assignments to propagate before creating the credential.
  # Without this, External Location "Test Connection" fails on first apply.
  depends_on = [var.rbac_propagation_trigger]
}

# ---------------------------------------------------------------------------
# External Locations  (bronze / silver / gold)
# ---------------------------------------------------------------------------
resource "databricks_external_location" "locations" {
  for_each = local.medallion_layers

  name            = "${var.environment}_${each.value}"
  url             = "abfss://${each.value}@${var.storage_account_name}.dfs.core.windows.net/"
  credential_name = databricks_storage_credential.adls.name
  comment         = "${title(each.value)} zone external location"
  force_destroy   = false

  # Explicit validation: ensures READ/WRITE/LIST/DELETE + File Events all pass.
  skip_validation = false
}

# ---------------------------------------------------------------------------
# Unity Catalog — Metastore Assignment (workspace must be bound)
# ---------------------------------------------------------------------------
resource "databricks_metastore_assignment" "this" {
  workspace_id = var.databricks_workspace_numeric_id
  metastore_id = var.metastore_id
}

# ---------------------------------------------------------------------------
# Catalog
# ---------------------------------------------------------------------------
resource "databricks_catalog" "main" {
  name           = var.catalog_name
  comment        = "Enterprise Unity Catalog for ${var.environment}"
  storage_root   = "abfss://unity-catalog@${var.storage_account_name}.dfs.core.windows.net/${var.catalog_name}"
  isolation_mode = "ISOLATED"

  properties = {
    environment = var.environment
    managed_by  = "terraform"
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [databricks_metastore_assignment.this]
}

# ---------------------------------------------------------------------------
# Schemas  (bronze / silver / gold)
# ---------------------------------------------------------------------------
resource "databricks_schema" "schemas" {
  for_each = local.medallion_layers

  catalog_name = databricks_catalog.main.name
  name         = each.value
  comment      = "${title(each.value)} schema — ${each.value == "bronze" ? "raw ingestion" : each.value == "silver" ? "cleansed / conformed" : "aggregated business layer"}"
}

# ---------------------------------------------------------------------------
# Grants
# ---------------------------------------------------------------------------
resource "databricks_grants" "catalog" {
  catalog = databricks_catalog.main.name

  grant {
    principal  = var.data_engineers_group
    privileges = ["USE_CATALOG", "CREATE_SCHEMA", "CREATE_TABLE"]
  }

  grant {
    principal  = var.data_readers_group
    privileges = ["USE_CATALOG"]
  }
}

resource "databricks_grants" "schema" {
  for_each = databricks_schema.schemas
  schema   = "${databricks_catalog.main.name}.${each.key}"

  grant {
    principal  = var.data_engineers_group
    privileges = ["USE_SCHEMA", "CREATE_TABLE", "MODIFY", "SELECT", "CREATE_VOLUME"]
  }

  grant {
    principal  = var.data_readers_group
    privileges = ["USE_SCHEMA", "SELECT"]
  }
}

resource "databricks_grants" "external_location" {
  for_each          = databricks_external_location.locations
  external_location = each.value.name

  grant {
    principal  = var.data_engineers_group
    privileges = ["READ_FILES", "WRITE_FILES", "CREATE_EXTERNAL_TABLE"]
  }

  grant {
    principal  = var.data_readers_group
    privileges = ["READ_FILES"]
  }
}

# ---------------------------------------------------------------------------
# ETL Notebook
# ---------------------------------------------------------------------------
resource "databricks_notebook" "etl_notebook" {
  path     = var.job_notebook_path
  language = "PYTHON"
  source   = "${path.module}/notebooks/bronze_to_silver_gold.py"
}

# ---------------------------------------------------------------------------
# Dev: Single-Node Interactive Cluster
# DATA_SECURITY_MODE must be SINGLE_USER for single-node (USER_ISOLATION is
# invalid when num_workers=0 / singleNode profile).
# ---------------------------------------------------------------------------
resource "databricks_cluster" "dev_single_node" {
  count = var.environment == "dev" ? 1 : 0

  cluster_name            = "${var.environment}-single-node"
  spark_version           = var.spark_version
  node_type_id            = var.dev_node_type
  num_workers             = 0
  autotermination_minutes = 20

  # SINGLE_USER required for single-node clusters in Unity Catalog
  data_security_mode = "SINGLE_USER"
  single_user_name   = var.cluster_single_user_name

  spark_conf = {
    "spark.databricks.cluster.profile" = "singleNode"
    "spark.master"                     = "local[*]"
  }

  spark_env_vars = {
    PYSPARK_PYTHON = "/databricks/python3/bin/python3"
  }

  custom_tags = {
    ResourceClass = "SingleNode"
    Environment   = var.environment
    ManagedBy     = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Prod: Instance Pool for cost-efficient job clusters
# ---------------------------------------------------------------------------
resource "databricks_instance_pool" "prod_pool" {
  count = var.environment == "prod" ? 1 : 0

  instance_pool_name                    = "${var.environment}-etl-pool"
  node_type_id                          = var.prod_node_type
  min_idle_instances                    = 0
  max_capacity                          = var.pool_max_capacity
  idle_instance_autotermination_minutes = 20

  preloaded_spark_versions = [var.spark_version]

  disk_spec {
    disk_type {
      azure_disk_volume_type = "PREMIUM_LRS"
    }
    disk_size  = 128
    disk_count = 1
  }
}

# ---------------------------------------------------------------------------
# Job (staging + prod)
# ---------------------------------------------------------------------------
resource "databricks_job" "etl" {
  count = contains(["staging", "prod"], var.environment) ? 1 : 0
  name  = "${var.environment}-bronze-silver-gold-etl"

  queue {
    enabled = true
  }

  job_cluster {
    job_cluster_key = "etl_cluster"

    new_cluster {
      spark_version      = var.spark_version
      instance_pool_id   = var.environment == "prod" ? databricks_instance_pool.prod_pool[0].id : null
      node_type_id       = var.environment == "prod" ? null : var.prod_node_type
      data_security_mode = "USER_ISOLATION"

      autoscale {
        min_workers = var.job_min_workers
        max_workers = var.job_max_workers
      }

      spark_conf = {
        "spark.sql.shuffle.partitions" = "auto"
      }

      custom_tags = {
        Environment = var.environment
        JobType     = "etl"
        ManagedBy   = "terraform"
      }
    }
  }

  task {
    task_key        = "bronze_to_silver_gold"
    job_cluster_key = "etl_cluster"

    notebook_task {
      notebook_path = databricks_notebook.etl_notebook.path
      base_parameters = {
        env            = var.environment
        catalog        = var.catalog_name
        storage_account = var.storage_account_name
      }
    }

    retry_on_timeout = false
    max_retries      = 1
  }

  health {
    rules {
      metric    = "RUN_DURATION_SECONDS"
      op        = "GREATER_THAN"
      value     = 7200 # alert if job takes >2h
    }
  }

  # Notify on failure
  notification_settings {
    no_alert_for_skipped_runs = false
  }
}
