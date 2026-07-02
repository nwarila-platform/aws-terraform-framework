#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
E2E_DIR=$(cd -- "${SCRIPT_DIR}/.." && pwd)
ROOT_DIR=$(cd -- "${E2E_DIR}/../.." && pwd)
FRAMEWORK_DIR="${E2E_FRAMEWORK_DIR:-${ROOT_DIR}/terraform}"
GENERATED_DIR="${E2E_DIR}/.generated"
RUN_ENV="${GENERATED_DIR}/e2e.env"

REGION="${E2E_REGION:-us-east-1}"
NAME_PREFIX="${E2E_NAME_PREFIX:-e2e}"
PROJECT="e2e-${NAME_PREFIX}"
READINESS_KEY_PATH="${E2E_READINESS_KEY_PATH:-}"
EXPECT_RDS="${E2E_EXPECT_RDS:-true}"
EXPECT_LB="${E2E_EXPECT_LB:-true}"
REFRESH_SERIAL="${E2E_REFRESH_SERIAL:-0}"

PASS_COUNT=0
FAIL_COUNT=0

require() {
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf 'missing required command: %s\n' "$cmd" >&2
      exit 127
    fi
  done
}

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS: %s\n' "$1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL: %s\n' "$1"
}

check() {
  local label=$1
  shift

  if "$@"; then
    pass "$label"
  else
    fail "$label"
  fi
}

check_jq() {
  local label=$1
  local filter=$2
  local file=$3

  if jq -e "$filter" "$file" >/dev/null; then
    pass "$label"
  else
    fail "$label"
  fi
}

check_grep() {
  local label=$1
  local pattern=$2
  local file=$3

  if grep -Eq "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label"
  fi
}

id_for() {
  local host=$1
  jq -r --arg host "$host" '.[$host].instance_id' "$OUTPUT_JSON"
}

ip_for() {
  local host=$1
  jq -r --arg host "$host" '.[$host].private_ip' "$OUTPUT_JSON"
}

image_id_for() {
  local host=$1
  local id
  id=$(id_for "$host")
  jq -r --arg id "$id" '.Reservations[].Instances[] | select(.InstanceId == $id) | .ImageId' "$INSTANCES_JSON"
}

instance_jq() {
  local host=$1
  local filter=$2
  local id
  id=$(id_for "$host")
  jq -e --arg id "$id" ".Reservations[].Instances[] | select(.InstanceId == \$id) | (${filter})" "$INSTANCES_JSON" >/dev/null
}

ssh_check() {
  local user=$1
  local host_ip=$2
  local remote_cmd=$3

  ssh -i "$READINESS_KEY_PATH" \
    -o BatchMode=yes \
    -o ConnectTimeout=10 \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile="${GENERATED_DIR}/known_hosts" \
    "${user}@${host_ip}" "$remote_cmd" >/dev/null
}

describe_instances() {
  mapfile -t INSTANCE_IDS < <(jq -r 'to_entries[].value.instance_id' "$OUTPUT_JSON")
  aws ec2 describe-instances --region "$REGION" --instance-ids "${INSTANCE_IDS[@]}" >"$INSTANCES_JSON"
}

volume_devices_match() {
  local host=$1
  local expected_json=$2
  local id
  local volume_json="${GENERATED_DIR}/${host}-volumes.json"

  id=$(id_for "$host")
  aws ec2 describe-volumes \
    --region "$REGION" \
    --filters "Name=attachment.instance-id,Values=${id}" \
    >"$volume_json"

  jq -e --argjson expected "$expected_json" '
    ([.Volumes[].Attachments[]?.Device] | sort) as $actual
    | ($expected | sort) as $wanted
    | ($wanted - $actual | length) == 0
  ' "$volume_json" >/dev/null
}

data_volumes_encrypted() {
  local host=$1
  local volume_json="${GENERATED_DIR}/${host}-volumes.json"

  jq -e '[.Volumes[] | select((.Attachments[]?.Device // "") != "/dev/sda1") | .Encrypted] | all(. == true)' "$volume_json" >/dev/null
}

