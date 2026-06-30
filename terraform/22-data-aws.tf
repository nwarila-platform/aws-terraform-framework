#% =========================================================================================== %#
#% = File: 22-data-aws.tf                                        | Category: variables (20-29) %#
#% ------------------------------------------------------------------------------------------- %#
#% =========================================================================================== %#


#region ------ [ Amazon Machine Image(s) ] ---------------------------------------------------- #

#?region ------ [ Notes ] -------------------------------------------------------------------- ?#
#? 1. Because aws_ami needs to, target each region independently and uniquely indicate the     ?#
#?    target AMI I've opted to built a lookup variable 'local.amazon_machine_images' that must ?#
#?    must be updated manually to list all supported operating systems. As we build custom     ?#
#?    packer-built AMIs, this will largely become irrelevant as we can use input variables     ?#
#?    to update this data source to automatically pull release specific custom AMI.            ?#
#?endregion --- [ Notes ] -------------------------------------------------------------------- ?#

#region ------ [ Amazon Machine Image(s): Red Hat Enterprise Linux 8 ] ---------------------- #

data "aws_ami" "us_west_2_red_hat_enterprise_linux_8" {

  count = length([
    for s in var.all_systems : s
    if s.ami == "red_hat_enterprise_linux_8" &&
    contains(["us_west_2", "us-west-2"], s.region)
  ]) > 0 ? 1 : 0

  # Set the provider in which to deploy the instance.
  provider = aws.us_west_2

  // [Optional(Boolean)] most_recent: If more than one result is returned, use the most recent.
  most_recent = true

  # [Optional(String[])] List of AMI owners to limit search.
  # Valid values: <AWS account ID>, 'self', <AWS owner alias>
  # Red Hat's public AMI publisher account.
  owners = ["279693163583"]

  # [Optional(String)] Name Regex:
  name_regex = "^RHEL-8\\.[\\d.]+_[^-]+-\\d{6,8}-x86_64-([^-]+-){2}GP3(-[^-]+){2}$"

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
  filter {
    name   = "description"
    values = ["Provided by Red Hat, Inc."]
  }
}

data "aws_ami" "us_east_1_red_hat_enterprise_linux_8" {

  count = length([
    for s in var.all_systems : s
    if s.ami == "red_hat_enterprise_linux_8" &&
    contains(["us_east_1", "us-east-1"], s.region)
  ]) > 0 ? 1 : 0

  # Set the provider in which to deploy the instance.
  provider = aws.us_east_1

  // [Optional(Boolean)] most_recent: If more than one result is returned, use the most recent.
  most_recent = true

  # [Optional(String[])] List of AMI owners to limit search.
  # Valid values: <AWS account ID>, 'self', <AWS owner alias>
  # Red Hat's public AMI publisher account.
  owners = ["279693163583"]

  # [Optional(String)] Name Regex:
  name_regex = "^RHEL-8\\.[\\d.]+_[^-]+-\\d{6,8}-x86_64-([^-]+-){2}GP3(-[^-]+){2}$"

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
  filter {
    name   = "description"
    values = ["Provided by Red Hat, Inc."]
  }
}

#endregion --- [ Amazon Machine Image(s): Red Hat Enterprise Linux 8 ] ---------------------- #

#region ------ [ Amazon Machine Image(s): Windows Server 2022 Base ] ------------------------ #

data "aws_ami" "us_west_2_windows_server_2022_base" {

  count = length([
    for s in var.all_systems : s
    if s.ami == "windows_server_2022_base" &&
    contains(["us_west_2", "us-west-2"], s.region)
  ]) > 0 ? 1 : 0

  # Set the provider in which to deploy the instance.
  provider = aws.us_west_2

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

data "aws_ami" "us_west_2_windows_server_2025_base" {

  count = length([
    for s in var.all_systems : s
    if s.ami == "windows_server_2025_base" &&
    contains(["us_west_2", "us-west-2"], s.region)
  ]) > 0 ? 1 : 0

  # Set the provider in which to deploy the instance.
  provider = aws.us_west_2

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

#endregion --- [ Amazon Machine Image(s) ] ---------------------------------------------------- #


#region ------ [ Load all of the AWS KMS Keys Using Their Alias Name ] ------------------------ #

data "aws_kms_alias" "us_west_2" {

  # Set the provider in which to deploy the instance.
  provider = aws.us_west_2

  # Iterate through all KMS aliases in the target region.
  # ?Note: This for_each loop iterates through all system and database definitions,
  # ?  removes duplicate aws_kms_alias values, and converts the list of aliases to a set
  # ?  so it can be iterated over and queried automatically for use in the AWS resources.
  for_each = toset(
    distinct(concat([
      for system in var.all_systems : system.aws_kms_alias
      if contains(["us_west_2", "us-west-2"], system.region)
      ], nonsensitive([
        for database in var.all_databases : database.aws_kms_alias
        if contains(["us_west_2", "us-west-2"], database.region)
    ])))
  )

  name = "alias/${each.value}"

}


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

data "aws_key_pair" "us_west_2" {

  # Set the provider in which to deploy the instance.
  provider = aws.us_west_2

  # Iterate through all key pairs in the target region.
  # ?Note: This for_each loop iterates through all system definitions, removes duplicate
  # ?  key_name values, and converts the list to a set so it can be iterated over and
  # ?  queried automatically for use in the AWS resources.
  for_each = toset(
    distinct([
      for system in var.all_systems : system.key_name
      if contains(["us_west_2", "us-west-2"], system.region)
    ])
  )

  key_name = each.value

}


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
      if contains(["us_east_1", "us-east-1"], system.region)
    ])
  )

  key_name = each.value

}

#endregion --- [ Load All AWS EC2 Key Pairs ] ------------------------------------------------- #


#region ------ [ Load All AWS IAM Instance Profiles ] ----------------------------------------- #

data "aws_iam_instance_profile" "us_west_2" {

  # Set the provider in which to deploy the instance.
  provider = aws.us_west_2

  # IAM instance profiles are global; this region split keeps wiring parallel to key_name.
  for_each = toset(
    distinct([
      for s in var.all_systems : s.iam_instance_profile
      if contains(["us_west_2", "us-west-2"], s.region)
    ])
  )

  name = each.value

}


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
