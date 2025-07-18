variable "project_id" {
  description = "The Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "The Google Cloud region"
  type        = string
  default     = "europe-west3"
}

variable "zone" {
  description = "The Google Cloud zone"
  type        = string
  default     = "europe-west3-a"
}

// GKE Cluster variables for authentication
variable "gke_cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "gke_cluster_location" {
  description = "Location (zone or region) of the GKE cluster"
  type        = string
}

variable "gcp_secret_name" {
  type = string
  default = "gcp-secret-manager-creds"
}

variable "gcp_secret_key" {
  type    = string
  default = "key.json"
}