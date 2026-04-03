# Local CLI Implementation Guide

This document explains how to implement the Azure data platform from scratch using your local machine first, and then later automate it through CI/CD.

It is written for the current Terraform repository structure and assumes the repository already contains modular Terraform for:
- Azure Databricks
- ADLS Gen2
- Unity Catalog
- Azure Data Factory
- Azure Key Vault
- Networking
- Monitoring
- Security / RBAC
- Multi-environment backends

The goal is to help you deploy safely from your local CLI with zero confusion and minimal manual fallback.

---

## 1. What you are deploying

This repository deploys a secure Azure data platform with separate environments and separate Terraform state per environment. The platform includes Azure Databricks, ADLS Gen2, Unity Catalog integration, Azure Data Factory, Key Vault, private networking, diagnostics, and supporting RBAC. [file:1]

The repository already follows a modular pattern and separates `dev`, `staging`, and `prod`, which is the correct foundation for enterprise deployment because each environment must have isolated configuration and isolated state. [file:1]

---

## 2. Deployment approach

You will implement this in two phases:

1. Local CLI-based deployment from your laptop or workstation.
2. Later migration to automated CI/CD using the same repository and backend design.

Start with local CLI so you can validate Azure permissions, DNS behavior, Databricks access, RBAC, and provider behavior before introducing pipeline complexity. That matches the practical lesson from your hands-on notes, where Azure and Databricks behaviors sometimes differed from older tutorials or changed CLI syntax. [file:1]

---

## 3. Prerequisites

### 3.1 Azure prerequisites

Before running Terraform, make sure you have:
- An Azure subscription.
- Permission to create resource groups, VNets, private endpoints, storage, Key Vault, Databricks, ADF, Log Analytics, and RBAC assignments.
- `User Access Administrator` or equivalent permission for role assignments, because Terraform will assign RBAC roles.

If you cannot create role assignments, Terraform may fail even if resource creation works.

### 3.2 Local software prerequisites

Install these tools on your machine:
- Azure CLI
- Terraform `>= 1.8.x`
- Git
- jq (recommended)
- Databricks CLI (recommended for validation and later notebook/job work)
- Python 3 (optional but helpful)

### 3.3 Recommended versions

Use:
- Azure CLI: latest stable
- Terraform: 1.8.x or newer stable supported by the repo
- Databricks CLI: `0.200+`

Your notes showed that Databricks CLI syntax changed in newer versions, especially for secret scope creation, so staying on a modern version is important. [file:1]

---

## 4. Install local tools

### 4.1 Azure CLI

Linux:
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

macOS:
```bash
brew update
brew install azure-cli
```

Windows:
Install from Microsoft MSI package or `winget`.

Verify:
```bash
az version
```

### 4.2 Terraform

Linux/macOS with Homebrew:
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

Linux manual:
Download from HashiCorp releases and add to PATH.

Verify:
```bash
terraform version
```

### 4.3 Databricks CLI

Linux/macOS:
```bash
curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh
```

Verify:
```bash
databricks --version
```

Your notes also showed that Databricks Asset Bundles can require `uv` depending on the chosen template, so if you later use bundles, install `uv` too or choose notebook tasks without Python wheel build steps. [file:1]

### 4.4 jq

Linux:
```bash
sudo apt-get update && sudo apt-get install -y jq
```

macOS:
```bash
brew install jq
```

---

## 5. Clone the repository

```bash
git clone <your-repository-url>
cd terraform-azure-data-platform
```

Inspect the main structure:

```bash
tree -L 3
```

You should see:
- `modules/`
- `envs/dev`
- `envs/staging`
- `envs/prod`
- `backend-config/`
- `backend-bootstrap/`
- `.github/workflows/`

---

## 6. Authenticate to Azure locally

Login:
```bash
az login
```

Set the correct subscription:
```bash
az account list --output table
az account set --subscription "<subscription-id-or-name>"
```

Confirm:
```bash
az account show --output table
```

If your organization uses multiple tenants, confirm you are in the right tenant and subscription before running Terraform.

---

