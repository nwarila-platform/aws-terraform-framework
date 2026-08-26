# Exact toolchain pins. The org repo-hygiene gate keys on this filename; the lockfile
# carries multi-platform hashes for the pinned provider build.

terraform {

  # Declare minimum Terraform version.
  required_version = "= 1.15.1"

  # Declare minimum AWS version.
  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "= 6.47.0"
    }

    # Resolves debug_dns_names to the addresses that may reach the fleet. Terraform has no
    # built-in resolver, so a name can only become a rule through a provider.
    dns = {
      source  = "hashicorp/dns"
      version = "= 3.4.3"
    }

  }

}
