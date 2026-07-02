#% =========================================================================================== %#
#% = File: 02-provider-aws.tf                                    | Category: Providers (00-09) %#
#% ----- [ Description ] --------------------------------------------------------------------- %#
#% =========================================================================================== %#

provider "aws" {

  // Define the provider, using an alias, targeting a specific region.
  alias = "us_west_2"

  // Specify the region to connect to.
  region = "us-west-2"

}

provider "aws" {

  // Define the provider, using an alias, targeting a specific region
  alias = "us_east_1"

  // Specify the region to connect to.
  region = "us-east-1"
}
