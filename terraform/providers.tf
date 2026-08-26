provider "aws" {

  alias = "us_east_1"

  region = "us-east-1"

  # Identity travels in the create request, which is the only place a launch policy can see it.
  # RunInstances tags the volumes it creates from these; a resource's own tags block is applied
  # afterwards by CreateTags and never reaches the request. See local.identity_tags.
  default_tags {
    tags = local.identity_tags
  }

}

# Declared with no configuration on purpose: resolution uses the runner's own resolver, which is
# the one that agrees with what the operator sees. Pointing it at a fixed server would resolve
# names the runner itself cannot, and the addresses have to match the operator's reality.
provider "dns" {}
