terraform {
  backend "gcs" {
    bucket = "test-terraform-473818-tfstate"
    prefix = "terraform/state"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = "test-terraform-473818"
  region  = "europe-west9"
}

# Terraform state bucket
resource "google_storage_bucket" "terraform_state" {
  name          = "test-terraform-473818-tfstate"
  location      = "europe-west9"
  force_destroy = true

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Ingested data bucket
resource "google_storage_bucket" "ingested_data" {
 name          = "test-terraform-473818-ingested-data"
 location      = "europe-west9"
 storage_class = "STANDARD"

 uniform_bucket_level_access = true
}

# Test on local csv file
resource "google_storage_bucket_object" "default" {
 name         = "test.csv"
 source       = "test.csv"
 content_type = "text/plain"
 bucket       = google_storage_bucket.ingested_data.id
}

# Dev dataset
resource "google_bigquery_dataset" "dev_dataset" {
  dataset_id                  = "test_terraform_473818_dev"
  location                    = "europe-west9"
  description                 = "Development dataset for BI project"
  friendly_name               = "BI Dataset (dev)"
  default_table_expiration_ms = 7776000000 # 90 days
}

# Prod dataset
resource "google_bigquery_dataset" "prod_dataset" {
  dataset_id    = "test_terraform_473818_prod"
  location      = "europe-west9"
  description   = "Production dataset for BI project"
  friendly_name = "BI Dataset (prod)"
}

# Service account for dbt and minimal IAM bindings
resource "google_service_account" "dbt_sa" {
  account_id   = "test-terraform-473818-sa"
  display_name = "DBT service account"
}

# Grant permissions required for dbt workflows (adjust as needed)
resource "google_project_iam_member" "sa_bq_dataeditor" {
  project = "test-terraform-473818"
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.dbt_sa.email}"
}

resource "google_project_iam_member" "sa_bq_jobuser" {
  project = "test-terraform-473818"
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.dbt_sa.email}"
}

resource "google_project_iam_member" "sa_storage_admin" {
  project = "test-terraform-473818"
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.dbt_sa.email}"
}