output "vpc_id" {
  description = "ID of the DevBoard VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = module.vpc.private_subnets
}

output "intra_subnet_ids" {
  description = "IDs of the intra subnets."
  value       = module.vpc.intra_subnets
}

output "cluster_name" {
  description = "Name of the DevBoard EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded EKS cluster CA."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Cluster security group ID."
  value       = module.eks.cluster_security_group_id
}

# Argocd: Initial admin password.

data "kubernetes_secret" "argocd_initial_admin_secret" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = "argocd"
  }

  depends_on = [helm_release.argocd]
}

output "argocd_admin_username" {
  value = "admin"
}

output "argocd_admin_password" {
  description = "The initial ArgoCD admin password."
  value       = sensitive(data.kubernetes_secret.argocd_initial_admin_secret.data["password"])
  sensitive   = true
}

# Grafana: Initial admin password.

data "kubernetes_secret" "grafana_initial_admin_secret" {
  metadata {
    name      = "kube-prometheus-stack-grafana"
    namespace = "monitoring"
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

output "grafana_admin_username" {
  value     = sensitive(data.kubernetes_secret.grafana_initial_admin_secret.data["admin-user"])
  sensitive = true
}

output "grafana_admin_password" {
  description = "The initial Grafana admin password."
  value       = sensitive(data.kubernetes_secret.grafana_initial_admin_secret.data["admin-password"])
  sensitive   = true
}

# Fetch Argo CD Load Balancer details
data "kubernetes_service" "argocd_lb" {
  metadata {
    name      = "argocd-server"
    namespace = "argocd"
  }
  depends_on = [helm_release.argocd]
}

# Fetch Grafana Load Balancer details
data "kubernetes_service" "grafana_lb" {
  metadata {
    name      = "kube-prometheus-stack-grafana"
    namespace = "monitoring"
  }
  depends_on = [helm_release.kube_prometheus_stack]
}

# Clear visible URLs in your console output
output "argocd_url" {
  value = "http://${data.kubernetes_service.argocd_lb.status[0].load_balancer[0].ingress[0].hostname}"
}

output "grafana_url" {
  value = "http://${data.kubernetes_service.grafana_lb.status[0].load_balancer[0].ingress[0].hostname}"
}
