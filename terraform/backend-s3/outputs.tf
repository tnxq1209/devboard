output "state_bucket_name" {
  description = "Name of the Terraform state bucket."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_region" {
  description = "Region containing the Terraform state bucket."
  value       = var.region
}
