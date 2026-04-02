# Azure Data Platform Terraform

Production-grade, modular Terraform implementation for an Azure-based enterprise data engineering platform with separate environments (`dev`, `staging`, `prod`) and separate remote state backends in Azure Blob Storage.

This repository provisions a secure Azure data platform built around Azure Data Lake Storage Gen2, Azure Databricks with Unity Catalog, Azure Key Vault, Azure Data Factory, private networking, managed identities, RBAC, diagnostics, and CI/CD.

## Architecture

The platform is designed for multi-environment enterprise deployment with environment isolation, private connectivity, least-privilege access, and remote state separation.

### Core services
- Azure Resource Group per environment.
- Azure Virtual Network with dedicated subnets for Databricks and Private Endpoints.
- Azure Storage Account with ADLS Gen2 enabled.
- Bronze, Silver, Gold, and Unity Catalog storage containers.
- Azure Databricks Premium workspace with VNet injection and no public access.
- Azure Databricks Access Connector using Managed Identity.
- Unity Catalog resources including storage credential, external locations, catalog, and schemas.
- Azure Key Vault with RBAC authorization and private endpoint.
- Azure Data Factory v2 with Managed Identity and private endpoint.
- Log Analytics workspace and diagnostic settings.
- GitHub Actions CI/CD with plan/apply workflow and approval gates.

## Repository structure

```text
terraform-azure-data-platform/
├── backend-bootstrap/
│   └── main.tf
├── modules/
│   ├── networking/
│   ├── storage/
│   ├── keyvault/
│   ├── security/
│   ├── databricks/
│   ├── adf/
│   └── monitoring/
├── envs/
│   ├── dev/
│   ├── staging/
│   └── prod/
└── .github/
    └── workflows/
```

## Prerequisites

Before deploying, ensure the following tools and Azure capabilities are available.

### Local tools
- Terraform `>= 1.7.0`
- Azure CLI `>= 2.60`
- Git
- Access to an Azure subscription with permissions to create:
  - Resource Groups
  - Storage Accounts
  - VNets and Private Endpoints
  - Key Vault
  - Databricks
  - Data Factory
  - RBAC assignments
  - Log Analytics

### Azure permissions
Your deployment identity should have at minimum:
- `Contributor` on the target subscription or management group.
- `User Access Administrator` on the target subscription or resource groups, because Terraform assigns RBAC roles.
- Permission to create federated identity credentials if using GitHub OIDC.

### Recommended Azure features
Make sure these providers are registered in the subscription:

```bash
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.Databricks
az provider register --namespace Microsoft.DataFactory
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.ManagedIdentity
```

## Environment model

Each environment has:
- Its own Terraform root under `envs/<environment>/`
- Its own `.tfvars` file
- Its own remote backend key in Azure Blob Storage
- Its own Azure Resource Group and platform resources

### Backend state layout

Terraform state is stored in Azure Blob Storage with one backend key per environment.

Example:

```text
container: tfstate
├── dev/terraform.tfstate
├── staging/terraform.tfstate
└── prod/terraform.tfstate
```

This prevents state collision and supports isolated promotion across environments.

## Backend design

This implementation uses the `azurerm` backend in each environment.

### Dev backend
Located in `envs/dev/main.tf`:

```hcl
backend "azurerm" {
  resource_group_name  = "rg-terraform-state"
  storage_account_name = "tfstatedataplatform"
  container_name       = "tfstate"
  key                  = "dev/terraform.tfstate"
  use_oidc             = true
}
```

### Staging backend
Located in `envs/staging/main.tf`:

```hcl
backend "azurerm" {
  resource_group_name  = "rg-terraform-state"
  storage_account_name = "tfstatedataplatform"
  container_name       = "tfstate"
  key                  = "staging/terraform.tfstate"
  use_oidc             = true
}
```

### Prod backend
Located in `envs/prod/main.tf`:

```hcl
backend "azurerm" {
  resource_group_name  = "rg-terraform-state"
  storage_account_name = "tfstatedataplatform"
  container_name       = "tfstate"
  key                  = "prod/terraform.tfstate"
  use_oidc             = true
}
```

## Step 1: Clone the repository

```bash
git clone <your-repository-url>
cd terraform-azure-data-platform
```

## Step 2: Authenticate to Azure

### Option A: Local development with Azure CLI

```bash
az login
az account set --subscription "<subscription-id-or-name>"
```

If your local Terraform provider uses Azure CLI authentication, this is enough for local execution.

### Option B: GitHub Actions with OIDC
This is recommended for CI/CD because it avoids long-lived client secrets.

