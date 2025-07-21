
// Helm chart for Connaisseur
resource "helm_release" "connaisseur" {
  name             = "connaisseur"
  repository       = "https://sse-secure-systems.github.io/connaisseur/charts"
  chart            = "connaisseur"
  namespace        = "connaisseur"
  create_namespace = true
  version          = "2.8.4"

  values = [
    file("${path.module}/values/connaisseur-values.yaml")
  ]
}

// Kubernetes namespace for Trivy resources
resource "kubernetes_namespace" "trivy" {
  metadata {
    name = "trivy"
  }
}

// Helm chart for Trivy Operator
resource "helm_release" "trivy_operator" {
  name             = "trivy-operator"
  repository       = "https://aquasecurity.github.io/helm-charts"
  chart            = "trivy-operator"
  namespace        = kubernetes_namespace.trivy.metadata[0].name
  create_namespace = false
  version          = "0.30.0"
  depends_on       = [kubernetes_namespace.trivy]

  values = [
    file("${path.module}/values/trivy-values.yaml")
  ]
}

// Helm chart for falco
resource "helm_release" "falco" {
  name             = "falco"
  repository       = "https://falcosecurity.github.io/charts"
  chart            = "falco"
  version          = "6.2.5"
  namespace        = "falco"
  create_namespace = true

  values = [
    file("${path.module}/values/falco-values.yaml")
  ]
}

// Helm chart for gatekeeper
resource "helm_release" "gatekeeper" {
  name             = "gatekeeper"
  repository       = "https://open-policy-agent.github.io/gatekeeper/charts"
  chart            = "gatekeeper"
  version          = "3.20.1"
  namespace        = "gatekeeper-system"
  create_namespace = true

   values = [
    file("${path.module}/values/gatekeeper-values.yaml")
  ]
}