tag_equals() {
  local host=$1
  local tag_key=$2
  local expected=$3
  instance_jq "$host" "([.Tags[]? | select(.Key == \"${tag_key}\") | .Value][0]) == \"${expected}\""
}

if [[ -f "$RUN_ENV" ]]; then
  # shellcheck source=/dev/null
  source "$RUN_ENV"
  REGION="${E2E_REGION:-$REGION}"
  PROJECT="${E2E_PROJECT:-$PROJECT}"
  READINESS_KEY_PATH="${E2E_READINESS_KEY_PATH:-$READINESS_KEY_PATH}"
  EXPECT_RDS="${E2E_EXPECT_RDS:-$EXPECT_RDS}"
  EXPECT_LB="${E2E_EXPECT_LB:-$EXPECT_LB}"
fi

require aws jq nc opa ssh terraform
mkdir -p "$GENERATED_DIR"

OUTPUT_JSON="${GENERATED_DIR}/aws_instances.output.json"
INSTANCES_JSON="${GENERATED_DIR}/instances.describe.json"
STATE_JSON="${GENERATED_DIR}/terraform-show.json"
PLAN_FILE="${GENERATED_DIR}/e2e.plan"
PLAN_JSON="${GENERATED_DIR}/e2e-plan.json"
OPA_INPUT="${GENERATED_DIR}/opa-input.json"

terraform -chdir="$FRAMEWORK_DIR" output -json aws_instances >"$OUTPUT_JSON"
terraform -chdir="$FRAMEWORK_DIR" show -json >"$STATE_JSON"
describe_instances

check_grep "apply reached completion/readiness gate passed" "Apply complete!" "${GENERATED_DIR}/framework-apply.log"

check "all expected EC2 hosts are in the output" jq -e 'keys | sort == ["e2e-lin-fam","e2e-lin-raw","e2e-lin-ubu","e2e-lin-ver","e2e-win-25"]' "$OUTPUT_JSON"
check "e2e-lin-raw is running" instance_jq e2e-lin-raw '.State.Name == "running"'
check "e2e-lin-fam is running" instance_jq e2e-lin-fam '.State.Name == "running"'
check "e2e-lin-ver is running" instance_jq e2e-lin-ver '.State.Name == "running"'
check "e2e-win-25 is running" instance_jq e2e-win-25 '.State.Name == "running"'
check "e2e-lin-ubu is stopped after readiness" instance_jq e2e-lin-ubu '.State.Name == "stopped"'
check "all EC2 instances require IMDSv2" jq -e '[.Reservations[].Instances[].MetadataOptions.HttpTokens] | all(. == "required")' "$INSTANCES_JSON"

check "raw AL2023 AMI id matched" instance_jq e2e-lin-raw ".ImageId == \"${E2E_AL2023_AMI_ID}\""
check "raw Ubuntu AMI id matched" instance_jq e2e-lin-ubu ".ImageId == \"${E2E_UBUNTU_AMI_ID}\""
check "family AMI resolved to app-linux v2" instance_jq e2e-lin-fam ".ImageId == \"${E2E_FIXTURE_APP_LINUX_V2_AMI}\""
check "versioned AMI resolved to app-linux v1" instance_jq e2e-lin-ver ".ImageId == \"${E2E_FIXTURE_APP_LINUX_V1_AMI}\""
check "family AMI did not resolve to app-linux-extra" bash -c "[[ \"$(image_id_for e2e-lin-fam)\" != \"${E2E_FIXTURE_APP_LINUX_EXTRA_V1_AMI}\" ]]"
check "versioned AMI did not resolve to app-linux-extra" bash -c "[[ \"$(image_id_for e2e-lin-ver)\" != \"${E2E_FIXTURE_APP_LINUX_EXTRA_V1_AMI}\" ]]"
check "Windows alias resolved to captured 2025 base" instance_jq e2e-win-25 ".ImageId == \"${E2E_WINDOWS_2025_AMI_ID}\""

