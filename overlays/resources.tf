# Ephemeral public networking. Every collection is driven by local.ephemeral_networks; an empty
# input is the explicit zero-resource path.

resource "aws_vpc" "us_east_1" {
  provider = aws.us_east_1
  for_each = local.ephemeral_networks

  cidr_block           = each.value["vpc_cidr"]
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = each.value["tags"]
}

resource "aws_internet_gateway" "us_east_1" {
  provider = aws.us_east_1
  for_each = local.ephemeral_networks

  vpc_id = aws_vpc.us_east_1[each.key].id
  tags   = each.value["tags"]
}

resource "aws_subnet" "us_east_1" {
  provider = aws.us_east_1
  for_each = local.ephemeral_networks

  vpc_id            = aws_vpc.us_east_1[each.key].id
  cidr_block        = each.value["subnet_cidr"]
  availability_zone = each.value["availability_zone"]

  # Kept false so AWS does not automatically assign a public IPv4 address to instances launched in
  # this managed subnet. If enabled, subnet auto-assignment also applies when an instance launches
  # with this framework's pre-created primary ENI.
  map_public_ip_on_launch = false

  tags = each.value["tags"]
}

resource "aws_route_table" "us_east_1" {
  provider = aws.us_east_1
  for_each = local.ephemeral_networks

  vpc_id = aws_vpc.us_east_1[each.key].id
  tags   = each.value["tags"]
}

resource "aws_route" "us_east_1_default" {
  provider = aws.us_east_1
  for_each = aws_route_table.us_east_1

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.us_east_1[each.key].id
}

resource "aws_route_table_association" "us_east_1" {
  provider = aws.us_east_1
  for_each = aws_route_table.us_east_1

  subnet_id      = aws_subnet.us_east_1[each.key].id
  route_table_id = each.value.id
}
