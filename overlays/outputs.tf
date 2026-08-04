output "network_aliases" {
  description = "Framework-ready alias map. vpc_id is always non-null so framework teardown never needs a DescribeSubnets lookup."
  value = {
    for name, network in local.ephemeral_networks : name => {
      subnet_id         = aws_subnet.us_east_1[name].id
      vpc_id            = aws_vpc.us_east_1[name].id
      subnet_cidr       = network["subnet_cidr"]
      availability_zone = network["availability_zone"]
    }
  }
}

output "subnet_ids" {
  description = "Created subnet ids keyed by symbolic network name."
  value       = { for name, subnet in aws_subnet.us_east_1 : name => subnet.id }
}

output "vpc_ids" {
  description = "Created VPC ids keyed by symbolic network name."
  value       = { for name, vpc in aws_vpc.us_east_1 : name => vpc.id }
}

output "deployment_tags" {
  description = "Deployment identity tags shared with the framework root."
  value       = local.deployment_tags
}
