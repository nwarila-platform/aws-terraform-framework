#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
E2E_DIR=$(cd -- "${SCRIPT_DIR}/.." && pwd)
GENERATED_DIR="${E2E_DIR}/.generated"
RUN_ENV="${GENERATED_DIR}/e2e.env"

REGION="${E2E_REGION:-us-east-1}"
NAME_PREFIX="${E2E_NAME_PREFIX:-e2e}"
PROJECT="e2e-${NAME_PREFIX}"
MAX_MINUTES="${MAX_MINUTES:-180}"
SURVIVORS_FILE="${GENERATED_DIR}/residue-survivors.txt"

require() {
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf 'missing required command: %s\n' "$cmd" >&2
      exit 127
    fi
  done
}

add_survivor() {
  [[ -z "$2" || "$2" == "None" || "$2" == "null" ]] && return 0
  printf '%s\t%s\n' "$1" "$2" | tee -a "$SURVIVORS_FILE"
}

has_project_or_environment_tag() {
  local json=$1
  jq -e --arg project "$PROJECT" 'any(.Tags[]?; (.Key == "Project" or .Key == "Environment") and .Value == $project)' <<<"$json" >/dev/null
}

run_cost_guard() {
  local start_file="${GENERATED_DIR}/${PROJECT}.started"
  local started now age_minutes

  if [[ "${E2E_SWEEP_NO_GUARD:-0}" == "1" || ! -f "$start_file" ]]; then
    return 0
  fi

  started=$(<"$start_file")
  now=$(date +%s)
  age_minutes=$(((now - started) / 60))

  if ((age_minutes > MAX_MINUTES)); then
    printf 'Cost guard: %s has been up for %s minutes (limit %s); triggering e2e-down.\n' "$PROJECT" "$age_minutes" "$MAX_MINUTES" >&2
    E2E_SWEEP_NO_GUARD=1 "${SCRIPT_DIR}/e2e-down.sh" || true
  fi
}

sweep_ec2_instances() {
  aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:Project,Values=${PROJECT}" "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text | tr '\t' '\n' | while IFS= read -r id; do
      [[ -n "$id" ]] && add_survivor ec2-instance "$id"
    done

  aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:Environment,Values=${PROJECT}" "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text | tr '\t' '\n' | while IFS= read -r id; do
      [[ -n "$id" ]] && add_survivor ec2-instance "$id"
    done
}

sweep_ec2_simple() {
  local kind=$1
  local query=$2
  shift 2

  aws ec2 "$@" \
    --region "$REGION" \
    --filters "Name=tag:Project,Values=${PROJECT}" \
    --query "$query" \
    --output text | tr '\t' '\n' | while IFS= read -r id; do
      [[ -n "$id" ]] && add_survivor "$kind" "$id"
    done
}

sweep_rds_tagged() {
  local describe_cmd=$1
  local array_filter=$2
  local id_filter=$3
  local arn_filter=$4
  local kind=$5
  local json

  json=$(aws rds "$describe_cmd" --region "$REGION" --output json)
  jq -c "${array_filter}[]" <<<"$json" | while IFS= read -r item; do
    local id arn tags
    id=$(jq -r "$id_filter" <<<"$item")
    arn=$(jq -r "$arn_filter" <<<"$item")
    [[ -z "$arn" || "$arn" == "null" ]] && continue
    tags=$(aws rds list-tags-for-resource --region "$REGION" --resource-name "$arn" --output json)
    if has_project_or_environment_tag "$tags"; then
      add_survivor "$kind" "$id"
    fi
  done
}

sweep_elbv2_tagged() {
  local describe_cmd=$1
  local array_filter=$2
  local arn_filter=$3
  local kind=$4
  local json

  json=$(aws elbv2 "$describe_cmd" --region "$REGION" --output json)
  jq -r "${array_filter}[] | ${arn_filter}" <<<"$json" | while IFS= read -r arn; do
    local tags
    [[ -z "$arn" || "$arn" == "null" ]] && continue
    tags=$(aws elbv2 describe-tags --region "$REGION" --resource-arns "$arn" --output json)
    if jq -e --arg project "$PROJECT" 'any(.TagDescriptions[].Tags[]?; .Key == "Project" and .Value == $project)' <<<"$tags" >/dev/null; then
      add_survivor "$kind" "$arn"
    fi
  done
}

sweep_iam() {
  aws iam list-instance-profiles --output json | jq -r '.InstanceProfiles[].InstanceProfileName' | while IFS= read -r name; do
    [[ "$name" != "${PROJECT}-framework" && "$name" != "${PROJECT}-runner" ]] && continue
    add_survivor iam-instance-profile "$name"
  done

  aws iam list-roles --output json | jq -r '.Roles[].RoleName' | while IFS= read -r name; do
    [[ "$name" != "${PROJECT}-framework" && "$name" != "${PROJECT}-runner" ]] && continue
    add_survivor iam-role "$name"
  done
}

