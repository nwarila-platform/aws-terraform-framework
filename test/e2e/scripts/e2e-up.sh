#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
E2E_DIR=$(cd -- "${SCRIPT_DIR}/.." && pwd)
ROOT_DIR=$(cd -- "${E2E_DIR}/../.." && pwd)
HARNESS_DIR="${E2E_DIR}/harness"
FRAMEWORK_DIR="${ROOT_DIR}/terraform"
GENERATED_DIR="${E2E_DIR}/.generated"
HARNESS_TFVARS="${GENERATED_DIR}/harness.auto.tfvars"
RENDERED_TFVARS="${GENERATED_DIR}/framework.auto.tfvars"
RUN_ENV="${GENERATED_DIR}/e2e.env"
FIXTURE_ENV="${GENERATED_DIR}/fixture-amis.env"

REGION="${E2E_REGION:-us-east-1}"
NAME_PREFIX="${E2E_NAME_PREFIX:-e2e}"
PROJECT="e2e-${NAME_PREFIX}"
OPERATOR_CIDR="${E2E_OPERATOR_CIDR:-}"
USE_RUNNER="${E2E_USE_RUNNER:-true}"
ENABLE_RDS="${E2E_ENABLE_RDS:-true}"
ENABLE_LB="${E2E_ENABLE_LB:-true}"
ENABLE_NLB="${E2E_ENABLE_NLB:-false}"
MAX_MINUTES="${MAX_MINUTES:-180}"
REMOTE_ROOT="${E2E_REMOTE_ROOT:-/home/ec2-user/e2e/aws-terraform-framework}"
REFRESH_SERIAL="${E2E_REFRESH_SERIAL:-0}"

require() {
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf 'missing required command: %s\n' "$cmd" >&2
      exit 127
    fi
  done
}

bool_tf() {
  case "$1" in
    true | TRUE | 1 | yes | YES) printf 'true' ;;
    false | FALSE | 0 | no | NO) printf 'false' ;;
    *)
      printf 'invalid boolean value: %s\n' "$1" >&2
      exit 2
      ;;
  esac
}

tf_output() {
  local key=$1
  jq -r --arg key "$key" '.[$key].value' "$GENERATED_DIR/harness-outputs.json"
}

tf_output_json() {
  local key=$1
  jq -c --arg key "$key" '.[$key].value' "$GENERATED_DIR/harness-outputs.json"
}

resolve_ami() {
  local owner=$1
  local name_glob=$2
  aws ec2 describe-images \
    --region "$REGION" \
    --owners "$owner" \
    --filters "Name=name,Values=${name_glob}" "Name=architecture,Values=x86_64" "Name=root-device-type,Values=ebs" "Name=state,Values=available" \
    --query 'sort_by(Images,&CreationDate)[-1].ImageId' \
    --output text
}

wait_for_ssh() {
  local public_ip=$1
  local key_path=$2
  local deadline=$((SECONDS + 600))

  while ((SECONDS < deadline)); do
    if ssh -i "$key_path" \
      -o BatchMode=yes \
      -o ConnectTimeout=5 \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile="${GENERATED_DIR}/known_hosts" \
      "ec2-user@${public_ip}" "true" >/dev/null 2>&1; then
      return 0
    fi
    sleep 10
  done

  printf 'runner SSH did not become ready within 10 minutes\n' >&2
  return 1
}

if [[ -z "$OPERATOR_CIDR" ]]; then
  printf 'E2E_OPERATOR_CIDR is required to scope runner SSH access.\n' >&2
  exit 2
fi

require aws envsubst jq ssh scp tar terraform
mkdir -p "$GENERATED_DIR"

printf '%s\n' "$(date +%s)" >"${GENERATED_DIR}/${PROJECT}.started"
printf 'Starting e2e harness %s in %s with MAX_MINUTES=%s\n' "$PROJECT" "$REGION" "$MAX_MINUTES"

AL2023_AMI_ID="${E2E_AL2023_AMI_ID:-$(aws ssm get-parameter \
  --region "$REGION" \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value \
  --output text)}"
UBUNTU_AMI_ID="${E2E_UBUNTU_AMI_ID:-$(resolve_ami 099720109477 'ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*')}"
WINDOWS_2025_AMI_ID="${E2E_WINDOWS_2025_AMI_ID:-$(resolve_ami amazon 'Windows_Server-2025-English-Full-Base-*')}"

E2E_REGION="$REGION" E2E_NAME_PREFIX="$NAME_PREFIX" E2E_AL2023_AMI_ID="$AL2023_AMI_ID" \
  "${SCRIPT_DIR}/mint-fixture-amis.sh"
# shellcheck source=/dev/null
source "$FIXTURE_ENV"

cat >"$HARNESS_TFVARS" <<EOF
region        = "${REGION}"
name_prefix   = "${NAME_PREFIX}"
operator_cidr = "${OPERATOR_CIDR}"
use_runner    = $(bool_tf "$USE_RUNNER")
enable_rds    = $(bool_tf "$ENABLE_RDS")
enable_lb     = $(bool_tf "$ENABLE_LB")
enable_nlb    = $(bool_tf "$ENABLE_NLB")
EOF

