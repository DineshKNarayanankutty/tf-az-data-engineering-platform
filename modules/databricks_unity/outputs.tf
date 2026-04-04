output "storage_credential_id" {
  value       = databricks_storage_credential.adls.id
  description = "ID of the Unity Catalog storage credential"
}

output "external_location_ids" {
  value       = { for k, v in databricks_external_location.locations : k => v.id }
  description = "Map of external location name → ID"
}

output "catalog_id" {
  value       = databricks_catalog.main.id
  description = "Unity Catalog catalog ID"
}

output "dev_cluster_id" {
  value       = var.environment == "dev" ? databricks_cluster.dev_single_node[0].id : null
  description = "ID of the dev single-node interactive cluster (null in other envs)"
}

output "etl_job_id" {
  value       = contains(["staging", "prod"], var.environment) ? databricks_job.etl[0].id : null
  description = "ID of the ETL job (null in dev)"
}
