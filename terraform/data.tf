# Pre-existing infrastructure lookups. Managed-capability names are excluded from these
# lookups so a managed reference is never resolved as pre-existing.

#region ------ [ aws_ssm_parameter (image catalog) ] ------------------------------------------- #

#region ------ [ aws_ssm_parameter.us_east_1_ami - us-east-1 ] --------------------------------- #

data "aws_ssm_parameter" "us_east_1_ami" {

  # Resolve every distinct catalog selector used by a US-East-1 system. Keyed by selector rather
  # than by system, so systems sharing an image share one read.
  provider = aws.us_east_1
  for_each = toset([
    for system in var.all_systems : system.ami
    if !startswith(system.ami, "ami-") &&
    replace(system.region, "-", "_") == "us_east_1"
  ])

  # The key is computed from the selector, never searched for. A misspelled family or a version
  # that was never published fails the plan here with ParameterNotFound - which is the point:
  # there is no fallback that could quietly substitute a different image.
  name = local.ami_parameter_name[each.value]

}

#endregion --- [ aws_ssm_parameter.us_east_1_ami - us-east-1 ] --------------------------------- #

#endregion --- [ aws_ssm_parameter (image catalog) ] ------------------------------------------- #


#region ------ [ aws_ami (verification) ] ------------------------------------------------------ #

#region ------ [ aws_ami.us_east_1_verified - us-east-1 ] -------------------------------------- #

data "aws_ami" "us_east_1_verified" {

  # Every image the framework launches is fetched by exact id and checked before use, whether the
  # id was pinned in tfvars or resolved from the catalog above. This is also the lookup the rest
  # of the plan reads image attributes from, so verification cannot be bypassed by accident.
  provider = aws.us_east_1
  for_each = toset([
    for system in var.all_systems : system.ami
    if replace(system.region, "-", "_") == "us_east_1"
  ])

  # Module-owned (ADR repo/0001). An id says nothing about who produced it, so pinning the owner
  # is what stops a look-alike in an unrelated account being launched on a matching id alone.
  #
  # A catalog selector only ever resolves to an image the deploying account published, so it is
  # held to "self". A literal id is the escape hatch for images this framework did not build, so
  # it additionally accepts the vendor accounts in local.direct_ami_owners.
  owners = startswith(each.value, "ami-") ? local.direct_ami_owners : ["self"]

  filter {
    name = "image-id"
    values = [
      startswith(each.value, "ami-")
      ? each.value
      : data.aws_ssm_parameter.us_east_1_ami[each.value].insecure_value
    ]
  }

  lifecycle {

    # A pointer aimed at a deregistered or still-pending image resolves fine and then fails at
    # apply; catching it here keeps the failure in the plan.
    postcondition {
      condition     = self.state == "available"
      error_message = "AMI selector '${each.value}' resolved to image ${self.id}, which is in state '${self.state}' rather than 'available'."
    }

    # The publisher stamps what it built; the selector says what was asked for. Comparing them
    # catches a mis-wired catalog pointer - the one failure an id alone cannot reveal. Literal
    # ids are exempt: they address an image directly and make no claim about a family.
    #
    # An image carrying no family stamp at all is not treated as a mismatch. Every image the
    # publisher produces is stamped (its own monotonicity guard reads the tag back), so an
    # unstamped image is a hand-built one in this account rather than a bad publish - and
    # owners = ["self"] above is what bounds that case.
    postcondition {
      condition = (
        startswith(each.value, "ami-") ||
        try(self.tags["ImageFamily"], null) == null ||
        self.tags["ImageFamily"] == split("@", each.value)[0]
      )
      error_message = "Catalog mismatch: selector '${each.value}' resolved to image ${self.id}, stamped family '${try(self.tags["ImageFamily"], "<untagged>")}'."
    }

    # A truncated selector accepts drift below the level it pins, so the stamped version must
    # either equal the requested one or extend it by a further segment. "8.10" accepts
    # "8.10.20260808"; it does not accept "8.11".
    postcondition {
      condition = (
        !strcontains(each.value, "@") ||
        try(self.tags["ImageVersion"], null) == null ||
        self.tags["ImageVersion"] == split("@", each.value)[1] ||
        startswith(self.tags["ImageVersion"], "${split("@", each.value)[1]}.")
      )
      error_message = "Catalog mismatch: selector '${each.value}' resolved to image ${self.id}, stamped version '${try(self.tags["ImageVersion"], "<untagged>")}'."
    }

  }

}