sweep_kms() {
  aws kms list-aliases --region "$REGION" --output json |
    jq -r --arg alias "alias/${PROJECT}" '.Aliases[] | select(.AliasName == $alias) | .AliasName' |
    while IFS= read -r alias_name; do
      [[ -n "$alias_name" ]] && add_survivor kms-alias "$alias_name"
    done

  aws kms list-keys --region "$REGION" --output json | jq -r '.Keys[].KeyId' | while IFS= read -r key_id; do
    local tags state
    tags=$(aws kms list-resource-tags --region "$REGION" --key-id "$key_id" --output json 2>/dev/null || true)
    if jq -e --arg project "$PROJECT" 'any(.Tags[]?; .TagKey == "Project" and .TagValue == $project)' <<<"$tags" >/dev/null; then
      state=$(aws kms describe-key --region "$REGION" --key-id "$key_id" --query 'KeyMetadata.KeyState' --output text)
      if [[ "$state" == "PendingDeletion" ]]; then
        printf 'INFO: kms-key %s is pending deletion and is not counted as active residue.\n' "$key_id"
      else
        add_survivor kms-key "$key_id"
      fi
    fi
  done
}

sweep_secrets() {
  aws secretsmanager list-secrets --region "$REGION" --include-planned-deletion --output json |
    jq -c --arg project "$PROJECT" '.SecretList[]
      | select((.Name | startswith("rds!db-")) and any(.Tags[]?; (.Key == "Project" or .Key == "Environment") and .Value == $project))' |
    while IFS= read -r secret; do
      local arn name deleted
      arn=$(jq -r '.ARN' <<<"$secret")
      name=$(jq -r '.Name' <<<"$secret")
      deleted=$(jq -r '.DeletedDate // empty' <<<"$secret")

      if [[ -z "$deleted" && "${E2E_FORCE_DELETE_RDS_SECRETS:-0}" == "1" ]]; then
        printf 'Force-deleting lingering RDS managed secret %s\n' "$name"
        aws secretsmanager delete-secret --region "$REGION" --secret-id "$arn" --force-delete-without-recovery >/dev/null || true
      else
        add_survivor secret "$name"
      fi
    done
}

require aws jq
mkdir -p "$GENERATED_DIR"
: >"$SURVIVORS_FILE"

if [[ -f "$RUN_ENV" ]]; then
  # shellcheck source=/dev/null
  source "$RUN_ENV"
  REGION="${E2E_REGION:-$REGION}"
  PROJECT="${E2E_PROJECT:-$PROJECT}"
fi

run_cost_guard

sweep_ec2_instances
sweep_ec2_simple ebs-volume 'Volumes[].VolumeId' describe-volumes
sweep_ec2_simple ebs-snapshot 'Snapshots[].SnapshotId' describe-snapshots --owner-ids self
sweep_ec2_simple eni 'NetworkInterfaces[].NetworkInterfaceId' describe-network-interfaces
sweep_ec2_simple eip 'Addresses[].AllocationId' describe-addresses
sweep_ec2_simple key-pair 'KeyPairs[].KeyName' describe-key-pairs
sweep_ec2_simple vpc 'Vpcs[].VpcId' describe-vpcs
sweep_ec2_simple internet-gateway 'InternetGateways[].InternetGatewayId' describe-internet-gateways
sweep_ec2_simple subnet 'Subnets[].SubnetId' describe-subnets
sweep_ec2_simple route-table 'RouteTables[].RouteTableId' describe-route-tables
sweep_ec2_simple security-group 'SecurityGroups[].GroupId' describe-security-groups

sweep_rds_tagged describe-db-instances '.DBInstances' '.DBInstanceIdentifier' '.DBInstanceArn' rds-instance
sweep_rds_tagged describe-db-snapshots '.DBSnapshots' '.DBSnapshotIdentifier' '.DBSnapshotArn' rds-snapshot
sweep_rds_tagged describe-db-subnet-groups '.DBSubnetGroups' '.DBSubnetGroupName' '.DBSubnetGroupArn' rds-subnet-group

sweep_elbv2_tagged describe-load-balancers '.LoadBalancers' '.LoadBalancerArn' load-balancer
sweep_elbv2_tagged describe-target-groups '.TargetGroups' '.TargetGroupArn' target-group
sweep_iam
sweep_kms
sweep_secrets

sort -u "$SURVIVORS_FILE" -o "$SURVIVORS_FILE"

if [[ -s "$SURVIVORS_FILE" ]]; then
  printf 'Residue remains for %s:\n' "$PROJECT" >&2
  cat "$SURVIVORS_FILE" >&2
  exit 1
fi

printf 'Residue sweep clean for %s in %s.\n' "$PROJECT" "$REGION"
