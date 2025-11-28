# Infrastructure Deployment Guide

This document explains how to provision the Google Cloud resources and supporting assets used by the Projet M2 BI platform. Follow these steps after cloning the repository and authenticating with Google Cloud.

## Prerequisites

- [OpenTofu](https://opentofu.org/) or [Terraform](https://www.terraform.io/) installed
- [uv](https://docs.astral.sh/uv/) package manager installed
- [mise](https://mise.jdx.dev/) task runner installed
- Google Cloud SDK (`gcloud`) installed and authenticated
- A GCP project with billing enabled
- Permissions to create resources in BigQuery, Cloud Storage, and IAM

## Deployment Steps

### Automated setup with `mise`

Most of the repetitive setup can be automated through the tasks declared in `mise.toml`:

1. **Sync local env vars:** `mise run sync_env` copies `.env.example` to `.env` and highlights new placeholders.
2. **Authenticate gcloud:** `mise run gcloud:auth` ensures the CLI is logged in, sets the active project from `.env`, and prepares application-default credentials for OpenTofu.
3. **Provision the Terraform state bucket:** `mise run gcloud:provide_state_bucket` idempotently creates `gs://${TERRAFORM_STATE_BUCKET}` (using the optional `TERRAFORM_STATE_BUCKET_LOCATION`) via `gcloud storage buckets create`.
4. **Initialize Infrastructure:** `mise run infra:init` initializes OpenTofu/Terraform with the correct backend configuration.
5. **Plan Infrastructure:** `mise run infra:plan` shows the changes that will be applied.
6. **Apply Infrastructure:**
   ```bash
   tofu -chdir=infrastructure apply
   ```
7. **Export Outputs:** `mise run infra:outputs` exports the Terraform outputs to `infrastructure/terraform-outputs.json`.
8. **Generate Configurations:**
   ```bash
   mise run dbt:render_profiles
   mise run prefect:render_configs
   ```
   This generates `dbt/profiles.yml` and `prefect.yml` using the Terraform outputs and environment variables.
9. **Setup Prefect Blocks:**
   ```bash
   mise run prefect:setup_blocks --save
   ```
   This creates the necessary Prefect blocks (GCP credentials, BigQuery targets, dbt profiles) for your flows.

### Manual Steps (Underlying Workflow)

You can still perform the steps manually if you prefer; the remainder of this guide documents the underlying workflow.

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd projet-m2-bi
   ```

2. **Configure variables**
   Ensure `.env` is set up correctly. `mise` uses `.env` to populate environment variables.

3. **Initialize and apply the infrastructure**
   ```bash
   cd infrastructure
   tofu init -backend-config="bucket=<your-state-bucket>"
   tofu plan
   tofu apply
   ```

4. **Export Terraform outputs**
   ```bash
   tofu output -json > terraform-outputs.json
   ```

5. **Generate dbt profiles and Prefect blocks**
   
   The project uses `scripts/render_template` and `scripts/setup_prefect_blocks.py` to generate configurations.

   **Render templates:**
   ```bash
   uv run scripts/render_template dbt/profiles.tpl.yml
   uv run scripts/render_template prefect.tpl.yml
   ```

   **Setup Prefect Blocks:**
   ```bash
   uv run scripts/setup_prefect_blocks.py --profiles dbt/profiles.yml --service-account .secrets/sa_key.json --save
   ```

## Notes

- The Terraform remote state uses a GCS bucket; ensure the bucket exists or bootstrap it locally before switching to the remote backend.
- Service account keys must remain outside version control (the `.secrets` directory is ignored by `.gitignore`).
- The setup module automatically detects all targets from the template and creates corresponding Prefect blocks.
- For production-grade deployments, automate these steps via CI/CD pipelines and secret managers.