## 7. Register Azure resource providers

Run these once per subscription if they are not already registered:

```bash
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.Databricks
az provider register --namespace Microsoft.DataFactory
az provider register --namespace Microsoft.ManagedIdentity
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.EventGrid
az provider register --namespace Microsoft.Consumption
```

Check status:
```bash
az provider show --namespace Microsoft.Databricks --query registrationState -o tsv
```

---

## 8. Verify local Azure access for RBAC

Because the repository creates RBAC assignments, validate that your login has permission:

```bash
az role assignment list \
  --assignee $(az ad signed-in-user show --query id -o tsv) \
  --scope /subscriptions/$(az account show --query id -o tsv) \
  --output table
```

If RBAC assignment later fails, the most common cause is missing `User Access Administrator` or equivalent.

---

## 9. Bootstrap the Terraform backend

## 9.1 Why bootstrap is separate

Terraform cannot use a remote backend until the backend storage account and blob container already exist. That is why backend bootstrap is intentionally separate from the main environments. This avoids circular dependency. [file:1]

### 9.2 Go to bootstrap folder

```bash
cd backend-bootstrap
```

### 9.3 Initialize and apply bootstrap

```bash
terraform init
terraform plan
terraform apply
```

This should create:
- Resource group for Terraform state
- Storage account for remote state
- Blob containers for `dev`, `stage`, and `prod`

### 9.4 Validate backend storage

```bash
az storage account list --output table
az storage container list \
  --account-name tfstatedataplatformdkn \
  --auth-mode login \
  --output table
```

If the container exists, backend bootstrap is complete.

-

## 10. Understand backend-per-environment

Each environment uses a separate backend config file and a separate storage container in Azure Blob Storage.

Expected pattern:
- `backend-config/dev.hcl` → `container_name = dev`
- `backend-config/stage.hcl` → `container_name = stage`
- `backend-config/prod.hcl` → `container_name = prod`

Each backend config should set both `use_oidc = true` and `use_azuread_auth = true` so the backend uses Microsoft Entra ID instead of shared keys. [file:1]

---

## 11. Review and prepare environment variables

Before first deployment, open the environment-specific files.

### Files to inspect
- `envs/dev/*.tf`
- `envs/dev/dev.tfvars`
- `backend-config/dev.hcl`

Repeat later for staging and prod.

### Update the dev configuration
Make sure these values match your Azure standards:
- organization name
- project name
- region
- CIDR ranges
- cost center
- owner tag
- alert email
- Databricks group names
- notebook paths
- node sizes

---

## 12. Secret handling before first run

### 12.1 Important rule
Never store real secrets inside:
- Terraform code
- `.tfvars`
- Git
- shell history if possible

### 12.2 Databricks PAT handling
If the repo currently expects a Databricks PAT for the ADF linked service, export it as an environment variable before Terraform apply:

```bash
export TF_VAR_databricks_pat_value="<your-databricks-pat>"
```

Use a temporary shell session and avoid saving it in files.

### 12.3 Local shell hygiene
Recommended:
```bash
unset HISTFILE
export TF_VAR_databricks_pat_value="<your-databricks-pat>"
```

Then restore shell history behavior later if needed.

---

## 13. Deploy dev environment from local CLI

### 13.1 Move into dev environment

```bash
cd ../envs/dev
```

### 13.2 Terraform init with dev backend

```bash
terraform init -backend-config=../../backend-config/dev.hcl -reconfigure
```

### 13.3 Validate Terraform

```bash
terraform fmt -check -recursive
terraform validate
```

### 13.4 Review the plan

```bash
terraform plan -var-file=dev.tfvars
```

Read the plan carefully. On first run, expect creation of the full stack.

### 13.5 Apply dev

```bash
terraform apply -var-file=dev.tfvars
```

---

## 14. What to validate after dev deployment

After Terraform completes, validate everything in Azure and Databricks.

### 14.1 Resource group

```bash
az group show --name <dev-resource-group-name> --output table
```

### 14.2 Storage account
Check that:
- HNS is enabled
- public access is disabled
- containers exist

