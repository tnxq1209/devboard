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
