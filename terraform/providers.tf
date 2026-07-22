# Aliased regional provider. The module supports us_east_1 only.

provider "aws" {

  // Define the provider, using an alias, targeting a specific region
  alias = "us_east_1"

  // Specify the region to connect to.
  region = "us-east-1"

  // Stamp the deployment-identity tags onto every taggable resource.
  default_tags {
    tags = local.deployment_tags
  }
}