if [[ -n "$READINESS_KEY_PATH" && -f "$READINESS_KEY_PATH" ]]; then
  check "ec2-user can SSH to AL2023 raw host" ssh_check ec2-user "$(ip_for e2e-lin-raw)" "true"

  UBU_ID=$(id_for e2e-lin-ubu)
  aws ec2 start-instances --region "$REGION" --instance-ids "$UBU_ID" >/dev/null
  aws ec2 wait instance-running --region "$REGION" --instance-ids "$UBU_ID"
  check "ubuntu can SSH to Ubuntu host and sshd/ssh is active" ssh_check ubuntu "$(ip_for e2e-lin-ubu)" "systemctl is-active sshd || systemctl is-active ssh"
  aws ec2 stop-instances --region "$REGION" --instance-ids "$UBU_ID" >/dev/null
  aws ec2 wait instance-stopped --region "$REGION" --instance-ids "$UBU_ID"
  describe_instances
else
  fail "readiness private key exists for SSH rechecks"
fi

check "WinRM 5986 is reachable on Windows host" nc -z -w 10 "$(ip_for e2e-win-25)" 5986

check "raw Linux has /dev/sdd and /dev/sde data volumes" volume_devices_match e2e-lin-raw '["/dev/sdd","/dev/sde"]'
check "Ubuntu has /dev/sdd data volume" volume_devices_match e2e-lin-ubu '["/dev/sdd"]'
check "Windows has xvdd data volume" volume_devices_match e2e-win-25 '["xvdd"]'
check "raw Linux data volumes are encrypted" data_volumes_encrypted e2e-lin-raw
check "Ubuntu data volumes are encrypted" data_volumes_encrypted e2e-lin-ubu
check "Windows data volumes are encrypted" data_volumes_encrypted e2e-win-25
check_jq "volume_attachment skip_destroy values are reflected as false" '[.. | objects | select(.type? == "aws_volume_attachment") | .values.skip_destroy] | all(. == false)' "$STATE_JSON"

check "Ubuntu returned to stopped state after SSH recheck" instance_jq e2e-lin-ubu '.State.Name == "stopped"'
check_grep "apply log shows readiness gate ran before stopped-state control" "terraform_data\\.readiness_gate|aws_ec2_instance_state" "${GENERATED_DIR}/framework-apply.log"

for host in e2e-lin-raw e2e-lin-fam e2e-lin-ver e2e-win-25; do
  check "${host} Backup tag defaults to True" tag_equals "$host" Backup True
  check "${host} ManagedBy tag present" tag_equals "$host" ManagedBy Terraform
  check "${host} Environment tag is project" tag_equals "$host" Environment "$PROJECT"
  check "${host} Name tag is hostname" tag_equals "$host" Name "$host"
done
check "Ubuntu Backup tag override is False" tag_equals e2e-lin-ubu Backup False
check "Ubuntu Function tag is correct" tag_equals e2e-lin-ubu Function e2e-lin-ubu
check "Windows OS tag is present" instance_jq e2e-win-25 'any(.Tags[]?; .Key == "OS" and (.Value | test("Windows")))'

if [[ "$EXPECT_RDS" == "true" ]]; then
  RDS_JSON="${GENERATED_DIR}/rds.describe.json"
  SECRET_JSON="${GENERATED_DIR}/rds-secret.describe.json"
  aws rds describe-db-instances --region "$REGION" --db-instance-identifier "${E2E_DB_NAME:-e2edb}" >"$RDS_JSON"
  SECRET_ARN=$(jq -r '.DBInstances[0].MasterUserSecret.SecretArn // empty' "$RDS_JSON")

  check_jq "RDS instance is available" '.DBInstances[0].DBInstanceStatus == "available"' "$RDS_JSON"
  check_jq "RDS storage type is gp3" '.DBInstances[0].StorageType == "gp3"' "$RDS_JSON"
  check_jq "RDS storage is encrypted" '.DBInstances[0].StorageEncrypted == true' "$RDS_JSON"
  check_jq "RDS is not public" '.DBInstances[0].PubliclyAccessible == false' "$RDS_JSON"
  check_jq "RDS managed password secret exists in DB metadata" '.DBInstances[0].MasterUserSecret.SecretArn | type == "string"' "$RDS_JSON"
  if [[ -n "$SECRET_ARN" ]]; then
    aws secretsmanager describe-secret --region "$REGION" --secret-id "$SECRET_ARN" >"$SECRET_JSON"
    check_jq "managed password secret is readable by ARN" '.ARN | type == "string"' "$SECRET_JSON"
  else
    fail "managed password secret is readable by ARN"
  fi
  check_jq "RDS state has no plaintext password" '[.. | objects | select(.type? == "aws_db_instance") | .values.password] | all(. == null)' "$STATE_JSON"
  check_jq "RDS Backup tag defaults to True" 'any(.DBInstances[0].TagList[]?; .Key == "Backup" and .Value == "True")' "$RDS_JSON"
