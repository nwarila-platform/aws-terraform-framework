# Pre-existing infrastructure lookups. Managed-capability names are excluded from these
# lookups so a managed reference is never resolved as pre-existing.

#region ------ [ Amazon Machine Image(s) ] ---------------------------------------------------- #

#?region ------ [ Notes ] -------------------------------------------------------------------- ?#
#? 1. Because aws_ami needs to, target each region independently and uniquely indicate the     ?#
#?    target AMI I've opted to built a lookup variable 'local.amazon_machine_images' that must ?#
#?    must be updated manually to list all supported operating systems. As we build custom     ?#
#?    packer-built AMIs, this will largely become irrelevant as we can use input variables     ?#
#?    to update this data source to automatically pull release specific custom AMI.            ?#
#?endregion --- [ Notes ] -------------------------------------------------------------------- ?#

#region ------ [ Amazon Machine Image(s): Self-Built AMIs ] -------------------------------- #


data "aws_ami" "us_east_1_selfbuilt" {

  for_each = toset([
    for s in var.all_systems : s.ami
    if !local.ami_specs[s.ami].is_direct_id &&
    !local.ami_specs[s.ami].is_public_alias &&
    contains(["us_east_1", "us-east-1"], s.region)
  ])

  # Set the provider in which to deploy the instance.
  provider = aws.us_east_1

  // [Optional(Boolean)] most_recent: If more than one result is returned, use the most recent.
  most_recent = true

  # [Optional(String[])] List of AMI owners to limit search.
  # Valid values: <AWS account ID>, 'self', <AWS owner alias>
  # Self-owned AMIs in the deploying account.
  owners = ["self"]

  # [Optional(String)] Name Regex: Anchors the self-built family/version after the server-side glob.
  name_regex = local.ami_specs[each.value].name_regex

  // ===================================================================================== //
  // === Filter(s): One or more name/value pairs to filter off of.                     === //
  // ------------------------------------------------------------------------------------- //
  // All filters are optional, most filters are lists, and all of them are combined to     //
  // allow robust targeting.                                                               //
  // ===================================================================================== //

  # [String[]] Name: Self-built AMI name glob. The glob template is assembled in
  # local.ami_specs so future naming-delimiter changes are localized.
  filter {
    name   = "name"
    values = [local.ami_specs[each.value].glob]
  }

  # [String[]] image-type: Type of image.
  # Valid values: "machine", "kernel", "ramdisk"
  filter {
    name   = "image-type"
    values = ["machine"]
  }

  # [String[]] Root Device Type: Type of root device.
  # Valid values: "ebs", "instance-store"
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  # [String[]] Architecture: OS architecture of the AMI.
  # Valid values: "x86_64", "arm64", "arm64_mac", "x86_64_mac", "i386"
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  # [String[]] Status: Current state of the AMI. If the state is 'available', the image is
  #     successfully registered and can be used to launch an instance.
  # Valid values: "available", "pending", "failed"
  filter {
    name   = "state"
    values = ["available"]
  }
}

#endregion --- [ Amazon Machine Image(s): Self-Built AMIs ] -------------------------------- #

#region ------ [ Amazon Machine Image(s): Windows Server 2022 Base ] ------------------------ #


