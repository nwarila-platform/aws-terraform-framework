#% =========================================================================================== %#
#% = File: 02-providers-aws.tf                                   | Category: Providers (00-09) %#
#% ----- [ Description ] --------------------------------------------------------------------- %#
#% =========================================================================================== %#

provider "aws" {

  // Define the provider, using an alias, targetting a specific region.
  alias = "us_iso_west_1"

  // Specify the region to connect to.
  region = "us-iso-west-1"

}

provider "aws" {

  // Define the provider, using an alias, targetting a specific region
  alias = "us_iso_east_1"

  // Specify the region to connect to.
  region = "us-iso-east-1"
}