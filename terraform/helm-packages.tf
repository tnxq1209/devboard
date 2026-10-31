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
        service = {
          type = "LoadBalancer"
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

resource "helm_release" "envoy_gateway" {
  name             = "envoy-gateway"
  repository       = "oci://docker.io/envoyproxy"
  chart            = "gateway-helm"
  version          = var.envoy_gateway_chart_version
  namespace        = "envoy-gateway-system"
  create_namespace = true

  values = [
    yamlencode({
      deployment = {
        envoyGateway = {
          resources = {
            request = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }
        }
      }
    })
  ]
}

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
          type = "LoadBalancer"
        }
      }
    })
  ]

  timeout = 900
  wait    = true
}

# Port-forward for Argo CD
resource "null_resource" "argocd_port_forward" {
  triggers = {
    helm_id = helm_release.argocd.id
  }

  provisioner "local-exec" {
    # Launches kubectl port-forward in the background
    # Works on Linux, macOS, and Git Bash / WSL on Windows
    command = "kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &"
  }

  depends_on = [helm_release.argocd]
}

# Port-forward for Grafana (kube-prometheus-stack)
resource "null_resource" "grafana_port_forward" {
  triggers = {
    helm_id = helm_release.kube_prometheus_stack.id
  }

  provisioner "local-exec" {
    # Grafana service name typically matches the Helm release name + '-grafana'
    command = "kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80 > /dev/null 2>&1 &"
  }

  depends_on = [helm_release.kube_prometheus_stack]
}
