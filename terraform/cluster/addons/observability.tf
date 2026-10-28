resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "oci://ghcr.io/prometheus-community/charts"
  chart            = "kube-prometheus-stack"
  version          = var.kube_prom_stack_version
  namespace        = "monitoring"
  create_namespace = true

  values = [
    yamlencode({
      grafana = {
        persistence = {
          enabled          = true
          type             = "pvc"
          size             = "3Gi"
          storageClassName = "gp3"
        }
      }

      prometheus = {
        prometheusSpec = {
          retention = "7d"

          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp3"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "5Gi"
                  }
                }
              }
            }
          }
        }
      }

      alertmanager = {
        alertmanagerSpec = {
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp3"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "2Gi"
                  }
                }
              }
            }
          }
        }
      }
    })
  ]

  timeout = 900
  wait    = true
}