```bash
az storage account show \
  --name <storage-account-name> \
  --resource-group <resource-group> \
  --query "{name:name,isHnsEnabled:isHnsEnabled,publicAccess:publicNetworkAccess}" \
  -o json
```

### 14.3 Containers

```bash
az storage container list \
  --account-name <storage-account-name> \
  --auth-mode login \
  --output table
```

Expect at least:
- bronze
- silver
- gold
- unity-catalog

### 14.4 Databricks workspace

```bash
az databricks workspace show \
  --name <workspace-name> \
  --resource-group <resource-group> \
  --output json
```

Confirm:
- Premium SKU
- public network access disabled
- VNet injection values are present

### 14.5 Access Connector
The Databricks Access Connector may be created by your own Terraform module or may already exist depending on the chosen pattern. Your prior notes showed that Azure Databricks can auto-create one in some cases, so always verify whether Terraform is reusing an existing connector or creating a new one intentionally. [file:1]

Check connector:

```bash
az databricks access-connector list \
  --resource-group <resource-group-or-databricks-managed-rg> \
  --output table
```

### 14.6 RBAC on storage account
This is extremely important.

Your notes showed that verifying role assignment without `--scope` can return misleading empty results because scope-level assignments are not shown by default. Use the exact storage account scope when verifying. [file:1]

```bash
STG_ID=$(az storage account show \
  --name <storage-account-name> \
  --resource-group <resource-group> \
  --query id -o tsv)

CONNECTOR_PRINCIPAL_ID=$(az databricks access-connector show \
  --name <access-connector-name> \
  --resource-group <connector-rg> \
  --query identity.principalId -o tsv)

az role assignment list \
  --assignee $CONNECTOR_PRINCIPAL_ID \
  --scope $STG_ID \
  --output table
```

Expect these four roles on the storage account scope:
- Storage Blob Data Contributor
- Storage Account Contributor
- EventGrid EventSubscription Contributor
- Storage Queue Data Contributor

Those four roles were required in your real hands-on validation for Unity Catalog external locations with File Events support. [file:1]

### 14.7 Key Vault

```bash
az keyvault show \
  --name <key-vault-name> \
  --resource-group <resource-group> \
  --output json
```

Confirm:
- RBAC authorization enabled
- public access disabled where configured
- private endpoint exists

### 14.8 ADF

```bash
az datafactory show \
  --name <adf-name> \
  --resource-group <resource-group> \
  --output json
```

Confirm:
- managed identity attached
- public network disabled if configured
- linked services and pipeline deployed

### 14.9 Private endpoints
List them:

```bash
az network private-endpoint list \
  --resource-group <resource-group> \
  --output table
```

Expect private endpoints for at least:
- Storage Blob / DFS
- Key Vault
- Databricks
- ADF if included in your module

### 14.10 Private DNS zones

```bash
az network private-dns zone list \
  --resource-group <resource-group> \
  --output table
```

Expect DNS zones and VNet links for private resolution.

---

## 15. Validate Databricks locally

### 15.1 Configure Databricks CLI

Your notes showed successful CLI usage with workspace URL + PAT token authentication. [file:1]

```bash
databricks configure
```

Enter:
- Workspace URL
- PAT token

### 15.2 Verify cluster visibility

```bash
databricks clusters list --output table
```

For dev, expect a single-node cluster or equivalent dev compute depending on your Terraform settings. Your learning setup used a single-node cluster because free-trial vCPU limits prevented multi-worker clusters. [file:1]

### 15.3 Validate Unity Catalog resources

Use Databricks SQL editor, notebook, or CLI-supported workflow to check:
- catalog exists
- schemas exist
- external locations are valid
- grants are correct

Your notes showed that modern Databricks expects `MANAGED LOCATION` when creating a catalog, which is important if you ever compare repo output to manual SQL. [file:1]

---

## 16. Validate ADF pipeline behavior

Your hands-on notes showed a real ADF pattern where a Copy activity writes to ADLS and then a Databricks Notebook activity runs afterward. That is the same sequence your Terraform implementation is targeting. [file:1]

