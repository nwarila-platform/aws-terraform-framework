#% =========================================================================================== %#
#% = File: 02-provider-aws.tf                                    | Category: Providers (00-09) %#
#% ----- [ Description ] --------------------------------------------------------------------- %#
#% =========================================================================================== %#

provider "aws" {

  // Define the provider, using an alias, targeting a specific region.
  alias = "us_west_2"

  // Specify the region to connect to.
  region = "us-west-2"

  // Stamp the deployment-identity tags (var.resource_metadata) onto every taggable resource this
  // provider manages. Resource-level tags win on key collision, and EC2 root_block_device tags
  // cannot inherit these, so 32-locals-aws.tf merges them there directly. Empty map when
  // resource_metadata is null, keeping non-opted-in consumers byte-identical.
  default_tags {
    tags = local.deployment_tags
  }

}

provider "aws" {

  // Define the provider, using an alias, targeting a specific region
  alias = "us_east_1"

  // Specify the region to connect to.
  region = "us-east-1"

  // Stamp the deployment-identity tags onto every taggable resource (see us_west_2 note above).
  default_tags {
    tags = local.deployment_tags
  }
}
