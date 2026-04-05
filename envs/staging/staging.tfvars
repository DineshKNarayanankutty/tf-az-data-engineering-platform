org            = "dkn-org"
project        = "dataplatform"
environment    = "staging"
location       = "East US 2"
location_short = "eus2"
owner          = "platform-team"
cost_center    = "CC-1234-DATA"
repository     = "terraform-azure-data-engineering-platform"
alert_email    = "platform-alerts@yourcompany.com"

# Networking (separate /16 per env — no overlap)
vnet_cidr                 = "10.20.0.0/16"
databricks_host_cidr      = "10.20.1.0/24"
databricks_container_cidr = "10.20.2.0/24"
private_endpoint_cidr     = "10.20.3.0/24"

# Storage
replication_type       = "ZRS"
enable_blob_versioning = true
delete_retention_days  = 14
tier_to_cool_days      = 30
tier_to_archive_days   = 90
delete_after_days      = 365

data_engineers_group = "data-engineers"
data_readers_group   = "data-readers"

spark_version  = "15.4.x-scala2.12"
dev_node_type  = "Standard_D4ds_v5"
prod_node_type = "Standard_D8ds_v5"

pool_max_capacity = 8
job_min_workers   = 1
job_max_workers   = 4

job_notebook_path              = "/Shared/pipelines/bronze_to_silver_gold"
create_example_external_table  = false
adf_databricks_cluster_workers = 2

metastore_id             = "YOUR_METASTORE_ID_HERE"
cluster_single_user_name = null  # staging uses autoscale job clusters, not single-node

existing_databricks_access_connector_name                = null
existing_databricks_access_connector_resource_group_name = null

enable_budget        = true
budget_name          = "staging-monthly-budget"
subscription_id      = "YOUR_SUBSCRIPTION_ID_HERE"
budget_amount        = 500
budget_start_date    = "2026-01-01T00:00:00Z"
budget_end_date      = "2027-01-01T00:00:00Z"
budget_contact_emails = ["platform-alerts@yourcompany.com"]
