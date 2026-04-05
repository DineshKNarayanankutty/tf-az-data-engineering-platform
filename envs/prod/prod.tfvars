org            = "dkn-org"
project        = "dataplatform"
environment    = "prod"
location       = "East US 2"
location_short = "eus2"
owner          = "platform-team"
cost_center    = "CC-1234-DATA"
repository     = "terraform-azure-data-engineering-platform"
alert_email    = "platform-alerts@yourcompany.com"

# Networking
vnet_cidr                 = "10.30.0.0/16"
databricks_host_cidr      = "10.30.1.0/24"
databricks_container_cidr = "10.30.2.0/24"
private_endpoint_cidr     = "10.30.3.0/24"

# Storage — GRS + versioning for production
replication_type       = "GRS"
enable_blob_versioning = true
delete_retention_days  = 30
tier_to_cool_days      = 60
tier_to_archive_days   = 180
delete_after_days      = 730

data_engineers_group = "data-engineers"
data_readers_group   = "data-readers"

spark_version  = "15.4.x-scala2.12"
dev_node_type  = "Standard_D4ds_v5"
prod_node_type = "Standard_D8ds_v5"

pool_max_capacity = 20
job_min_workers   = 2
job_max_workers   = 8

job_notebook_path              = "/Shared/pipelines/bronze_to_silver_gold"
create_example_external_table  = false
adf_databricks_cluster_workers = 4

metastore_id             = "YOUR_METASTORE_ID_HERE"
cluster_single_user_name = null  # prod uses autoscale job clusters

existing_databricks_access_connector_name                = null
existing_databricks_access_connector_resource_group_name = null

enable_budget        = true
budget_name          = "prod-monthly-budget"
subscription_id      = "YOUR_SUBSCRIPTION_ID_HERE"
budget_amount        = 2000
budget_start_date    = "2026-01-01T00:00:00Z"
budget_end_date      = "2027-01-01T00:00:00Z"
budget_contact_emails = ["platform-alerts@yourcompany.com", "finance@yourcompany.com"]
