# Pre-existing infrastructure lookups. Managed-capability names are excluded from these
# lookups so a managed reference is never resolved as pre-existing.

#region ------ [ aws_ami (self-built) ] -------------------------------------------------------- #

#region ------ [ aws_ami.us_east_1_selfbuilt - us-east-1 ] ------------------------------------- #

data "aws_ami" "us_east_1_selfbuilt" {

  # Iterate through all Self-Built Amazon Machine Images in the US-East-1 region.
  provider = aws.us_east_1
  for_each = toset([
    for system in var.all_systems : system.ami
    if !local.ami_specs[system.ami].is_direct_id &&
    !local.ami_specs[system.ami].is_public_alias &&
    replace(system.region, "-", "_") == "us_east_1"
  ])

  # Define the Self-Built Amazon Machine Image Properties
  most_recent = true
  name_regex  = local.ami_specs[each.value].name_regex

  # Self-owned AMIs in the deploying account.
  owners = ["self"]

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "image-type"
    values = ["machine"]
  }

  # The glob template is assembled in local.ami_specs, so a future naming-delimiter change
  # stays localized there.
  filter {
    name   = "name"
    values = [local.ami_specs[each.value].glob]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

}

#endregion --- [ aws_ami.us_east_1_selfbuilt - us-east-1 ] ------------------------------------- #

#endregion --- [ aws_ami (self-built) ] -------------------------------------------------------- #


#region ------ [ aws_ami (public base) ] ------------------------------------------------------- #

#region ------ [ aws_ami.us_east_1_public - us-east-1 ] ---------------------------------------- #

data "aws_ami" "us_east_1_public" {

  # Iterate through all Public Base Amazon Machine Images in the US-East-1 region.
  provider = aws.us_east_1
  for_each = toset([
    for system in var.all_systems : system.ami
    if local.ami_specs[system.ami].is_public_alias &&
    replace(system.region, "-", "_") == "us_east_1"
  ])

  # Define the Public Base Amazon Machine Image Properties
  most_recent = true
  name_regex  = local.public_ami_name_regex[each.value]

  # Module-owned: this framework consumes Amazon's public images only, so there is nothing
  # here for a consumer to vary.
  owners = ["amazon"]

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "image-type"
    values = ["machine"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

}

#endregion --- [ aws_ami.us_east_1_public - us-east-1 ] ---------------------------------------- #

#endregion --- [ aws_ami (public base) ] ------------------------------------------------------- #


#region ------ [ aws_ami (direct id) ] --------------------------------------------------------- #

#region ------ [ aws_ami.us_east_1_direct - us-east-1 ] ---------------------------------------- #

data "aws_ami" "us_east_1_direct" {

  # Iterate through all Direct Amazon Machine Image IDs in the US-East-1 region.
  provider = aws.us_east_1
  for_each = toset([
    for system in var.all_systems : system.ami
    if local.ami_specs[system.ami].is_direct_id &&
    replace(system.region, "-", "_") == "us_east_1"
  ])

  # Define the Direct Amazon Machine Image Properties. A pinned id identifies exactly one image,
  # so the architecture, image-type, root-device-type and state filters the other two AMI blocks
  # need to narrow a name match have nothing left to narrow here.
  filter {
    name   = "image-id"
    values = [each.value]
  }

}

#endregion --- [ aws_ami.us_east_1_direct - us-east-1 ] ---------------------------------------- #

#endregion --- [ aws_ami (direct id) ] --------------------------------------------------------- #


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
    nonsensitive([
      for database in var.all_databases : database.aws_kms_alias
      if replace(database.region, "-", "_") == "us_east_1"
    ]),
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
