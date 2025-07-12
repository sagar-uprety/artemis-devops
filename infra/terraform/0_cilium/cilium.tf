// Helm chart for Cilium
resource "helm_release" "cilium" {
  name             = "cilium"
  repository       = "https://helm.cilium.io/"
  chart            = "cilium"
  namespace        = "kube-system"  // Using kube-system as per GKE docs
  version          = "1.18.1"       
  timeout          = 900
  create_namespace = true  // Let Helm create necessary namespaces
  
  values = [
    file("${path.module}/cilium-values.yaml")
  ]
}