data "aws_ami" "us_east_1_windows_server_2022_base" {

  count = length([
    for s in var.all_systems : s
    if s.ami == "windows_server_2022_base" &&
    contains(["us_east_1", "us-east-1"], s.region)
  ]) > 0 ? 1 : 0

  # Set the provider in which to deploy the instance.
  provider = aws.us_east_1

  // [Optional(Boolean)] most_recent: If more than one result is returned, use the most recent.
  most_recent = true

  # [Optional(String[])] List of AMI owners to limit search.
  # Valid values: <AWS account ID>, 'self', <AWS owner alias>
  owners = var.windows_ami_owners

  # [Optional(String)] Name Regex:
  name_regex = "^Windows_Server-2022-English-Full-Base-[\\d.]+$"

  // ===================================================================================== //
  // === Filter(s): One or more name/value pairs to filter off of.                     === //
  // ------------------------------------------------------------------------------------- //
  // All filters are optional, most filters are lists, and all of them are combined to     //
  // allow robust targeting.                                                               //
  // ===================================================================================== //

  # [String[]] image-type: Type of image.
  # Valid values: "machine", "kernel", "ramdisk"
  filter {
    name   = "image-type"
    values = ["machine"]
  }

  # [String[]] Root Device Type: Type of root device.
  # Valid values: "ebs", "instance-store"
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  # [String[]] Architecture: OS architecture of the AMI.
  # Valid values: "x86_64", "arm64", "arm64_mac", "x86_64_mac", "i386"
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  # [String[]] Root Device Name: Device name of the root device.
  filter {
    name   = "root-device-name"
    values = ["/dev/sda1"]
  }

  # [String[]] Status: Current state of the AMI. If the state is 'available', the image is
  #     successfully registered and can be used to launch an instance.
  # Valid values: "available", "pending", "failed"
  filter {
    name   = "state"
    values = ["available"]
  }

  # [String[]] Description: Description of the AMI that was provided during image creation.
  # filter {
  #   name   = "description"
  #   values = ["Provided by Red Hat, Inc."]
  # }
}

#endregion --- [ Amazon Machine Image(s): Windows Server 2022 Base ] ------------------------ #

#region ------ [ Amazon Machine Image(s): Windows Server 2025 Base ] ------------------------ #


data "aws_ami" "us_east_1_windows_server_2025_base" {

  count = length([
    for s in var.all_systems : s
    if s.ami == "windows_server_2025_base" &&
    contains(["us_east_1", "us-east-1"], s.region)
  ]) > 0 ? 1 : 0

  # Set the provider in which to deploy the instance.
  provider = aws.us_east_1

  // [Optional(Boolean)] most_recent: If more than one result is returned, use the most recent.
  most_recent = true

  # [Optional(String[])] List of AMI owners to limit search.
  # Valid values: <AWS account ID>, 'self', <AWS owner alias>
  owners = var.windows_ami_owners

  # [Optional(String)] Name Regex:
  name_regex = "^Windows_Server-2025-English-Full-Base-[\\d.]+$"

  // ===================================================================================== //
  // === Filter(s): One or more name/value pairs to filter off of.                     === //
  // ------------------------------------------------------------------------------------- //
  // All filters are optional, most filters are lists, and all of them are combined to     //
  // allow robust targeting.                                                               //
  // ===================================================================================== //

  # [String[]] image-type: Type of image.
  # Valid values: "machine", "kernel", "ramdisk"
  filter {
    name   = "image-type"
    values = ["machine"]
  }

  # [String[]] Root Device Type: Type of root device.
  # Valid values: "ebs", "instance-store"
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  # [String[]] Architecture: OS architecture of the AMI.
  # Valid values: "x86_64", "arm64", "arm64_mac", "x86_64_mac", "i386"
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  # [String[]] Root Device Name: Device name of the root device.
  filter {
    name   = "root-device-name"
    values = ["/dev/sda1"]
  }

  # [String[]] Status: Current state of the AMI. If the state is 'available', the image is
  #     successfully registered and can be used to launch an instance.
  # Valid values: "available", "pending", "failed"
  filter {
    name   = "state"
    values = ["available"]
  }

  # [String[]] Description: Description of the AMI that was provided during image creation.
  # filter {
  #   name   = "description"
  #   values = ["Provided by Red Hat, Inc."]
  # }
}

#endregion --- [ Amazon Machine Image(s): Windows Server 2025 Base ] ------------------------ #

#region ------ [ Amazon Machine Image(s): Direct AMI IDs ] ---------------------------------- #


