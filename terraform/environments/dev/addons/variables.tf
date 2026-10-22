variable "region" {
  description = "AWS region for DevBoard"
  type        = string
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "Name of the existing EKS cluster"
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

