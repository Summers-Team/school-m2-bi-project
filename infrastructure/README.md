# Infrastructure Deployment Guide

This document explains how to provision the Google Cloud resources and supporting assets used by the Projet M2 BI platform. Follow these steps after cloning the repository and authenticating with Google Cloud.

## Prerequisites

- [OpenTofu](https://opentofu.org/) or [Terraform](https://www.terraform.io/) installed
- [uv](https://docs.astral.sh/uv/) package manager installed
- Google Cloud SDK (`gcloud`) installed and authenticated
- A GCP project with billing enabled
- Permissions to create resources in BigQuery, Cloud Storage, and IAM

## Deployment Steps

### Quick bootstrap with `mise`

Most of the repetitive setup can be automated through the tasks declared in `mise.toml`:

1. **Sync local env vars:** `mise run sync_env` copies `.env.example` to `.env` and highlights new placeholders.
2. **Authenticate gcloud:** `mise run gcloud:auth` ensures the CLI is logged in, sets the active project from `.env`, and prepares application-default credentials for OpenTofu.
3. **Provision the Terraform state bucket:** `mise run gcloud:provide_state_bucket` idempotently creates `gs://${TERRAFORM_STATE_BUCKET}` (using the optional `TERRAFORM_STATE_BUCKET_LOCATION`) via `gcloud storage buckets create`, exactly as documented in the [Cloud Storage quickstart](https://cloud.google.com/storage/docs/discover-object-storage-gcloud#local-shell).
4. **Prepare backend prerequisites:** `mise run infra:provide_backend` depends on the previous steps, so running `mise run infra:init` or `mise run infra:plan` will automatically ensure the remote state bucket exists before touching OpenTofu.
5. **Generate the service-account key:** `mise run gcloud:create_sa_key --email <sa-email>` writes `.secrets/sa_key.json` (override with `--output` if needed, or add `--dry-run` to preview). The command reads `GCLOUD_SA_EMAIL` from the environment when the flag is omitted.
6. **Capture Terraform outputs:** `mise run infra:outputs --file infrastructure/terraform-outputs.json` runs `tofu output -json` after `infra:init` and stores the JSON alongside your IaC.

You can still perform the steps manually if you prefer; the remainder of this guide documents the underlying workflow.

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd projet-m2-bi
   ```

2. **Configure variables**
   ```bash
   cp infrastructure/terraform.tfvars.example infrastructure/terraform.tfvars
   ```
   Edit `infrastructure/terraform.tfvars` to set your project ID, state bucket name, dataset IDs, and service account settings.
   You can keep `.env` in sync with `mise run sync_env`, which ensures tasks such as `gcloud:auth` and `gcloud:provide_state_bucket` read the latest identifiers.

3. **Initialize and apply the infrastructure**
   ```bash
   cd infrastructure
   tofu init -backend-config="bucket=<your-state-bucket>"
   tofu plan
   tofu apply
   ```
   Replace `<your-state-bucket>` with the value configured in `terraform.tfvars`. The backend block already fixes the prefix to `terraform/state`.
   If you prefer task automation, run `mise run infra:init` (which depends on `gcloud:provide_state_bucket`) followed by `mise run infra:plan`/`infra:apply`.

4. **Export Terraform outputs**
   ```bash
   tofu output -json > terraform-outputs.json
   ```
   Keep this JSON file alongside the Terraform configuration (default path consumed by the profile generator). If you prefer automation, run `mise run infra:outputs --file infrastructure/terraform-outputs.json` (it defaults to that path) after `mise run infra:init` to capture the outputs.

6. **Create and store the service account key (if required)**
   ```bash
   # manual alternative if you do not use mise
   gcloud iam service-accounts keys create .secrets/sa_key.json --iam-account <sa-email>
   ```
   `<sa-email>` is available in the Terraform outputs. The setup module automatically uses `.secrets/sa_key.json` to create the GCP credentials block. You can also run `mise run gcloud:create_sa_key --email <sa-email>` (with optional `--output` and `--dry-run`) to reuse the automated workflow described above.

5. **Generate the dbt profiles and Prefect blocks**
   
   The project includes an automated setup module that:
   - Parses the dbt profile template (`dbt/profiles.tpl.yml`)
   - Detects all defined targets (dev, prod, etc.)
   - Generates local `dbt/profiles.yml` from Terraform outputs
   - Creates Prefect blocks for all targets automatically
   
   **Complete setup (local profiles + Prefect blocks):**
   ```bash
   cd ..
   uv run python -m infrastructure.setup_profiles
   ```
   
   **Or use specific modes:**
   ```bash
   # Local profiles only
   uv run python -m infrastructure.setup_profiles --local-only
   
   # Prefect blocks only
   uv run python -m infrastructure.setup_profiles --blocks-only
   ```
   
   This will create:
   - Local `dbt/profiles.yml` for command-line dbt usage
   - Prefect blocks for orchestrated workflows:
     - `gcp-credentials` - GCP service account credentials
     - `bigquery-target-configs-{target}` - BigQuery config per target
     - `dbt-cli-profile-{target}` - dbt CLI profile per target
     - `dbt-operation-run-{target}` - dbt run operation per target
     - `dbt-operation-test-{target}` - dbt test operation per target
     - `dbt-operation-debug-{target}` - dbt debug operation per target



## Setup Profiles Module

The `infrastructure/setup_profiles/` module provides automated configuration for dbt profiles and Prefect blocks with multi-target support.

**Key features:**
- Automatically detects all targets from `dbt/profiles.tpl.yml` (dev, prod, etc.)
- Generates local `dbt/profiles.yml` from Terraform outputs
- Creates Prefect blocks for each target (credentials, configs, profiles, operations)
- Supports flexible execution modes (complete, local-only, blocks-only)

See [`infrastructure/setup_profiles/README.md`](setup_profiles/README.md) for detailed usage examples and architecture documentation.

## Notes

- The Terraform remote state uses a GCS bucket; ensure the bucket exists or bootstrap it locally before switching to the remote backend.
- Service account keys must remain outside version control (the `.secrets` directory is ignored by `.gitignore`).
- The setup module automatically detects all targets from the template and creates corresponding Prefect blocks.
- For production-grade deployments, automate these steps via CI/CD pipelines and secret managers.
