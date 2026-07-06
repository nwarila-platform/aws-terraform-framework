#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
E2E_DIR=$(cd -- "${SCRIPT_DIR}/.." && pwd)
GENERATED_DIR="${E2E_DIR}/.generated"

REGION="${E2E_REGION:-us-east-1}"
NAME_PREFIX="${E2E_NAME_PREFIX:-e2e}"
PROJECT="e2e-${NAME_PREFIX}"
STAMP="${E2E_FIXTURE_STAMP:-$(date -u +%Y%m%d%H%M%S)}"
FIXTURE_ENV="${GENERATED_DIR}/fixture-amis.env"

require() {
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf 'missing required command: %s\n' "$cmd" >&2
      exit 127
    fi
  done
}

copy_fixture() {
  local name=$1
  local image_id

  image_id=$(aws ec2 copy-image \
    --region "$REGION" \
    --source-region "$REGION" \
    --source-image-id "$BASE_AMI_ID" \
    --name "$name" \
    --description "E2E fixture copied from AL2023 for ${PROJECT}" \
    --tag-specifications "ResourceType=image,Tags=[{Key=Project,Value=${PROJECT}},{Key=Name,Value=${name}}]" "ResourceType=snapshot,Tags=[{Key=Project,Value=${PROJECT}},{Key=Name,Value=${name}}]" \
    --query ImageId \
    --output text)

  printf 'Waiting for %s (%s) to become available...\n' "$name" "$image_id" >&2
  aws ec2 wait image-available --region "$REGION" --image-ids "$image_id"
  printf '%s\n' "$image_id"
}

require aws
mkdir -p "$GENERATED_DIR"

BASE_AMI_ID="${E2E_AL2023_AMI_ID:-$(aws ssm get-parameter \
  --region "$REGION" \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value \
  --output text)}"

APP_LINUX_V1_NAME="app-linux_v1_${STAMP}"
APP_LINUX_V2_NAME="app-linux_v2_${STAMP}"
APP_LINUX_EXTRA_V1_NAME="app-linux-extra_v1_${STAMP}"

APP_LINUX_V1_AMI=$(copy_fixture "$APP_LINUX_V1_NAME")
APP_LINUX_V2_AMI=$(copy_fixture "$APP_LINUX_V2_NAME")
APP_LINUX_EXTRA_V1_AMI=$(copy_fixture "$APP_LINUX_EXTRA_V1_NAME")

{
  printf 'export E2E_FIXTURE_STAMP=%q\n' "$STAMP"
  printf 'export E2E_FIXTURE_APP_LINUX_V1_NAME=%q\n' "$APP_LINUX_V1_NAME"
  printf 'export E2E_FIXTURE_APP_LINUX_V2_NAME=%q\n' "$APP_LINUX_V2_NAME"
  printf 'export E2E_FIXTURE_APP_LINUX_EXTRA_V1_NAME=%q\n' "$APP_LINUX_EXTRA_V1_NAME"
  printf 'export E2E_FIXTURE_APP_LINUX_V1_AMI=%q\n' "$APP_LINUX_V1_AMI"
  printf 'export E2E_FIXTURE_APP_LINUX_V2_AMI=%q\n' "$APP_LINUX_V2_AMI"
  printf 'export E2E_FIXTURE_APP_LINUX_EXTRA_V1_AMI=%q\n' "$APP_LINUX_EXTRA_V1_AMI"
} >"$FIXTURE_ENV"

printf 'Minted fixture AMIs for %s in %s:\n' "$PROJECT" "$REGION"
printf '  %s=%s\n' "$APP_LINUX_V1_NAME" "$APP_LINUX_V1_AMI"
printf '  %s=%s\n' "$APP_LINUX_V2_NAME" "$APP_LINUX_V2_AMI"
printf '  %s=%s\n' "$APP_LINUX_EXTRA_V1_NAME" "$APP_LINUX_EXTRA_V1_AMI"
printf 'Wrote %s\n' "$FIXTURE_ENV"
