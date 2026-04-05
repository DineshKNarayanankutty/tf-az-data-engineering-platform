terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.57"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
  use_oidc            = true
  storage_use_azuread = true
}

# Workspace-scoped Databricks provider.
# azure_workspace_resource_id is enough — the provider resolves the host URL itself.
# Do NOT add host = "https://${module.databricks.workspace_url}" here:
# that creates a provider → module → provider circular dependency.
provider "databricks" {
  alias                       = "workspace"
  azure_workspace_resource_id = module.databricks.workspace_id
  azure_use_msi               = true
}
