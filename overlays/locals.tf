locals {
  # This tag contract is intentionally identical to terraform/locals.tf. The workflow leak gate
  # filters on repository-id and stack, so these values are operational identity, not decoration.
  deployment_tags = var.resource_metadata == null ? {} : merge(
    {
      "nwarila:management:managed-by"    = "terraform"
      "nwarila:management:repository"    = var.resource_metadata.repository
      "nwarila:management:repository-id" = var.resource_metadata.repository_id
      "nwarila:management:stack"         = var.resource_metadata.stack
      "nwarila:management:environment"   = var.environment
      "nwarila:operations:owner"         = var.resource_metadata.owner
    },
    var.resource_metadata.commit_sha == null ? {} : { "nwarila:provenance:commit-sha" = var.resource_metadata.commit_sha },
    var.resource_metadata.run_id == null ? {} : { "nwarila:provenance:run-id" = var.resource_metadata.run_id },
  )

  ephemeral_networks = {
    for name, network in var.networks : name => {
      availability_zone = network.availability_zone
      vpc_cidr          = network.vpc_cidr
      subnet_cidr       = network.subnet_cidr
      tags = merge(
        network.tags,
        {
          Name        = name
          Environment = var.environment
          Terraform   = "True"
        },
      )
    }
  }
}
