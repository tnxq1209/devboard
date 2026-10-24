resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "oci://ghcr.io/argoproj/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true

  values = [
    yamlencode({
      server = {
        extraArgs = ["--insecure"]

        service = {
          type = "ClusterIP"
        }
      }
    })
  ]

  timeout = 900
  wait    = true
}
