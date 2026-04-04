output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "databricks_host_subnet_id" {
  value = azurerm_subnet.databricks_host.id
}

output "databricks_host_subnet_name" {
  value = azurerm_subnet.databricks_host.name
}

output "databricks_host_subnet_nsg_association_id" {
  value = azurerm_subnet_network_security_group_association.databricks_host.id
}

output "databricks_container_subnet_id" {
  value = azurerm_subnet.databricks_container.id
}

output "databricks_container_subnet_name" {
  value = azurerm_subnet.databricks_container.name
}

output "databricks_container_subnet_nsg_association_id" {
  value = azurerm_subnet_network_security_group_association.databricks_container.id
}

output "private_endpoint_subnet_id" {
  value = azurerm_subnet.private_endpoints.id
}

output "dns_zone_storage_blob_id" {
  value = azurerm_private_dns_zone.storage_blob.id
}

output "dns_zone_storage_dfs_id" {
  value = azurerm_private_dns_zone.storage_dfs.id
}

output "dns_zone_keyvault_id" {
  value = azurerm_private_dns_zone.keyvault.id
}

output "dns_zone_databricks_id" {
  value = azurerm_private_dns_zone.databricks.id
}

output "dns_zone_adf_id" {
  value = azurerm_private_dns_zone.adf.id
}
