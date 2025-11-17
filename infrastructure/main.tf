

resource "google_storage_bucket" "terraform_state" {
  name          = var.state_bucket
  location      = var.region
  force_destroy = true

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Dev dataset
resource "google_bigquery_dataset" "dev_dataset" {
  dataset_id                  = var.bq_dev_dataset_id
  location                    = var.region
  description                 = "Development dataset for BI project"
  friendly_name               = "BI Dataset (dev)"
  default_table_expiration_ms = 7776000000 # 90 days
}

# Prod dataset
resource "google_bigquery_dataset" "prod_dataset" {
  dataset_id    = var.bq_prod_dataset_id
  location      = var.region
  description   = "Production dataset for BI project"
  friendly_name = "BI Dataset (prod)"
}

# Service account for dbt and minimal IAM bindings
resource "google_service_account" "dbt_sa" {
  account_id   = var.sa_account_id
  display_name = "DBT service account"
}

# Grant permissions required for dbt workflows (adjust as needed)
resource "google_project_iam_member" "sa_bq_dataeditor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.dbt_sa.email}"
}

resource "google_project_iam_member" "sa_bq_jobuser" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.dbt_sa.email}"
}

resource "google_project_iam_member" "sa_storage_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.dbt_sa.email}"
}