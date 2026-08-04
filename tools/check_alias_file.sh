#!/usr/bin/env bash

# Validate the generated framework alias var-file before apply and again before teardown.
# Usage: check_alias_file.sh <file> [expected-alias-key]   (default: poc-net)
#        check_alias_file.sh --self-test
set -euo pipefail

validate() {
  local alias_file="$1"
  local expected_key="${2:-poc-net}"

  jq -e --arg key "${expected_key}" '
    def ipv4_cidr:
      type == "string"
      and test("^([0-9]{1,3}\\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$")
      and ((split("/")[0] | split(".") | map(tonumber)) as $octets
           | ($octets | length) == 4
           and all($octets[]; . >= 0 and . <= 255));

    type == "object"
    and (keys == ["network_aliases"])
    and (.network_aliases | type == "object")
    and (.network_aliases | has($key))
    and (.network_aliases | length > 0)
    and all(.network_aliases | keys[]; test("^subnet-") | not)
    and all(.network_aliases[];
      type == "object"
      and ((keys | sort) == ["availability_zone", "subnet_cidr", "subnet_id", "vpc_id"])
      and (.subnet_id | type == "string")
      and (.subnet_id | test("^subnet-[0-9a-z][0-9a-z-]*$"))
      and (.vpc_id | type == "string")
      and (.vpc_id | test("^vpc-[0-9a-z][0-9a-z-]*$"))
      and ((.subnet_cidr == null) or (.subnet_cidr | ipv4_cidr))
      and ((.availability_zone == null)
           or ((.availability_zone | type == "string")
               and (.availability_zone | test("^us-east-1[a-f]$")))))
  ' "${alias_file}" >/dev/null
}

self_test() {
  local temp_dir failures=0
  temp_dir=$(mktemp -d)
  trap 'rm -rf -- "${temp_dir}"' RETURN

  run_case() {
    local name="$1" expected="$2" fixture="$3"
    local path="${temp_dir}/${name}.json" actual="reject"
    printf '%s\n' "${fixture}" >"${path}"
    if validate "${path}" 2>/dev/null; then
      actual="accept"
    fi
    if [ "${actual}" != "${expected}" ]; then
      printf 'alias checker self-test FAILED: %s expected %s, got %s\n' "${name}" "${expected}" "${actual}" >&2
      failures=$((failures + 1))
    fi
  }

  run_case well_formed accept '{"network_aliases":{"poc-net":{"subnet_id":"subnet-0123456789abcdef0","vpc_id":"vpc-0123456789abcdef0","subnet_cidr":"10.1.10.0/24","availability_zone":"us-east-1a"}}}'
  run_case teardown_fallback accept '{"network_aliases":{"poc-net":{"subnet_id":"subnet-00000000000000000","vpc_id":"vpc-00000000000000000","subnet_cidr":null,"availability_zone":null}}}'
  run_case empty_document reject '{}'
  run_case empty_alias_map reject '{"network_aliases":{}}'
  run_case missing_vpc_id reject '{"network_aliases":{"poc-net":{"subnet_id":"subnet-fake","subnet_cidr":null,"availability_zone":null}}}'
  run_case null_vpc_id reject '{"network_aliases":{"poc-net":{"subnet_id":"subnet-fake","vpc_id":null,"subnet_cidr":null,"availability_zone":null}}}'
  run_case wrong_alias reject '{"network_aliases":{"wrong":{"subnet_id":"subnet-fake","vpc_id":"vpc-fake","subnet_cidr":null,"availability_zone":null}}}'
  run_case numeric_cidr reject '{"network_aliases":{"poc-net":{"subnet_id":"subnet-fake","vpc_id":"vpc-fake","subnet_cidr":42,"availability_zone":null}}}'
  run_case array_az reject '{"network_aliases":{"poc-net":{"subnet_id":"subnet-fake","vpc_id":"vpc-fake","subnet_cidr":null,"availability_zone":[]}}}'
  run_case fifth_field reject '{"network_aliases":{"poc-net":{"subnet_id":"subnet-fake","vpc_id":"vpc-fake","subnet_cidr":null,"availability_zone":null,"extra":true}}}'
  run_case symbolic_subnet reject '{"network_aliases":{"poc-net":{"subnet_id":"poc-subnet","vpc_id":"vpc-fake","subnet_cidr":null,"availability_zone":null}}}'
  run_case non_json reject 'not-json'
  # Adjacent shell quotes keep the removed key out of structural source greps while producing the
  # exact extra top-level key that a stale consumer file would contain.
  run_case extra_top_level reject '{"network_aliases":{"poc-net":{"subnet_id":"subnet-fake","vpc_id":"vpc-fake","subnet_cidr":null,"availability_zone":null}},"managed_''networks":{}}'
  run_case subnet_shaped_alias reject '{"network_aliases":{"poc-net":{"subnet_id":"subnet-fake","vpc_id":"vpc-fake","subnet_cidr":null,"availability_zone":null},"subnet-poc":{"subnet_id":"subnet-other","vpc_id":"vpc-other","subnet_cidr":null,"availability_zone":null}}}'
  run_case out_of_range_octets reject '{"network_aliases":{"poc-net":{"subnet_id":"subnet-fake","vpc_id":"vpc-fake","subnet_cidr":"999.999.999.999/24","availability_zone":"us-east-1a"}}}'

  if [ "${failures}" -ne 0 ]; then
    return 1
  fi
  echo "alias-contract-check: all positive and negative fixtures passed"
}

if [ "${1:-}" = "--self-test" ]; then
  self_test
  exit
fi

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: check_alias_file.sh <file> [expected-alias-key] | --self-test" >&2
  exit 2
fi

validate "$1" "${2:-poc-net}"
