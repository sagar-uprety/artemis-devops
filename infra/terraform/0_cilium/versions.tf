terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "~> 7.1.1"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.1.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0.2"
    }
  }
  
  backend "gcs" {
    bucket  = "containersecwiz"
    prefix  = "tfstate/artemis_init"
  }
}
