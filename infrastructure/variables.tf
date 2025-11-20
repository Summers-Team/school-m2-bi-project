variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west9"
}

variable "state_bucket" {
  description = "GCS bucket for Terraform state (must exist prior to remote backend init)"
  type        = string
}

variable "ingested_data_bucket" {
  description = "GCS bucket name for ingested data"
  type        = string
}

variable "bq_dev_dataset_id" {
  description = "BigQuery dataset ID for dev"
  type        = string
  default     = "bi_dataset_dev_id"
}

variable "bq_prod_dataset_id" {
  description = "BigQuery dataset ID for prod"
  type        = string
  default     = "bi_dataset_prod_id"
}

variable "sa_account_id" {
  description = "Service account account_id (local part) for DBT"
  type        = string
  default     = "projet-m2-bi-dbt-sa"
}

variable "sa_key_path" {
  description = "Local path where the service account key JSON will be stored (not created by TF)"
  type        = string
  default     = ".secrets/sa_key.json"
}