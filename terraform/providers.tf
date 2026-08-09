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