Check in ADF:
- linked service to ADLS works with Managed Identity
- linked service to Databricks resolves with Key Vault secret
- dataset exists
- pipeline exists
- pipeline debug or trigger run succeeds

### Important ADF note
Your notes also captured a real-world sink dataset issue: schema import can fail when the destination path does not yet exist, and setting schema import to `None` avoids that chicken-and-egg problem. That is a useful troubleshooting point if your first ADF run behaves unexpectedly. [file:1]

---

## 17. Deploy staging and prod later

After dev is validated, repeat the same process for `staging` and `prod`.

### Staging

```bash
cd ../staging
terraform init -backend-config=../../backend-config/staging.hcl -reconfigure
terraform validate
terraform plan -var-file=staging.tfvars
terraform apply -var-file=staging.tfvars
```

### Prod

```bash
cd ../prod
terraform init -backend-config=../../backend-config/prod.hcl -reconfigure
terraform validate
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

Never point staging or prod to the dev backend.

---

## 18. Promotion flow you should follow

Use this promotion order:

1. Deploy backend bootstrap.
2. Deploy dev locally.
3. Validate networking, RBAC, Databricks, Unity Catalog, ADF, and Key Vault.
4. Fix any module or permission issues.
5. Deploy staging locally.
6. Validate again with stricter checks.
7. Deploy prod only after staging is stable.
8. Only then migrate execution to CI/CD.

This local-first approach is safer because it gives you full visibility into Azure and provider behavior before automation hides the details.

---

## 19. Recommended local command checklist

### Bootstrap
```bash
cd backend-bootstrap
terraform init
terraform apply
```

### Dev
```bash
cd ../envs/dev
terraform init -backend-config=../../backend-config/dev.hcl -reconfigure
terraform fmt -check -recursive
terraform validate
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

### Staging
```bash
cd ../staging
terraform init -backend-config=../../backend-config/staging.hcl -reconfigure
terraform validate
terraform plan -var-file=staging.tfvars
terraform apply -var-file=staging.tfvars
```

### Prod
```bash
cd ../prod
terraform init -backend-config=../../backend-config/prod.hcl -reconfigure
terraform validate
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

---

## 20. Troubleshooting guide

### Backend init fails
Check:
- backend bootstrap completed
- storage account exists
- container exists
- your login has access to the storage account

### Role assignments fail
Check:
- your Azure identity has permission to assign roles
- the target scope is correct
- the principal ID exists

### Role verification returns empty
Use `--scope` against the exact storage account resource ID. Your notes showed this is a common trap. [file:1]

### Databricks storage credential or external location validation fails
Check that the Access Connector has all four storage account scoped roles. Your notes showed that `Storage Blob Data Contributor` alone was not enough because File Events support also required three additional roles. [file:1]

### Databricks SQL command examples from tutorials do not work
Your notes showed that some older SQL DDL patterns like `CREATE STORAGE CREDENTIAL` are no longer supported in newer Databricks SQL, so prefer Terraform, API, CLI, or current UI patterns rather than outdated tutorials. [file:1]

### ADF sink dataset schema import fails
If the target path does not exist yet, schema import may fail before the first copy run. Your notes recorded that setting schema import to `None` avoids this issue. [file:1]

### Databricks bundle deploy fails with `uv` missing
If you later use Asset Bundles, install `uv` or remove the Python wheel artifact path and use notebook tasks instead. Your notes showed both approaches worked. [file:1]

---

## 21. When to move to CI/CD

Move to CI/CD only after:
- dev deployment works from local CLI
- staging deployment works from local CLI
- provider auth flow is stable
- backend state separation is confirmed
- RBAC is validated
- ADF and Databricks behavior are verified end-to-end

That avoids debugging Azure, Terraform, Databricks, and GitHub Actions all at the same time.

---

## 22. Post-local next step

After local rollout is stable, your next task should be to map local deployment commands to GitHub Actions using the same backend config files, tfvars pattern, and approval flow, so the automation exactly mirrors the proven manual path rather than introducing a different deployment model.
