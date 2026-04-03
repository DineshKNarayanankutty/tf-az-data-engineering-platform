resource_group_name  = "rg-terraform-state"
storage_account_name = "tfstatedataplatformdkn"
container_name       = "dev"
key                  = "terraform.tfstate"
use_oidc             = true
use_azuread_auth     = true
