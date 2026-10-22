resource "helm_release" "envoy_gateway" {
  name             = "envoy-gateway"
  repository       = "oci://docker.io/envoyproxy"
  chart            = "gateway-helm"
  version          = "v1.9.2"
  namespace        = "envoy-gateway-system"
  create_namespace = false

  values = [
    yamlencode({
      deployment = {
        envoyGateway = {
          resources = {
            limits = {
              cpu    = "200m"
              memory = "1024Mi"
            }
          }
        }
      }
    })
  ]
}

