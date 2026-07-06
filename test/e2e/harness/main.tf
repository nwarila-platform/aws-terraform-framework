terraform {
  required_version = "= 1.15.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.47.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "= 2.9.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "= 4.3.0"
    }
  }
}

provider "aws" {
  region = local.region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  region            = replace(var.region, "_", "-")
  project           = "e2e-${var.name_prefix}"
  terraform_version = "1.15.1"
  opa_version       = "1.4.2"

  vpc_cidr            = "10.42.0.0/16"
  public_subnet_cidr  = "10.42.0.0/24"
  private_subnet_cidr = ["10.42.10.0/24", "10.42.11.0/24"]

  common_tags = {
    Project     = local.project
    Environment = local.project
    ManagedBy   = "Terraform"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_vpc" "this" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = local.project
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.project}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.project}-runner-public"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  count = 2

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.private_subnet_cidr[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.project}-framework-private-${count.index + 1}"
    Tier = "private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${local.project}-public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.project}-private"
  }
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "runner" {
  name        = "${local.project}-runner"
  description = "E2E runner SSH access from the operator CIDR."
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Operator SSH to runner"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.operator_cidr]
  }

  egress {
    description = "Runner outbound for package install, Terraform, and AWS APIs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.project}-runner"
  }
}

resource "aws_security_group" "framework" {
  name        = "${local.project}-framework"
  description = "Private framework instances reached only from the e2e runner."
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Runner SSH readiness"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.runner.id]
  }

  ingress {
    description     = "Runner WinRM readiness"
    from_port       = 5986
    to_port         = 5986
    protocol        = "tcp"
    security_groups = [aws_security_group.runner.id]
  }

  egress {
    description = "Private VPC egress only"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [local.vpc_cidr]
  }

  tags = {
    Name = "${local.project}-framework"
  }
}

resource "aws_security_group" "load_balancer" {
  name        = "${local.project}-alb"
  description = "Internal ALB access from the e2e runner."
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Runner HTTP to internal ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.runner.id]
  }

  egress {
    description     = "ALB to framework targets"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.framework.id]
  }

  tags = {
    Name = "${local.project}-alb"
  }
}

resource "aws_security_group" "rds" {
  name        = "${local.project}-rds"
  description = "Private RDS access from framework instances and the e2e runner."
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Postgres from framework instances"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.framework.id]
  }

  ingress {
    description     = "Postgres checks from runner"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.runner.id]
  }

  egress {
    description = "Private VPC egress only"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [local.vpc_cidr]
  }

  tags = {
    Name = "${local.project}-rds"
  }
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "private_key" {
  filename        = "${path.module}/../.generated/${local.project}.pem"
  content         = tls_private_key.this.private_key_openssh
  file_permission = "0400"
}

resource "aws_key_pair" "this" {
  key_name   = local.project
  public_key = tls_private_key.this.public_key_openssh

  tags = {
    Name = local.project
  }
}

resource "aws_iam_role" "framework" {
  name = "${local.project}-framework"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${local.project}-framework"
  }
}

resource "aws_iam_instance_profile" "framework" {
  name = "${local.project}-framework"
  role = aws_iam_role.framework.name

  tags = {
    Name = "${local.project}-framework"
  }
}

resource "aws_iam_role" "runner" {
  count = var.use_runner ? 1 : 0

  name = "${local.project}-runner"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${local.project}-runner"
  }
}

resource "aws_iam_role_policy" "runner" {
  count = var.use_runner ? 1 : 0

  name = "${local.project}-framework-apply"
  role = aws_iam_role.runner[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DescribeForTerraformAndVerify"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "elasticloadbalancing:Describe*",
          "iam:GetInstanceProfile",
          "kms:DescribeKey",
          "kms:ListAliases",
          "kms:ListResourceTags",
          "rds:Describe*",
          "rds:ListTagsForResource",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = "*"
      },
      {
        Sid    = "ManageFrameworkEc2"
        Effect = "Allow"
        Action = [
          "ec2:AttachVolume",
          "ec2:CreateNetworkInterface",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:DeleteNetworkInterface",
          "ec2:DeleteTags",
          "ec2:DeleteVolume",
          "ec2:DetachVolume",
          "ec2:GetPasswordData",
          "ec2:ModifyInstanceAttribute",
          "ec2:RunInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:TerminateInstances"
        ]
        Resource = "*"
      },
      {
        Sid    = "ManageFrameworkLoadBalancers"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteRule",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:RemoveTags",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets"
        ]
        Resource = "*"
      },
      {
        Sid    = "ManageFrameworkRds"
        Effect = "Allow"
        Action = [
          "rds:AddTagsToResource",
          "rds:CreateDBInstance",
          "rds:DeleteDBInstance",
          "rds:ModifyDBInstance",
          "rds:RemoveTagsFromResource"
        ]
        Resource = "*"
      },
      {
        # RDS invokes these AS the runner (forward-access session) at DB-create
        # time when manage_master_user_password=true. Verified via CloudTrail in
        # the RBAC LP test: CreateSecret/TagResource run under the caller, while
        # value ops + DeleteSecret run under AWSServiceRoleForRDS.
        Sid    = "RdsManagedPasswordSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:TagResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "UseHarnessKmsKey"
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = aws_kms_key.this.arn
      },
      {
        Sid      = "PassFrameworkProfileRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.framework.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "runner" {
  count = var.use_runner ? 1 : 0

  name = "${local.project}-runner"
  role = aws_iam_role.runner[0].name

  tags = {
    Name = "${local.project}-runner"
  }
}

resource "aws_kms_key" "this" {
  description             = "Throwaway e2e encryption key for ${local.project}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = local.project
  }
}

resource "aws_kms_alias" "this" {
  name          = "alias/${local.project}"
  target_key_id = aws_kms_key.this.key_id
}

resource "aws_db_subnet_group" "this" {
  name       = local.project
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = local.project
  }
}

resource "aws_instance" "runner" {
  count = var.use_runner ? 1 : 0

  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.runner.id]
  key_name                    = aws_key_pair.this.key_name
  iam_instance_profile        = aws_iam_instance_profile.runner[0].name
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted             = true
    kms_key_id            = aws_kms_key.this.arn
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true

    tags = {
      Name = "${local.project}-runner-root"
    }
  }

  user_data = <<-USER_DATA
    #!/bin/bash
    set -euxo pipefail

    dnf install -y awscli-2 gettext git gzip jq nmap-ncat openssh-clients tar unzip || \
      dnf install -y awscli gettext git gzip jq nmap-ncat openssh-clients tar unzip

    terraform_version="${local.terraform_version}"
    curl -fsSLo /tmp/terraform.zip "https://releases.hashicorp.com/terraform/$${terraform_version}/terraform_$${terraform_version}_linux_amd64.zip"
    unzip -o /tmp/terraform.zip -d /usr/local/bin
    chmod 0755 /usr/local/bin/terraform

    opa_version="${local.opa_version}"
    curl -fsSLo /usr/local/bin/opa "https://openpolicyagent.org/downloads/v$${opa_version}/opa_linux_amd64_static"
    chmod 0755 /usr/local/bin/opa

    mkdir -p /home/ec2-user/e2e
    chown -R ec2-user:ec2-user /home/ec2-user/e2e
  USER_DATA

  tags = {
    Name = "${local.project}-runner"
    Role = "e2e-runner"
  }

  depends_on = [
    aws_internet_gateway.this,
    local_sensitive_file.private_key,
  ]
}
