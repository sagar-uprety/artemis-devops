output "gcp_secret_manager_creds_name" {
  value = kubernetes_secret.gcp_secret_manager_creds.metadata[0].name
}