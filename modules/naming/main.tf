locals {
  prefix = lower(join("-", compact([var.org, var.project, var.environment, var.location_short])))

  tags = merge({
    environment = var.environment
    project     = var.project
    owner       = var.owner
    cost_center = var.cost_center
    managed_by  = "terraform"
    repository  = var.repository
    workload    = "data-platform"
  }, var.extra_tags)

  names = {
    rg            = "${local.prefix}-rg"
    vnet          = "${local.prefix}-vnet"
    kv            = substr(replace("${var.org}${var.project}${var.environment}${var.location_short}kv", "-", ""), 0, 24)
    dbw           = "${local.prefix}-dbw"
    adf           = "${local.prefix}-adf"
    law           = "${local.prefix}-law"
    pep_subnet    = "${local.prefix}-snet-pep"
    host_subnet   = "${local.prefix}-snet-dbw-host"
    cont_subnet   = "${local.prefix}-snet-dbw-container"
    dbw_connector = "${local.prefix}-dbw-connector"
    adf_uami      = "${local.prefix}-uami-adf"
    stg           = substr(replace("${var.org}${var.project}${var.environment}${var.location_short}adls", "-", ""), 0, 24)
  }
}

output "names" {
  value = local.names
}

output "tags" {
  value = local.tags
}

output "prefix" {
  value = local.prefix
}
