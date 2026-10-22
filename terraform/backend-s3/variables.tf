variable "region" {
  description = "AWS region for DevBoard infrastructure."
  type        = string
  default     = "ap-south-1"
}

variable "bucket_name" {
  description = "Globally unique name for the Terraform state bucket."
  type        = string
  default     = null
}