else
  pass "RDS assertions skipped because enable_rds=false"
fi

if [[ "$EXPECT_LB" == "true" ]]; then
  LB_JSON="${GENERATED_DIR}/lb.describe.json"
  TG_JSON="${GENERATED_DIR}/target-groups.output.json"
  LISTENERS_JSON="${GENERATED_DIR}/listeners.output.json"
  terraform -chdir="$FRAMEWORK_DIR" output -json aws_target_groups >"$TG_JSON"
  terraform -chdir="$FRAMEWORK_DIR" output -json aws_listeners >"$LISTENERS_JSON"
  aws elbv2 describe-load-balancers --region "$REGION" --names "${PROJECT}-alb" >"$LB_JSON"
  TG_ARN=$(jq -r '."e2e_alb/lin_raw".arn' "$TG_JSON")
  aws elbv2 describe-target-health --region "$REGION" --target-group-arn "$TG_ARN" >"${GENERATED_DIR}/target-health.json"

  check_jq "ALB is internal" '.LoadBalancers[0].Scheme == "internal"' "$LB_JSON"
  check_jq "ALB has explicit security groups" '.LoadBalancers[0].SecurityGroups | length > 0' "$LB_JSON"
  check_jq "target group output exists" 'has("e2e_alb/lin_raw")' "$TG_JSON"
  if jq -e --arg id "$(id_for e2e-lin-raw)" 'any(.TargetHealthDescriptions[]?; .Target.Id == $id)' "${GENERATED_DIR}/target-health.json" >/dev/null; then
    pass "raw Linux target is registered"
  else
    fail "raw Linux target is registered"
  fi
  check_jq "HTTP listener output exists" 'has("e2e_alb/http")' "$LISTENERS_JSON"
else
  pass "LB assertions skipped because enable_lb=false"
fi

check_jq "aws_instances output has exactly the 8 neutral fields" '
  ["environment","function","hostname","instance_id","os_family","private_dns","private_ip","region"] as $expected
  | length == 5
  and all(to_entries[]; (.value | keys | sort) == $expected)
' "$OUTPUT_JSON"
check_jq "aws_instances output has expected private IPs and normalized region" '
  all(to_entries[]; .value.region == "us_east_1")
  and .["e2e-lin-raw"].private_ip == "10.42.10.10"
  and .["e2e-lin-ubu"].private_ip == "10.42.10.11"
  and .["e2e-lin-fam"].os_family == "linux"
  and .["e2e-win-25"].os_family == "windows"
' "$OUTPUT_JSON"

set +e
terraform -chdir="$FRAMEWORK_DIR" plan -detailed-exitcode -input=false -out="$PLAN_FILE" >"${GENERATED_DIR}/idempotency-plan.log" 2>&1
PLAN_EXIT=$?
set -e
if [[ $PLAN_EXIT -eq 0 ]]; then
  pass "idempotency plan is empty"
elif [[ $PLAN_EXIT -eq 2 ]]; then
  fail "idempotency plan is empty"
else
  fail "idempotency plan completed"
fi

