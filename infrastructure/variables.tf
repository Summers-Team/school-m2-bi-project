variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west9"
}


variable "ingested_data_bucket" {
  description = "GCS bucket name for ingested data"
  type        = string
}

variable "dev_suffix" {
  description = "Suffix for BigQuery dataset ID for dev"
  type        = string
  default     = "bi_dataset_dev_id"
}

variable "prod_suffix" {
  description = "Suffix for BigQuery dataset ID for prod"
  type        = string
  default     = "bi_dataset_prod_id"
}

variable "sa_dbt_id" {
  description = "Service account account_id (local part) for DBT"
  type        = string
  default     = "projet-bi-dbt-sa"
}
