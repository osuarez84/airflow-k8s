provider "google" {
  project = "buoyant-embassy-260717"
  region  = "europe-west1"
  zone    = "europe-west1-b"
  credentials = file("service_account.json")
}


resource "google_service_account" "default" {
  account_id   = "service-account-id"
  display_name = "Service Account"
}

resource "google_container_cluster" "primary" {
  name     = "my-gke-cluster"

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
  network = google_compute_network.private-k8s-network.name
  subnetwork = google_compute_subnetwork.k8s-subnetwork.name
  ip_allocation_policy {
    cluster_secondary_range_name  = "services-range"
    services_secondary_range_name = google_compute_subnetwork.k8s-subnetwork.secondary_ip_range.1.range_name
  }


}

# TODO
# Check the k8s VPC by default ¿?
resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "my-node-pool"
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.default.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

# Create a bucket for the remote logs
resource "google_storage_bucket" "remote-logs" {
  name          = "airflow-remote-logs-${random_id.suffix.hex}"
  location      = "EU"
  force_destroy = true

  uniform_bucket_level_access = true
}


# Add this vpc to the k8s cluster?
resource "google_compute_network" "private-k8s-network" {
  name = "k8s-private-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "k8s-subnetwork" {
  name          = "k8s-subnetwork"
  ip_cidr_range = "10.2.0.0/16"
  region        = "europe-west1"
  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = "192.168.1.0/24"
  }

  secondary_ip_range {
    range_name    = "pod-ranges"
    ip_cidr_range = "192.168.64.0/22"
  }

  network       = google_compute_network.private-k8s-network.id
}

//#######################
//# SQL Metadata database
//#######################
//
//resource "google_compute_global_address" "sql-private-ip-address" {
//  name          = "private-ip-address"
//  purpose       = "VPC_PEERING"
//  address_type  = "INTERNAL"
//  prefix_length = 16
//  network       = google_compute_network.private-k8s-network.id
//}
//
//resource "google_service_networking_connection" "private_vpc_connection" {
//  network                 = google_compute_network.private-k8s-network.id
//  service                 = "servicenetworking.googleapis.com"
//  reserved_peering_ranges = [google_compute_global_address.sql-private-ip-address.name]
//}
//
//
//# TODO
//# Generate the VM to connect to the SQL instance for testing
//# https://cloud.google.com/sql/docs/postgres/connect-compute-engine#connect-gce-proxy
//
//
//resource "google_sql_database_instance" "airflow-metadata" {
//  name             = "airflow-metadata-${random_id.suffix.hex}"
//  database_version = "POSTGRES_12"
//  deletion_protection = false
//
//  depends_on = [google_service_networking_connection.private_vpc_connection]
//
//  settings {
//    # Second-generation instance tiers are based on the machine
//    # type. See argument reference below.
//    tier = "db-g1-small"
//    availability_type = "REGIONAL"
//    ip_configuration {
//      ipv4_enabled = false
//      private_network = google_compute_network.private-k8s-network.id
//    }
//  }
//}
//
//
//# Create the DDBB and the user
//resource "google_sql_database" "airflow-ddbb" {
//  name     = "airflow"
//  instance = google_sql_database_instance.airflow-metadata.name
//}
//
//# Those should be secrets
//resource "google_sql_user" "airflow-user" {
//  name     = "airflow"
//  instance = google_sql_database_instance.airflow-metadata.name
//  password = "airflow"
//}