#endregion --- [ aws_ami.us_east_1_verified - us-east-1 ] -------------------------------------- #

#endregion --- [ aws_ami (verification) ] ------------------------------------------------------ #


#region ------ [ aws_kms_alias ] --------------------------------------------------------------- #

#region ------ [ aws_kms_alias.us_east_1 - us-east-1 ] ----------------------------------------- #

data "aws_kms_alias" "us_east_1" {

  # Iterate through all KMS Aliases in the US-East-1 region.
  provider = aws.us_east_1
  for_each = toset(distinct(concat(
    [
      for system in var.all_systems : system.aws_kms_alias
      if replace(system.region, "-", "_") == "us_east_1"
    ],
    [
      for database in var.all_databases : database.aws_kms_alias
      if replace(database.region, "-", "_") == "us_east_1"
    ],
  )))

  # Define the KMS Alias Properties
  name = "alias/${each.value}"

}

#endregion --- [ aws_kms_alias.us_east_1 - us-east-1 ] ----------------------------------------- #

#endregion --- [ aws_kms_alias ] --------------------------------------------------------------- #


#region ------ [ aws_key_pair ] ---------------------------------------------------------------- #

#region ------ [ aws_key_pair.us_east_1 - us-east-1 ] ------------------------------------------ #

data "aws_key_pair" "us_east_1" {

  # Iterate through all EC2 Key Pairs in the US-East-1 region.
  provider = aws.us_east_1
  for_each = toset([
    for system in var.all_systems : system.key_name
    if replace(system.region, "-", "_") == "us_east_1"
  ])

  # Define the EC2 Key Pair Properties
  key_name = each.value

}

#endregion --- [ aws_key_pair.us_east_1 - us-east-1 ] ------------------------------------------ #

#endregion --- [ aws_key_pair ] ---------------------------------------------------------------- #


#region ------ [ aws_subnet ] ------------------------------------------------------------------ #

#region ------ [ aws_subnet.us_east_1 - us-east-1 ] -------------------------------------------- #

data "aws_subnet" "us_east_1" {

  # Iterate through all Subnets in the US-East-1 region. Needs ec2:DescribeSubnets, already
  # covered by the read-only statement in the consumer deploy policies.
  #
  # VPC, CIDR block, and availability zone come from here: this framework consumes pre-created
  # subnets and the consumer no longer restates any of that metadata alongside the id.
  provider = aws.us_east_1
  for_each = toset([
    for system in var.all_systems : system.subnet_id
    if replace(system.region, "-", "_") == "us_east_1"
  ])

  # Define the Subnet Properties
  id = each.value

}

#endregion --- [ aws_subnet.us_east_1 - us-east-1 ] -------------------------------------------- #

#endregion --- [ aws_subnet ] ------------------------------------------------------------------ #


#region ------ [ aws_iam_instance_profile ] ---------------------------------------------------- #

#region ------ [ aws_iam_instance_profile.us_east_1 - us-east-1 ] ------------------------------ #

data "aws_iam_instance_profile" "us_east_1" {

  # Iterate through all IAM Instance Profiles in the US-East-1 region.
  provider = aws.us_east_1
  for_each = toset([
    for system in var.all_systems : system.iam_instance_profile
    if replace(system.region, "-", "_") == "us_east_1"
  ])

  # Define the IAM Instance Profile Properties
  name = each.value

}

#endregion --- [ aws_iam_instance_profile.us_east_1 - us-east-1 ] ------------------------------ #

#endregion --- [ aws_iam_instance_profile ] ---------------------------------------------------- #
