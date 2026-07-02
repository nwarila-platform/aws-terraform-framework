#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
E2E_DIR=$(cd -- "${SCRIPT_DIR}/.." && pwd)
ROOT_DIR=$(cd -- "${E2E_DIR}/../.." && pwd)
HARNESS_DIR="${E2E_DIR}/harness"
FRAMEWORK_DIR="${ROOT_DIR}/terraform"
GENERATED_DIR="${E2E_DIR}/.generated"
HARNESS_TFVARS="${GENERATED_DIR}/harness.auto.tfvars"
RUN_ENV="${GENERATED_DIR}/e2e.env"

REGION="${E2E_REGION:-us-east-1}"
NAME_PREFIX="${E2E_NAME_PREFIX:-e2e}"
PROJECT="e2e-${NAME_PREFIX}"
REMOTE_ROOT="${E2E_REMOTE_ROOT:-/home/ec2-user/e2e/aws-terraform-framework}"

require() {
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf 'missing required command: %s\n' "$cmd" >&2
      exit 127
    fi
  done
}

tf_output_or_null() {
  local key=$1
  if terraform -chdir="$HARNESS_DIR" output -json >/tmp/e2e-harness-output.json 2>/dev/null; then
    jq -r --arg key "$key" '.[$key].value // "null"' /tmp/e2e-harness-output.json
  else
    printf 'null\n'
  fi
}

deregister_fixture_amis() {
  local images_json image_id snapshots snapshot_id

  images_json=$(aws ec2 describe-images \
    --region "$REGION" \
    --owners self \
    --filters "Name=tag:Project,Values=${PROJECT}" \
    --output json)

  while IFS= read -r image_id; do
    [[ -z "$image_id" ]] && continue
    snapshots=$(jq -r --arg image_id "$image_id" '.Images[] | select(.ImageId == $image_id) | .BlockDeviceMappings[]?.Ebs.SnapshotId // empty' <<<"$images_json")
    printf 'Deregistering fixture AMI %s\n' "$image_id"
    aws ec2 deregister-image --region "$REGION" --image-id "$image_id" || true

    while IFS= read -r snapshot_id; do
      [[ -z "$snapshot_id" ]] && continue
      printf 'Deleting fixture snapshot %s\n' "$snapshot_id"
      aws ec2 delete-snapshot --region "$REGION" --snapshot-id "$snapshot_id" || true
    done <<<"$snapshots"
  done < <(jq -r '.Images[] | select(.Name | test("^app-linux(_v[0-9]|-extra_v[0-9])_")) | .ImageId' <<<"$images_json")

  while IFS= read -r snapshot_id; do
    [[ -z "$snapshot_id" ]] && continue
    printf 'Deleting tagged e2e snapshot residue %s\n' "$snapshot_id"
    aws ec2 delete-snapshot --region "$REGION" --snapshot-id "$snapshot_id" || true
  done < <(aws ec2 describe-snapshots \
    --region "$REGION" \
    --owner-ids self \
    --filters "Name=tag:Project,Values=${PROJECT}" \
    --query 'Snapshots[].SnapshotId' \
    --output text | tr '\t' '\n')
}

require aws jq ssh terraform

if [[ -f "$RUN_ENV" ]]; then
  # shellcheck source=/dev/null
  source "$RUN_ENV"
  REGION="${E2E_REGION:-$REGION}"
  NAME_PREFIX="${E2E_NAME_PREFIX:-$NAME_PREFIX}"
  PROJECT="${E2E_PROJECT:-e2e-${NAME_PREFIX}}"
  REMOTE_ROOT="${E2E_REMOTE_ROOT:-$REMOTE_ROOT}"
fi

HARNESS_USE_RUNNER=$(tf_output_or_null use_runner)
RUNNER_PUBLIC_IP=$(tf_output_or_null runner_public_ip)
KEY_PATH=$(tf_output_or_null key_path)

if [[ "$HARNESS_USE_RUNNER" == "true" && "$RUNNER_PUBLIC_IP" != "null" && -n "$RUNNER_PUBLIC_IP" && -f "$KEY_PATH" ]]; then
  printf 'Destroying framework from runner %s before harness teardown...\n' "$RUNNER_PUBLIC_IP"
  ssh -i "$KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile="${GENERATED_DIR}/known_hosts" \
    "ec2-user@${RUNNER_PUBLIC_IP}" \
    "bash -lc 'set -euo pipefail; cd ${REMOTE_ROOT}/terraform; terraform destroy -auto-approve -input=false 2>&1 | tee ${REMOTE_ROOT}/test/e2e/.generated/framework-destroy.log'" \
    | tee "${GENERATED_DIR}/framework-destroy.log" || true
else
  printf 'Destroying framework locally (runner unavailable or use_runner=false)...\n'
  if [[ -f "${FRAMEWORK_DIR}/framework.auto.tfvars" ]]; then
    terraform -chdir="$FRAMEWORK_DIR" destroy -auto-approve -input=false 2>&1 | tee "${GENERATED_DIR}/framework-destroy.log" || true
  else
    printf 'No local framework.auto.tfvars found; skipping local framework destroy.\n'
  fi
fi

if [[ -f "$HARNESS_TFVARS" ]]; then
  printf 'Destroying harness...\n'
  terraform -chdir="$HARNESS_DIR" init -backend=false -input=false
  terraform -chdir="$HARNESS_DIR" destroy -auto-approve -input=false -var-file="$HARNESS_TFVARS" 2>&1 | tee "${GENERATED_DIR}/harness-destroy.log" || true
else
  printf 'Missing %s; harness destroy needs the original required vars.\n' "$HARNESS_TFVARS" >&2
fi

deregister_fixture_amis

E2E_FORCE_DELETE_RDS_SECRETS=1 E2E_SWEEP_NO_GUARD=1 "${SCRIPT_DIR}/residue-sweep.sh"
rm -f "${GENERATED_DIR}/${PROJECT}.started"
