output "data_factory_id" {
  value       = azurerm_data_factory.main.id
  description = "ARM resource ID of the ADF instance"
}

output "data_factory_name" {
  value       = azurerm_data_factory.main.name
  description = "ADF instance name"
}

output "pipeline_name" {
  value       = azurerm_data_factory_pipeline.ingest_to_bronze.name
  description = "Name of the ingest pipeline"
}
