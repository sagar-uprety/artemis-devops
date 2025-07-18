// Data sources for GKE cluster authentication
data "google_client_config" "default" {}

data "google_container_cluster" "primary" {
  name     = var.gke_cluster_name
  location = var.gke_cluster_location
}

// Kubernetes provider configuration for GKE
provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
}

// Helm provider configuration for GKE
provider "helm" {
  kubernetes = {
    host                   = "https://${data.google_container_cluster.primary.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
  }
}
// Google Cloud provider configuration
provider "google" {
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}

// Google Cloud provider for beta features
provider "google-beta" {
  project     = var.project_id
  region      = var.region
  zone        = var.zone
} 
