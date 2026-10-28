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
  default     = "1.37"
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

variable "node_disk_size" {
  description = "Root volume per node, GiB. 30 rather than 20: Ollama's ~1.3 GB model plus three app images plus the ArgoCD/ESO/Envoy control planes get close to disk-pressure eviction on 20."
  type        = number
  default     = 30
}