You will need:
- Azure AD application / service principal
- Federated credential for GitHub repository or environment
- GitHub repository secrets:
  - `AZURE_CLIENT_ID`
  - `AZURE_TENANT_ID`
  - `AZURE_SUBSCRIPTION_ID`
  - optional `AZURE_CLIENT_SECRET` only if not using OIDC (OIDC recommended)

## Step 3: Bootstrap the remote backend storage

The backend storage must exist before Terraform can use it for remote state.

Run the bootstrap configuration first.

```bash
cd backend-bootstrap
terraform init
terraform plan
terraform apply
```

This creates:
- Resource Group: `rg-terraform-state`
- Storage Account: `tfstatedataplatform`
- Blob Container: `tfstate`

### Important note
The backend storage account is secure-by-default with public network access disabled. If you use GitHub-hosted runners, explicitly set `public_network_access_enabled = true` and define restricted `allowed_ip_rules`.

## Step 4: Review environment variables and tfvars

Each environment has a dedicated `.tfvars` file.

### Example: `envs/dev/dev.tfvars`

```hcl
project      = "dataplatform"
environment  = "dev"
location     = "eastus2"
owner        = "platform-team"
cost_center  = "CC-1234-DATA"
alert_email  = "platform-alerts@yourcompany.com"

vnet_cidr                 = "10.10.0.0/16"
databricks_host_cidr      = "10.10.1.0/24"
databricks_container_cidr = "10.10.2.0/24"
private_endpoint_cidr     = "10.10.3.0/24"

spark_version         = "14.3.x-scala2.12"
dev_node_type         = "Standard_D4ds_v5"
prod_node_type        = "Standard_D8ds_v5"
autoscale_min_workers = 1
autoscale_max_workers = 4

github_account_name = "your-org"
github_repo_name    = "azure-data-platform"
git_branch          = "develop"
```

### Secret handling
Do not store secrets in `.tfvars` files.

This implementation uses managed identities for Databricks and ADF integration, so no Databricks PAT variable is required.

## Step 5: Deploy each environment

### Deploy dev

```bash
cd envs/dev
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

### Deploy staging

```bash
cd envs/staging
terraform init
terraform plan -var-file=staging.tfvars
terraform apply -var-file=staging.tfvars
```

### Deploy prod

```bash
cd envs/prod
terraform init
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

## Recommended deployment order

Use this order for first-time rollout:

1. Bootstrap remote backend.
2. Deploy `dev`.
3. Validate networking, private endpoints, RBAC, Databricks workspace, ADF, and Key Vault.
4. Promote the same code to `staging` with environment-specific tfvars.
5. After validation and manual approval, deploy `prod`.

## What gets created

### Networking
- Virtual Network
- Databricks host subnet
- Databricks container subnet
- Private endpoints subnet
- NSGs for Databricks subnets
- Private DNS zones and VNet links

### Storage
- ADLS Gen2 Storage Account
- Containers:
  - `bronze`
  - `silver`
  - `gold`
  - `unity-catalog`
- Private Endpoints for Blob and DFS
- Diagnostic settings to Log Analytics

### Databricks
- Premium workspace
- VNet injection
- No public network access
- Private Endpoint for UI/API
- Unity Catalog metastore assignment
- Storage credential using Access Connector MI
- External locations for bronze/silver/gold
- Catalog and schemas
- Cluster with env-based sizing

### Security
- Databricks Access Connector
- User-assigned identity for ADF
- RBAC assignments for storage and Key Vault access

### Key Vault
- Premium Key Vault
- RBAC authorization mode
- Private Endpoint
- Managed identity access for services that need secrets

### Data Factory
- ADF v2
- User-assigned managed identity
- ADLS linked service using MI
- Key Vault linked service
- Databricks linked service using managed identity

### Monitoring
- Log Analytics Workspace
- Action Group
- Diagnostics across supported services

## Backend and promotion strategy

This repository uses the same reusable modules for all environments, while environment roots define:
- backend key
- tags
- CIDR ranges
- cluster sizing
- branch alignment
- operational settings

### Why separate backend per environment
This approach gives you:
- state isolation
- lower blast radius
- simpler rollback
- clearer audit trail
- safer CI/CD approvals

## How to reconfigure backend safely

If you need to move or change backend configuration later:

```bash
terraform init -reconfigure
```

If migrating existing state from local to remote or remote to new remote:

```bash
terraform init -migrate-state
```

## Validating deployment in Azure

After apply completes, validate these items.

