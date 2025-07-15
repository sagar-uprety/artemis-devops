// Get current authenticated account
data "google_client_config" "current" {}

// Create a Google Cloud service account for accessing Secret Manager
resource "google_service_account" "secrets_access_sa" {
  account_id   = "secrets-access-sa-artemis"
  display_name = "Secret Manager Access Service Account"
  description  = "Service account for accessing Secret Manager (will be used by ESO)"
  project      = var.project_id
}

// Grant the service account Secret Manager Secret Accessor role
// This allows reading secret values but not modifying secrets
resource "google_project_iam_member" "secretmanager_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.secrets_access_sa.email}"
}

// Create a service account key which is required for ESO to authenticate
// This key will be stored in a Kubernetes secret
resource "google_service_account_key" "secrets_access_sa_key" {
  service_account_id = google_service_account.secrets_access_sa.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

// Kubernetes namespace for External Secrets Operator resources
resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = "external-secrets"
  }
}

// Kubernetes secret with service account key
resource "kubernetes_secret" "gcp_secret_manager_creds" {
  metadata {
    name      = "gcp-secret-manager-creds"
    namespace = kubernetes_namespace.external_secrets.metadata[0].name
  }

  data = {
    "key.json" = base64decode(google_service_account_key.secrets_access_sa_key.private_key)
  }

  type = "Opaque"

  depends_on = [
    kubernetes_namespace.external_secrets,
    google_service_account_key.secrets_access_sa_key
  ]
}

// Helm chart for External Secrets Operator (ESO)
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = false
  version          = "0.19.2"
  depends_on = [kubernetes_namespace.external_secrets]
}

