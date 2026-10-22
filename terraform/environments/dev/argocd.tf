resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "oci://ghcr.io/argoproj/argo-helm"
  chart            = "argo-cd"
  version          = "10.3.0"
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

  depends_on = [
    module.eks
  ]
}
