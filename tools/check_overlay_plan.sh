#!/usr/bin/env bash

# The framework root cannot have an equivalent credential-free plan gate: any fixture system pulls
# live AMI, KMS alias, key-pair, and instance-profile data. Mocked framework tests cover the seam;
# this real-provider overlays plan proves default_tags become exact tags_all values. It is
# credential-free, not offline: init may download the pinned provider.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "${script_dir}/.." && pwd)
temp_dir=$(mktemp -d)

cleanup() {
  rm -rf -- "${temp_dir}"
}
trap cleanup EXIT

cp "${repo_root}"/overlays/*.tf "${temp_dir}/"
cp "${repo_root}/overlays/.terraform.lock.hcl" "${temp_dir}/"

cat >"${temp_dir}/overlay_check_override.tf" <<'EOF'
terraform {
  backend "local" {}
}

provider "aws" {
  alias                       = "us_east_1"
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}
EOF

export TF_IN_AUTOMATION=1
export TF_VAR_resource_metadata='{"repository":"nwarila-platform/aws-terraform-framework","repository_id":"1","stack":"ci","owner":"platform","commit_sha":null,"run_id":null}'

terraform -chdir="${temp_dir}" init -input=false
terraform -chdir="${temp_dir}" plan -input=false -out=tfplan \
  -var-file="${repo_root}/overlays/ephemeral-poc.tfvars"
terraform -chdir="${temp_dir}" show -json tfplan >"${temp_dir}/plan.json"

# The mocked test provider cannot compute provider default_tags. This real-provider plan must name
# all four taggable addresses and prove all six nwarila:* values exactly; extra non-nwarila tags are
# allowed. Routes and associations are not taggable and therefore have no tags_all contract.
jq -e '
  ["aws_vpc.us_east_1[\"poc-net\"]",
   "aws_subnet.us_east_1[\"poc-net\"]",
   "aws_internet_gateway.us_east_1[\"poc-net\"]",
   "aws_route_table.us_east_1[\"poc-net\"]"] as $want_addrs
  | {"nwarila:management:managed-by":  "terraform",
     "nwarila:management:repository":  "nwarila-platform/aws-terraform-framework",
     "nwarila:management:repository-id":"1",
     "nwarila:management:stack":       "ci",
     "nwarila:management:environment": "poc",
     "nwarila:operations:owner":       "platform"} as $want_tags
  | [ .resource_changes[] | select(.change.actions | index("create")) ] as $creates
  | (($creates | map(.address)) as $got
     | all($want_addrs[]; . as $a | $got | index($a) != null))
  and all($creates[]; select(.address as $a | $want_addrs | index($a) != null)
        | .change.after.tags_all as $t
        | all($want_tags | to_entries[]; $t[.key] == .value))
' "${temp_dir}/plan.json" >/dev/null || {
  echo "overlay-check: provider default_tags are missing, mis-valued, or a taggable resource address changed" >&2
  exit 1
}

echo "overlay-check: all four taggable addresses carry the six exact deployment identity values"
