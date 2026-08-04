# Aliased regional provider. The ephemeral-network root supports us_east_1 only.

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  # Stamp the same deployment identity used by the framework onto every taggable network resource.
  default_tags {
    tags = local.deployment_tags
  }
}
