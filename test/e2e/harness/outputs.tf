output "availability_zone" {
  description = "Primary AZ used by framework EC2 instances."
  value       = aws_subnet.private[0].availability_zone
}

output "db_subnet_group_name" {
  description = "RDS subnet group spanning the private harness subnets."
  value       = aws_db_subnet_group.this.name
}

output "enable_lb" {
  description = "Whether the generated framework tfvars should include the ALB case."
  value       = var.enable_lb
}

output "enable_nlb" {
  description = "Whether the generated framework tfvars should include the optional NLB case."
  value       = var.enable_nlb
}

output "enable_rds" {
  description = "Whether the generated framework tfvars should include the RDS case."
  value       = var.enable_rds
}

output "framework_instance_profile_name" {
  description = "Permission-minimal instance profile for framework-managed EC2 instances."
  value       = aws_iam_instance_profile.framework.name
}

output "framework_security_group_id" {
  description = "Security group for private framework EC2 instances."
  value       = aws_security_group.framework.id
}

output "key_name" {
  description = "EC2 key pair name shared by the runner and framework instances."
  value       = aws_key_pair.this.key_name
}

output "key_path" {
  description = "Local generated private key path used by e2e scripts."
  value       = local_sensitive_file.private_key.filename
  sensitive   = true
}

output "kms_alias_name" {
  description = "KMS alias name without the alias/ prefix, as required by the framework tfvars."
  value       = local.project
}

output "kms_alias_full_name" {
  description = "Full KMS alias resource name."
  value       = aws_kms_alias.this.name
}

output "load_balancer_security_group_id" {
  description = "Security group for the internal ALB."
  value       = aws_security_group.load_balancer.id
}

output "name_prefix" {
  description = "Harness name prefix."
  value       = var.name_prefix
}

output "private_subnet_id" {
  description = "Primary private subnet used by framework EC2 instances."
  value       = aws_subnet.private[0].id
}

output "private_subnet_ids" {
  description = "Private subnets used by RDS and internal load balancers."
  value       = aws_subnet.private[*].id
}

output "project" {
  description = "Project tag value for the e2e run."
  value       = local.project
}

output "rds_security_group_id" {
  description = "Security group for the RDS instance."
  value       = aws_security_group.rds.id
}

output "region" {
  description = "Normalized AWS region used by the harness."
  value       = local.region
}

output "runner_private_ip" {
  description = "Private IP of the runner, or null when use_runner=false."
  value       = try(aws_instance.runner[0].private_ip, null)
}

output "runner_public_ip" {
  description = "Public IP of the runner, or null when use_runner=false."
  value       = try(aws_instance.runner[0].public_ip, null)
}

output "use_runner" {
  description = "Whether the runner EC2 was requested."
  value       = var.use_runner
}

output "vpc_id" {
  description = "Throwaway VPC ID."
  value       = aws_vpc.this.id
}
