variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west9"
}



variable "bq_dev_dataset_id" {
  description = "BigQuery dataset ID for dev"
  type        = string
  default     = "bi_dataset_dev"
}

variable "bq_prod_dataset_id" {
  description = "BigQuery dataset ID for prod"
  type        = string
  default     = "bi_dataset_prod"
}

variable "sa_dbt_id" {
  description = "Service account account_id (local part) for DBT"
  type        = string
  default     = "projet-bi-dbt-sa"
}