### Storage
- Storage account exists and has hierarchical namespace enabled.
- Containers `bronze`, `silver`, `gold`, and `unity-catalog` exist.
- Public access is disabled.
- Private Endpoints are approved.

### Databricks
- Workspace is Premium.
- Public network access is disabled.
- Subnets are properly delegated.
- Workspace loads through private networking.
- Unity Catalog storage credential and external locations are present.

### Key Vault
- Public network access is disabled.
- RBAC is enabled.
- Private Endpoint is connected.
- Secret `databricks-pat-token` exists.

### Data Factory
- Managed identity is attached.
- Linked services resolve successfully.
- Private endpoint exists.

### RBAC
- Databricks Access Connector has required permissions on the storage account.
- ADF managed identity has `Storage Blob Data Contributor`.
- Required Key Vault secret permissions exist through RBAC.

## GitHub Actions CI/CD

The included workflow supports:
- `terraform fmt`
- `terraform validate`
- `terraform plan`
- manual approval via GitHub Environments
- `terraform apply`

### Suggested GitHub environments
Create these GitHub environments:
- `dev-apply`
- `staging-apply`
- `prod-apply`

Require manual reviewers for `staging-apply` and `prod-apply`.

### Suggested GitHub secrets
Set repository or environment secrets:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
```

## Security guidance

### Implemented security controls
- No hardcoded application secrets in code.
- Managed identities for service authentication where possible.
- Key Vault for secret storage.
- Private Endpoints for Storage, Key Vault, Databricks, and ADF.
- Public network access disabled on major services.
- RBAC with least privilege.
- Separate state per environment.

### Additional enterprise hardening recommendations
- Use Azure Policy to deny public IPs and enforce tags.
- Add Defender for Cloud and Defender for Storage.
- Add CMK encryption for Storage, Databricks, and Key Vault where required.
- Add Private DNS Resolver if using hub-spoke networking.
- Use dedicated CI/CD service principals per environment.
- Restrict backend state access to platform administrators only.

## Operational guidance

### Common commands
Format:

```bash
terraform fmt -recursive
```

Validate:

```bash
terraform validate
```

Plan:

```bash
terraform plan -var-file=dev.tfvars
```

Show current state:

```bash
terraform state list
```

Destroy a non-production environment:

```bash
terraform destroy -var-file=dev.tfvars
```

## Known implementation notes

### Databricks authentication
This implementation uses managed identity for Databricks integrations and avoids PAT token management in Terraform.

### Unity Catalog metastore lifecycle
The metastore is protected with `prevent_destroy = true`. This is intentional and should remain in place.

### Backend storage isolation
If your organization requires stronger isolation, create:
- one backend storage account per environment, or
- one container per environment with scoped RBAC

The current design uses one storage account and one container with separate blob keys, which is common and operationally efficient.

## Recommended next improvements

You can extend this repository with:
- Azure Policy assignments
- private DNS resolver and hub-spoke networking
- self-hosted GitHub runners inside Azure
- Databricks jobs, SQL warehouses, and notebook deployment
- ADF datasets, triggers, and integration runtime enhancements
- Sentinel or OPA policy checks in CI/CD
- Terratest or kitchen-terraform validation

## Troubleshooting

### Error: backend not found
Make sure `backend-bootstrap` was applied successfully and the storage account/container exist.

### Error: authorization failed on role assignments
Your identity likely lacks `User Access Administrator` or equivalent role assignment permissions.

### Error: private endpoint DNS resolution issues
Validate:
- Private DNS zones exist
- VNet links exist
- DNS records are present after PE approval
- client is resolving inside the VNet or connected network

### Error: Databricks provider authentication issues
Check:
- Databricks workspace is created successfully
- provider host is correct
- Azure authentication context is valid
- managed identity or Azure auth path is supported for your execution context

### Error: Key Vault secret creation denied
The deployment identity must have RBAC access to create secrets in the Key Vault.

## Implementation checklist

Use this checklist for rollout.

- [ ] Register required Azure resource providers.
- [ ] Bootstrap the remote state storage.
- [ ] Configure Azure authentication locally or via GitHub OIDC.
- [ ] Populate `dev.tfvars`, `staging.tfvars`, and `prod.tfvars`.
- [ ] Run `terraform init` in `envs/dev`.
- [ ] Run `terraform plan` and `terraform apply` for dev.
- [ ] Validate private networking, RBAC, and service health.
- [ ] Repeat for staging.
- [ ] Enable manual approval and deploy prod.

## Support model

This repository should be owned by a platform engineering or cloud foundation team. Application and data teams should consume the provisioned platform through controlled onboarding, not by modifying core infrastructure directly.
