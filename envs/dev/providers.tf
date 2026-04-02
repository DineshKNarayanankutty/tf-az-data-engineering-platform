terraform {
  required_version = ">= 1.8.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.46"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
  use_oidc = true
}

provider "databricks" {
  alias                       = "workspace"
  azure_workspace_resource_id = module.databricks.workspace_id
  azure_use_msi               = true
}
