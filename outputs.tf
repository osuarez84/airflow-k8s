//output "instance_SQL_ip_addr" {
//  value = google_sql_database_instance.airflow-metadata.ip_address
//  description = "The private IP address of the metadata DDBB."
//}

output "remote_logging_bucket" {
  value = google_storage_bucket.remote-logs.name
  description = "The name of the bucket for remote logging."
}