terraform -chdir="$HARNESS_DIR" init -backend=false -input=false
terraform -chdir="$HARNESS_DIR" apply -auto-approve -input=false -var-file="$HARNESS_TFVARS"
terraform -chdir="$HARNESS_DIR" output -json >"${GENERATED_DIR}/harness-outputs.json"

KEY_PATH=$(terraform -chdir="$HARNESS_DIR" output -raw key_path)
chmod 0400 "$KEY_PATH"

E2E_PROJECT=$(tf_output project)
E2E_AVAILABILITY_ZONE=$(tf_output availability_zone)
E2E_PRIVATE_SUBNET_ID=$(tf_output private_subnet_id)
E2E_PRIVATE_SUBNET_IDS_HCL=$(tf_output_json private_subnet_ids)
E2E_KEY_NAME=$(tf_output key_name)
E2E_FRAMEWORK_INSTANCE_PROFILE=$(tf_output framework_instance_profile_name)
E2E_KMS_ALIAS_NAME=$(tf_output kms_alias_name)
E2E_FRAMEWORK_SECURITY_GROUP_ID=$(tf_output framework_security_group_id)
E2E_LOAD_BALANCER_SECURITY_GROUP_ID=$(tf_output load_balancer_security_group_id)
E2E_RDS_SECURITY_GROUP_ID=$(tf_output rds_security_group_id)
E2E_DB_SUBNET_GROUP_NAME=$(tf_output db_subnet_group_name)
E2E_VPC_ID=$(tf_output vpc_id)
HARNESS_USE_RUNNER=$(tf_output use_runner)
RUNNER_PUBLIC_IP=$(tf_output runner_public_ip)

if [[ "$HARNESS_USE_RUNNER" == "true" ]]; then
  E2E_READINESS_KEY_PATH="${REMOTE_ROOT}/test/e2e/.generated/${E2E_PROJECT}.pem"
else
  E2E_READINESS_KEY_PATH="$KEY_PATH"
fi

if [[ "$(tf_output enable_rds)" == "true" ]]; then
  E2E_ALL_DATABASES=$(cat <<EOF
[
  {
    region                      = "us_east_1"
    availability_zone           = "${E2E_AVAILABILITY_ZONE}"
    db_name                     = "e2edb"
    db_subnet_group_name        = "${E2E_DB_SUBNET_GROUP_NAME}"
    engine                      = "postgres"
    engine_version              = "16.3"
    instance_class              = "db.t3.micro"
    username                    = "e2eadmin"
    aws_kms_alias               = "${E2E_KMS_ALIAS_NAME}"
    allocated_storage           = "20"
    deletion_protection         = false
    skip_final_snapshot         = true
    manage_master_user_password = true
    vpc_security_group_ids      = ["${E2E_RDS_SECURITY_GROUP_ID}"]

    tags = {
      Function = "e2e-db"
      Project  = "${E2E_PROJECT}"
    }
  }
]
EOF
)
else
  E2E_ALL_DATABASES="[]"
fi

if [[ "$(tf_output enable_lb)" == "true" ]]; then
  E2E_ALL_LOAD_BALANCERS=$(cat <<EOF
[
  {
    region             = "us_east_1"
    resource_key       = "e2e_alb"
    name               = "${E2E_PROJECT}-alb"
    internal           = true
    load_balancer_type = "application"
    security_groups    = ["${E2E_LOAD_BALANCER_SECURITY_GROUP_ID}"]
    subnets            = ${E2E_PRIVATE_SUBNET_IDS_HCL}

    target_groups = [
      {
        resource_key = "lin_raw"
        function     = "e2e-lin-raw"
        vpc_id       = "${E2E_VPC_ID}"
        port         = 80
        protocol     = "HTTP"

        health_check = {
          enabled = true
          matcher = "200-499"
          path    = "/"
        }

        tags = {
          Project = "${E2E_PROJECT}"
        }
      }
    ]

    listeners = [
      {
        resource_key = "http"
        port         = 80
        protocol     = "HTTP"

        default_action = {
          type             = "forward"
          target_group_key = "lin_raw"
        }
      }
    ]

    tags = {
      Function = "e2e-alb"
      Project  = "${E2E_PROJECT}"
    }
  }
]
EOF
)
else
  E2E_ALL_LOAD_BALANCERS="[]"
fi

export E2E_PROJECT
export E2E_REFRESH_SERIAL="$REFRESH_SERIAL"
export E2E_AVAILABILITY_ZONE E2E_PRIVATE_SUBNET_ID E2E_KEY_NAME
export E2E_FRAMEWORK_INSTANCE_PROFILE E2E_KMS_ALIAS_NAME
export E2E_FRAMEWORK_SECURITY_GROUP_ID E2E_LOAD_BALANCER_SECURITY_GROUP_ID
export E2E_RDS_SECURITY_GROUP_ID E2E_DB_SUBNET_GROUP_NAME E2E_VPC_ID
export E2E_READINESS_KEY_PATH E2E_AL2023_AMI_ID E2E_UBUNTU_AMI_ID
export E2E_WINDOWS_2025_AMI_ID E2E_ALL_DATABASES E2E_ALL_LOAD_BALANCERS

