variable "region" {
  description = "AWS region for DevBoard infrastructure."
  type        = string
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "devboard-eks"
}

variable "argocd_chart_version" {
  description = "Argo CD Helm chart version"
  type        = string
  default     = "10.3.0"
}

variable "envoy_gateway_chart_version" {
  description = "Envoy Gateway Helm chart version"
  type        = string
  default     = "v1.9.2"
}

variable "kube_prom_stack_version" {
  description = "Kube prometheus stack version"
  type        = string
  default     = "92.14.0"
}

variable "cluster_autoscaler_version" {
  description = "Cluster Autoscaler Helm chart version"
  type        = string
  default     = "9.35.0"
}

variable "loki_chart_version" {
  description = "Grafana Community Loki Helm chart version."
  type        = string
  default     = "21.2.3"
}

variable "alloy_chart_version" {
  description = "Grafana Alloy Helm chart version."
  type        = string
  default     = "1.16.0"
}
