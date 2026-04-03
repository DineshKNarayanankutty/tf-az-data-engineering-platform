org            = "dkn-org"
project        = "dataplatform"
environment    = "dev"
location       = "East US 2"
location_short = "eus2"
owner          = "platform-team"
cost_center    = "CC-1234-DATA"
repository     = "terraform-azure-data-engineering-platform"
alert_email    = "platform-alerts@yourcompany.com"

# Networking
vnet_cidr                 = "10.10.0.0/16"
databricks_host_cidr      = "10.10.1.0/24"
databricks_container_cidr = "10.10.2.0/24"
private_endpoint_cidr     = "10.10.3.0/24"

# Storage
replication_type       = "LRS"
enable_blob_versioning = false
delete_retention_days  = 7
tier_to_cool_days      = 15
tier_to_archive_days   = 60
delete_after_days      = 180

# Databricks groups (must exist in the Databricks workspace)
data_engineers_group = "data-engineers"
data_readers_group   = "data-readers"

# Runtime
spark_version = "15.4.x-scala2.12"
dev_node_type = "Standard_D4ds_v5"
prod_node_type = "Standard_D8ds_v5"

# Job scaling (dev uses single-node, these apply to staging/prod only)
pool_max_capacity = 4
job_min_workers   = 1
job_max_workers   = 2

job_notebook_path              = "/Shared/pipelines/bronze_to_silver_gold"
create_example_external_table  = false
adf_databricks_cluster_workers = 2

# Unity Catalog
# Find with: databricks metastores list --output json | jq '.[0].metastore_id'
metastore_id = "YOUR_METASTORE_ID_HERE"

# Bind the dev single-node cluster to a specific user or SP.
# Use the Databricks user email or service principal application ID.
cluster_single_user_name = "your-sp-or-user@yourcompany.com"

# Existing Access Connector — Databricks auto-creates one in the managed RG.
# Set these to avoid Terraform creating a duplicate. Get values from:
#   az databricks access-connector list --resource-group <managed-rg> --query "[0].{name:name,rg:resourceGroup}" -o tsv
existing_databricks_access_connector_name                = null
existing_databricks_access_connector_resource_group_name = null

# Governance (off for dev)
enable_budget = false
