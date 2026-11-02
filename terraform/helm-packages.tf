# 1. Kube Prometheus Stack Helm Deployment
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

  timeout    = 900
  wait       = true
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

# 2. Argo CD Helm Deployment
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

# 3. Metrics Server Helm Deployment
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  #version    = "3.12.1" # Target the exact stable version you want

  # Optional production tuning
  values = [
    <<-EOT
    args:
      - --kubelet-insecure-tls
    resources:
      requests:
        cpu: 100m
        memory: 200Mi
    EOT
  ]
  timeout    = 600 # 10 minutes for deployment wait time
}

# 4. Helm Deployment passing the Role ARN
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"

  values = [
    <<-EOT
    autoDiscovery:
      clusterName: "${module.eks.cluster_name}"
    rbac:
      serviceAccount:
        create: true
        name: "cluster-autoscaler"
        annotations:
          # FIX: Change .iam_role_arn to .arn
          eks.amazonaws.com/role-arn: "${module.cluster_autoscaler_irsa_role.arn}"
    EOT
  ]
}
