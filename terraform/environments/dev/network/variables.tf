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

variable "vpc_cidr" {
  description = "CIDR block for the DevBoard VPC."
  type        = string
  default     = "10.0.0.0/16"
}
