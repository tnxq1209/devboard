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

variable "kubernetes_version" {
  description = "Kubernetes version for EKS."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the DevBoard VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "node_instance_types" {
  description = "EC2 instance types for the EKS managed node group."
  type        = list(string)
  default     = ["c7i-flex.large"]
}

variable "node_desired_size" {
  description = "Desired number of EKS worker nodes."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of EKS worker nodes."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of EKS worker nodes."
  type        = number
  default     = 3
}

variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "10.3.0"
}

variable "envoy_chart_version" {
  description = "Envoy Gateway Helm chart version"
  type        = string
  default     = "v1.9.2"
}