envsubst <"${E2E_DIR}/framework.auto.tfvars.tftpl" >"$RENDERED_TFVARS"

{
  printf 'export E2E_REGION=%q\n' "$REGION"
  printf 'export E2E_NAME_PREFIX=%q\n' "$NAME_PREFIX"
  printf 'export E2E_PROJECT=%q\n' "$E2E_PROJECT"
  printf 'export E2E_REMOTE_ROOT=%q\n' "$REMOTE_ROOT"
  printf 'export E2E_KEY_NAME=%q\n' "$E2E_KEY_NAME"
  printf 'export E2E_KEY_PATH=%q\n' "$KEY_PATH"
  printf 'export E2E_READINESS_KEY_PATH=%q\n' "$E2E_READINESS_KEY_PATH"
  printf 'export E2E_AL2023_AMI_ID=%q\n' "$E2E_AL2023_AMI_ID"
  printf 'export E2E_UBUNTU_AMI_ID=%q\n' "$E2E_UBUNTU_AMI_ID"
  printf 'export E2E_WINDOWS_2025_AMI_ID=%q\n' "$E2E_WINDOWS_2025_AMI_ID"
  printf 'export E2E_DB_NAME=%q\n' "e2edb"
  printf 'export E2E_EXPECT_RDS=%q\n' "$(tf_output enable_rds)"
  printf 'export E2E_EXPECT_LB=%q\n' "$(tf_output enable_lb)"
  printf 'export E2E_USE_RUNNER=%q\n' "$HARNESS_USE_RUNNER"
} >"$RUN_ENV"
cat "$FIXTURE_ENV" >>"$RUN_ENV"

if [[ "$HARNESS_USE_RUNNER" == "true" ]]; then
  if [[ "$RUNNER_PUBLIC_IP" == "null" || -z "$RUNNER_PUBLIC_IP" ]]; then
    printf 'use_runner=true but runner_public_ip is empty\n' >&2
    exit 1
  fi

  wait_for_ssh "$RUNNER_PUBLIC_IP" "$KEY_PATH"

  tar \
    --exclude .git \
    --exclude .terraform \
    --exclude '.tmp' \
    --exclude 'test/e2e/.generated' \
    --exclude '*.tfstate' \
    --exclude '*.tfstate.*' \
    -C "$ROOT_DIR" \
    -czf - . | ssh -i "$KEY_PATH" \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile="${GENERATED_DIR}/known_hosts" \
      "ec2-user@${RUNNER_PUBLIC_IP}" \
      "rm -rf '${REMOTE_ROOT}' && mkdir -p '${REMOTE_ROOT}' && tar -xzf - -C '${REMOTE_ROOT}'"

  ssh -i "$KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile="${GENERATED_DIR}/known_hosts" \
    "ec2-user@${RUNNER_PUBLIC_IP}" \
    "mkdir -p '${REMOTE_ROOT}/test/e2e/.generated'"

  scp -i "$KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile="${GENERATED_DIR}/known_hosts" \
    "$KEY_PATH" "$RUN_ENV" "$FIXTURE_ENV" "${GENERATED_DIR}/harness-outputs.json" \
    "ec2-user@${RUNNER_PUBLIC_IP}:${REMOTE_ROOT}/test/e2e/.generated/"

  scp -i "$KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile="${GENERATED_DIR}/known_hosts" \
    "$RENDERED_TFVARS" \
    "ec2-user@${RUNNER_PUBLIC_IP}:${REMOTE_ROOT}/terraform/framework.auto.tfvars"

  ssh -i "$KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile="${GENERATED_DIR}/known_hosts" \
    "ec2-user@${RUNNER_PUBLIC_IP}" \
    "chmod 0400 '${REMOTE_ROOT}/test/e2e/.generated/${E2E_PROJECT}.pem'"

  ssh -i "$KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile="${GENERATED_DIR}/known_hosts" \
    "ec2-user@${RUNNER_PUBLIC_IP}" \
    "bash -lc 'set -euo pipefail; cd ${REMOTE_ROOT}/terraform; terraform init -backend=false -input=false; terraform apply -auto-approve -input=false 2>&1 | tee ${REMOTE_ROOT}/test/e2e/.generated/framework-apply.log'" \
    | tee "${GENERATED_DIR}/framework-apply.log"
else
  cp "$RENDERED_TFVARS" "${FRAMEWORK_DIR}/framework.auto.tfvars"
  terraform -chdir="$FRAMEWORK_DIR" init -backend=false -input=false
  terraform -chdir="$FRAMEWORK_DIR" apply -auto-approve -input=false 2>&1 | tee "${GENERATED_DIR}/framework-apply.log"
fi

printf 'E2E apply completed. Run make e2e-verify before teardown.\n'
