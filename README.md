# Azure Data Engineering Platform — Terraform

Production-grade Terraform for a lakehouse data platform on Azure.

**Stack:** ADLS Gen2 · Azure Databricks (Unity Catalog) · Azure Data Factory · Key Vault · Private Endpoints · Log Analytics · GitHub Actions CI/CD

---

## Architecture

```
GitHub Actions (OIDC)
└── Terraform
    ├── Networking        VNet, Databricks subnets, NSGs, Private DNS zones
    ├── Storage           ADLS Gen2 (bronze / silver / gold / unity-catalog containers)
    ├── Security          Databricks Access Connector, ADF UAMI, 4 RBAC roles
    ├── Key Vault         Premium SKU, RBAC auth, private endpoint
    ├── Databricks        Premium workspace, VNet injection, no public IP
    ├── Databricks Unity  Storage credential, external locations, catalog, schemas, grants
    │                     Dev: single-node cluster | Staging/Prod: autoscale job + instance pool
    ├── ADF               Managed VNet, linked services (ADLS/KV/Databricks), pipeline
    ├── Monitoring        Log Analytics workspace, action group, diagnostic settings
    └── Governance        Subscription consumption budget (optional)
```

---

## Prerequisites

1. **Azure subscription** with Contributor + User Access Administrator on the target scope
2. **Databricks workspace** provisioned (or let Terraform create it — module handles both)
3. **Unity Catalog metastore** — find your metastore ID:
   ```bash
   databricks metastores list --output json | jq -r '.[0].metastore_id'
   ```
4. **Federated OIDC credentials** on your Service Principal for GitHub Actions:
   ```bash
   az ad sp create-for-rbac --name "sp-terraform-dataplatform" --role Contributor \
     --scopes /subscriptions/<SUB_ID>
   ```
5. **GitHub secrets** set on the repo:
   - `AZURE_CLIENT_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`
6. **GitHub Environments** created: `dev-plan`, `dev-apply`, `staging-plan`, `staging-apply`, `prod-plan`, `prod-apply`

---

## First-Time Bootstrap

Bootstrap the remote state backend **once** before deploying any environment:

```bash
cd backend-bootstrap

# Edit variables as needed, then:
terraform init
terraform apply -auto-approve
```

After bootstrap, copy the printed `backend_config_snippet` values into `backend-config/dev.hcl`, `staging.hcl`, `prod.hcl`.

---

## Local Deployment

```bash
cd envs/dev

# Authenticate
az login
az account set --subscription <SUB_ID>

# Init with remote backend
terraform init -backend-config=../../backend-config/dev.hcl -reconfigure

# Plan
terraform plan -var-file=dev.tfvars -out=tfplan

# Apply
terraform apply tfplan
```

---

## Key Variables to Set Before First Deploy

Edit `envs/<env>/<env>.tfvars` and replace the placeholder values:

| Variable | Where to get it |
|---|---|
| `metastore_id` | `databricks metastores list` |
| `cluster_single_user_name` | SP application ID or user email (dev only) |
| `existing_databricks_access_connector_name` | If Databricks auto-created one in managed RG |
| `existing_databricks_access_connector_resource_group_name` | Managed resource group name |
| `subscription_id` | `az account show --query id -o tsv` |
| `alert_email` | Your team's alert email |

---

## Environment Strategy

| Env | Branch | Replication | Cluster | Budget |
|---|---|---|---|---|
| dev | develop | LRS | Single-node (Standard_D4ds_v5) | off |
| staging | staging | ZRS + versioning | Autoscale job 1–4 workers | $500/mo |
| prod | main | GRS + versioning | Autoscale job 2–8 workers + instance pool | $2000/mo |

---

## Important Notes From Lab Experience

**Access Connector:** When you provision a Databricks workspace, Azure automatically creates an Access Connector in the managed resource group. Set `existing_databricks_access_connector_name` and `existing_databricks_access_connector_resource_group_name` in tfvars to reuse it rather than creating a duplicate.

**File Events RBAC:** Unity Catalog External Locations require 4 roles on the storage account — not just `Storage Blob Data Contributor`. The security module assigns all four: `Storage Blob Data Contributor`, `Storage Account Contributor`, `EventGrid EventSubscription Contributor`, `Storage Queue Data Contributor`.

**Single-Node Clusters:** `data_security_mode = "SINGLE_USER"` is required for num_workers=0 clusters. `USER_ISOLATION` is invalid for single-node and will error at plan time.

**ADF Schema Import:** The bronze sink dataset has no schema defined. This is intentional — ADF cannot read schema from a file that doesn't exist yet. The Copy activity creates the file fresh.

**Storage Credential CLI:** `CREATE STORAGE CREDENTIAL` SQL is no longer supported in recent Databricks versions. Terraform's `databricks_storage_credential` resource handles this correctly via the REST API.

**RBAC Scope:** `az role assignment list --assignee <id>` returns nothing without `--scope`. Always specify the full storage account resource path when verifying.

---

## Module Reference

| Module | Purpose |
|---|---|
| `naming` | Consistent resource names + tags |
| `networking` | VNet, delegated subnets, NSGs with Databricks rules, private DNS |
| `storage` | ADLS Gen2, containers, lifecycle, private endpoints, diagnostics |
| `security` | Access Connector (new or existing), ADF UAMI, 4 storage RBAC roles |
| `keyvault` | Premium KV, RBAC auth, private endpoint, ADF + Databricks access |
| `databricks` | Premium workspace, VNet injection, private endpoint, diagnostics |
| `databricks_unity` | Storage credential, external locations, catalog, schemas, grants, clusters/jobs |
| `adf` | ADF instance, linked services, pipeline, managed private endpoints |
| `monitoring` | Log Analytics, action group |
| `governance` | Subscription budget (optional) |
