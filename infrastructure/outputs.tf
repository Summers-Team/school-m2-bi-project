output "bq_dev_dataset_id" {
  description = "BigQuery dev dataset ID"
  value       = google_bigquery_dataset.dev_dataset.dataset_id
}

output "bq_prod_dataset_id" {
  description = "BigQuery prod dataset ID"
  value       = google_bigquery_dataset.prod_dataset.dataset_id
}