terraform -chdir="$FRAMEWORK_DIR" show -json "$PLAN_FILE" >"$PLAN_JSON"
jq '{
  resources: (
    (.planned_values.root_module.resources // [])
    + ([.planned_values.root_module.child_modules[]?.resources[]?] // [])
  ) | map({address: .address, type: .type, values: .values})
}' "$PLAN_JSON" >"$OPA_INPUT"

if opa eval --fail-defined --format pretty --input "$OPA_INPUT" --data "${ROOT_DIR}/policies/opa" 'data.terraform_plan.deny[_]' >"${GENERATED_DIR}/opa-real-plan.log" 2>&1; then
  pass "OPA deny is undefined on the real plan"
else
  fail "OPA deny is undefined on the real plan"
fi

cat >"${GENERATED_DIR}/opa-bad-input.json" <<'JSON'
{
  "resources": [
    {"address": "aws_instance.public_ip", "type": "aws_instance", "values": {"associate_public_ip_address": true, "metadata_options": {"http_tokens": "required"}, "root_block_device": {"encrypted": true}}},
    {"address": "aws_instance.unencrypted_root", "type": "aws_instance", "values": {"associate_public_ip_address": false, "metadata_options": {"http_tokens": "required"}, "root_block_device": {"encrypted": false}}},
    {"address": "aws_ebs_volume.unencrypted", "type": "aws_ebs_volume", "values": {"encrypted": false}},
    {"address": "aws_db_instance.public", "type": "aws_db_instance", "values": {"storage_encrypted": true, "publicly_accessible": true}},
    {"address": "aws_network_interface.empty", "type": "aws_network_interface", "values": {"security_groups": []}}
  ]
}
JSON
opa eval --format json --input "${GENERATED_DIR}/opa-bad-input.json" --data "${ROOT_DIR}/policies/opa" 'data.terraform_plan.deny[_]' >"${GENERATED_DIR}/opa-bad-output.json"
check_grep "OPA bad fixture denies public IP" "public IP" "${GENERATED_DIR}/opa-bad-output.json"
check_grep "OPA bad fixture denies unencrypted root" "root_block_device" "${GENERATED_DIR}/opa-bad-output.json"
check_grep "OPA bad fixture denies unencrypted EBS" "aws_ebs_volume.unencrypted" "${GENERATED_DIR}/opa-bad-output.json"
check_grep "OPA bad fixture denies public DB" "publicly_accessible" "${GENERATED_DIR}/opa-bad-output.json"
check_grep "OPA bad fixture denies empty SG ENI" "default SG" "${GENERATED_DIR}/opa-bad-output.json"

set +e
terraform -chdir="$FRAMEWORK_DIR" plan -detailed-exitcode -input=false -var "refresh_serial=$((REFRESH_SERIAL + 1))" -out="${GENERATED_DIR}/refresh.plan" >"${GENERATED_DIR}/refresh-plan.log" 2>&1
REFRESH_EXIT=$?
set -e
if [[ $REFRESH_EXIT -eq 2 ]]; then
  pass "refresh_serial bump creates a non-empty plan"
  terraform -chdir="$FRAMEWORK_DIR" show -json "${GENERATED_DIR}/refresh.plan" >"${GENERATED_DIR}/refresh-plan.json"
  check_jq "refresh_serial replaces only the refresh Windows instance" '
    [.resource_changes[]? | select((.change.actions | index("delete")) and (.change.actions | index("create"))) | .address] as $replaced
    | ($replaced | any(. == "aws_instance.us_east_1_refresh[\"e2e-win-25\"]"))
    and ($replaced | all(contains("e2e-win-25") or . == "terraform_data.refresh"))
  ' "${GENERATED_DIR}/refresh-plan.json"
else
  fail "refresh_serial bump creates a non-empty plan"
fi

set +e
terraform -chdir="$FRAMEWORK_DIR" plan -input=false -var 'readiness_private_key_paths={unrelated="/tmp/unrelated.pem"}' >"${GENERATED_DIR}/precondition-plan.log" 2>&1
PRECONDITION_EXIT=$?
set -e
if [[ $PRECONDITION_EXIT -ne 0 ]]; then
  pass "missing readiness key precondition fails fast"
  check_grep "precondition names host and key" "host e2e-|key_name" "${GENERATED_DIR}/precondition-plan.log"
else
  fail "missing readiness key precondition fails fast"
fi

printf 'E2E verify tally: %s passed, %s failed\n' "$PASS_COUNT" "$FAIL_COUNT"
if [[ $FAIL_COUNT -ne 0 ]]; then
  exit 1
fi
