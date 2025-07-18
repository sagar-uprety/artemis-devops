# Secret Store for GCP Secret Manager
# This defines how External Secrets Operator (ESO) connects to GCP Secret Manager
resource "kubernetes_manifest" "secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "SecretStore"
    metadata = {
      name      = "gcp-secret-manager"
      namespace = "external-secrets"
    }
    spec = {
      provider = {
        gcpsm = {
          projectID = var.project_id
          auth = {
            secretRef = {
              secretAccessKeySecretRef = {
                name = var.gcp_secret_name
                key  = var.gcp_secret_key
              }
            }
          }
        }
      }
    }
  }
}

# Reflector is used to sync secrets across namespaces
resource "helm_release" "reflector" {
  name             = "reflector"
  repository       = "https://emberstack.github.io/helm-charts"
  chart            = "reflector"
  namespace        = "external-secrets"
  create_namespace = false
  version          = "9.2.0-develop.18"
}

# Reloader is used to reload pods when secrets and configmaps change
resource "helm_release" "reloader" {
  name             = "reloader"
  repository       = "https://stakater.github.io/stakater-charts"
  chart            = "reloader"
  namespace        = "reloader"
  create_namespace = true
  version          = "2.2.2"

  values = [
    file("${path.module}/reloader-values.yaml")
  ]
}