data "aws_ami" "us_east_1_direct" {

  for_each = toset([
    for s in var.all_systems : s.ami
    if can(regex("^ami-[0-9a-f]{8,17}$", s.ami)) && contains(["us_east_1", "us-east-1"], s.region)
  ])

  # Set the provider in which to deploy the instance.
  provider = aws.us_east_1

  filter {
    name   = "image-id"
    values = [each.value]
  }

}

#endregion --- [ Amazon Machine Image(s): Direct AMI IDs ] ---------------------------------- #

#endregion --- [ Amazon Machine Image(s) ] ---------------------------------------------------- #


#region ------ [ Load all of the AWS KMS Keys Using Their Alias Name ] ------------------------ #


data "aws_kms_alias" "us_east_1" {

  # Set the provider in which to deploy the instance.
  provider = aws.us_east_1

  # Iterate through all KMS aliases in the target region.
  for_each = toset(
    distinct(concat([
      for system in var.all_systems : system.aws_kms_alias
      if contains(["us_east_1", "us-east-1"], system.region)
      ], nonsensitive([
        for database in var.all_databases : database.aws_kms_alias
        if contains(["us_east_1", "us-east-1"], database.region)
    ])))
  )

  name = "alias/${each.value}"

}

#endregion --- [ Load all of the AWS KMS Keys Using Their Alias Name ] ------------------------ #


#region ------ [ Load All AWS EC2 Key Pairs ] ------------------------------------------------- #


data "aws_key_pair" "us_east_1" {

  # Set the provider in which to deploy the instance.
  provider = aws.us_east_1

  # Iterate through all key pairs in the target region.
  # ?Note: This for_each loop iterates through all system definitions, removes duplicate
  # ?  key_name values, and converts the list to a set so it can be iterated over and
  # ?  queried automatically for use in the AWS resources.
  for_each = toset(
    distinct([
      for system in var.all_systems : system.key_name
      if contains(["us_east_1", "us-east-1"], system.region) && !contains(keys(var.managed_keypairs), system.key_name)
    ])
  )

  key_name = each.value

}

#endregion --- [ Load All AWS EC2 Key Pairs ] ------------------------------------------------- #


#region ------ [ Load Subnets Backing Interface-Owned Security Groups ] ----------------------- #


# An interface-owned group derives its VPC from the parent system's subnet instead of restating it.
# A subnet_id naming a managed_networks entry resolves through local.managed_vpc_ids with no API
# call, so only a LITERAL subnet id reaches this lookup: it has zero instances when no interface
# declares a group. It needs ec2:DescribeSubnets, already covered by the read-only statement in the
# consumer deploy policies.


data "aws_subnet" "us_east_1_inline_security_group" {

  # Set the provider in which to look up the subnet.
  provider = aws.us_east_1

  # Deduplicated by subnet id: several systems with interface-owned groups may share one subnet.
  for_each = toset([
    for system in var.all_systems : system.subnet_id
    if contains(["us_east_1", "us-east-1"], system.region) &&
    anytrue([
      for nic in system.network_interfaces :
      nic.ingress != null && nic.egress != null
    ]) &&
    !contains(keys(var.managed_networks), system.subnet_id)
  ])

  id = each.value

}

#endregion --- [ Load Subnets Backing Interface-Owned Security Groups ] ----------------------- #


#region ------ [ Load All AWS IAM Instance Profiles ] ----------------------------------------- #


data "aws_iam_instance_profile" "us_east_1" {

  # Set the provider in which to deploy the instance.
  provider = aws.us_east_1

  # IAM instance profiles are global; this region split keeps wiring parallel to key_name.
  for_each = toset(
    distinct([
      for s in var.all_systems : s.iam_instance_profile
      if contains(["us_east_1", "us-east-1"], s.region)
    ])
  )

  name = each.value

}

#endregion --- [ Load All AWS IAM Instance Profiles ] ----------------------------------------- #
