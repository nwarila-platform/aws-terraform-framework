#% =========================================================================================== %#
#% = File: 00-providers.tf                                       | Category: Providers (00-09) %#
#% ----- [ Description ] --------------------------------------------------------------------- %#
#% =========================================================================================== %#
terraform {

  // Declare minimum Terraform version.
  required_version = "= 1.15.1"

  // Store state file in S3 bucket.
  backend "s3" {}

  // Declare minimum AWS version.
  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "= 6.47.0"
    }

  }

}
