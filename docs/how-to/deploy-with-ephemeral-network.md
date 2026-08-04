# Deploy With an Ephemeral Network

Use this procedure when a data-only consumer needs a throwaway public subnet
for one deployment. It coordinates two Terraform roots and two states:

- framework: `<owner>/<stack>/aws.tfstate`
- network overlay: `<owner>/<stack>/aws-network.tfstate`

The overlay must exist before the framework is applied. The framework must be
destroyed before the overlay is destroyed.

## Prerequisites

Use Terraform `1.15.1` and the lockfiles committed in both roots. Export the
same deployment metadata for both roots; the leak gate relies on its
`repository-id` and `stack` values. If the workflow derives `stack` as a shell
variable, it must also export `TF_STACK` before any tag filter uses it:

```yaml
- name: Derive deployment identity
  shell: bash
  env:
    GH_REPOSITORY: ${{ github.repository }}
    GH_REPOSITORY_ID: ${{ github.repository_id }}
    GH_RUN_ID: ${{ github.run_id }}
    OWNER_TEAM: platform
  run: |
    set -euo pipefail
    stack="${GH_REPOSITORY##*/}"
    commit_sha="$(git rev-parse HEAD)"
    echo "TF_STACK=${stack}" >> "$GITHUB_ENV"
    echo "ALIAS_FILE=${GITHUB_WORKSPACE}/network-aliases.tfvars.json" >> "$GITHUB_ENV"
    printf 'TF_VAR_resource_metadata=%s\n' "$(jq -cn \
      --arg repository "$GH_REPOSITORY" \
      --arg repository_id "$GH_REPOSITORY_ID" \
      --arg stack "$stack" \
      --arg owner "$OWNER_TEAM" \
      --arg commit_sha "$commit_sha" \
      --arg run_id "$GH_RUN_ID" \
      '{repository: $repository, repository_id: $repository_id, stack: $stack,
        owner: $owner, commit_sha: $commit_sha, run_id: $run_id}')" >> "$GITHUB_ENV"
```

Before any Terraform command, reject a value file that still assigns the
removed framework variable. The tombstone also fails at plan time, but this
preflight gives the earliest diagnostic:

```shell
if grep -Eqn '^[[:space:]]*managed_networks[[:space:]]*=' \
  "${GITHUB_WORKSPACE}/terraform/aws.tfvars"; then
  echo "::error::terraform/aws.tfvars still assigns managed_networks; removed in framework 3.0.0" >&2
  exit 1
fi
```

The deploy role must have the tag-conditioned network policy described in
[IAM requirements](#iam-requirements) before enabling this procedure. The
default regional quotas are five VPCs and five Elastic IPs. Raise quota issues
with the `platform` owner/on-call; do not change subnet public-IP
auto-assignment without an ADR.

## Apply the two phases

Set the root paths used by the consumer checkout:

```shell
TF_DIR=.frameworks/aws-tf/terraform
TF_NET_DIR=.frameworks/aws-tf/overlays
```

Initialize and apply the network state first. `ephemeral-poc.tfvars` includes
`environment = "poc"`, so no separate environment argument is required.

```shell
terraform -chdir="${TF_NET_DIR}" init \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=${TF_STATE_KEY_PREFIX}/aws-network.tfstate" \
  -backend-config="region=${AWS_REGION:-us-east-1}"

terraform -chdir="${TF_NET_DIR}" apply -auto-approve \
  -var-file=ephemeral-poc.tfvars
```

Export the seam as a generated `.tfvars.json` file and validate the complete
contract. Do not pass the map through shell-quoted `-var` syntax.

```shell
terraform -chdir="${TF_NET_DIR}" output -json network_aliases \
  | jq '{network_aliases: .}' > "${ALIAS_FILE}"
tools/check_alias_file.sh "${ALIAS_FILE}" poc-net
EPHEMERAL_VPC_ID="$(jq -r '.network_aliases["poc-net"].vpc_id' "${ALIAS_FILE}")"
export EPHEMERAL_VPC_ID
```

Initialize the framework state and pass the alias file to every plan, apply,
refresh/OS-swap apply, and destroy invocation:

```shell
terraform -chdir="${TF_DIR}" init \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=${TF_STATE_KEY_PREFIX}/aws.tfstate" \
  -backend-config="region=${AWS_REGION:-us-east-1}"

terraform -chdir="${TF_DIR}" apply -auto-approve \
  -var-file="${GITHUB_WORKSPACE}/terraform/aws.tfvars" \
  -var-file="${ALIAS_FILE}"
```

Apply the overlay once per job and export its aliases once. Reapplying it
mid-job can replace subnet IDs and therefore every framework ENI.

## Destroy safely

First ensure that teardown has a contract-valid alias file. A missing or
corrupt output is replaced with a syntactically valid, lookup-free fallback.
Its non-null dummy `vpc_id` is load-bearing: a null value would make destroy
refresh `data.aws_subnet` for a fabricated subnet and could strand the state.

```shell
if ! tools/check_alias_file.sh "${ALIAS_FILE}" poc-net 2>/dev/null; then
  echo "::warning::alias file missing or invalid; writing lookup-free teardown fallback"
  printf '%s\n' \
    '{"network_aliases":{"poc-net":{"subnet_id":"subnet-00000000000000000","vpc_id":"vpc-00000000000000000","subnet_cidr":null,"availability_zone":null}}}' \
    > "${ALIAS_FILE}"
fi
```

Destroy the framework first:

```shell
terraform -chdir="${TF_DIR}" destroy -auto-approve \
  -var-file="${GITHUB_WORKSPACE}/terraform/aws.tfvars" \
  -var-file="${ALIAS_FILE}"
```

Only after that succeeds may the overlay be destroyed:

```shell
terraform -chdir="${TF_NET_DIR}" destroy -auto-approve \
  -var-file=ephemeral-poc.tfvars
```

In a workflow, give the framework destroy an ID. If it fails, skip overlay
destroy unless a live `describe-network-interfaces` probe proves that the
ephemeral VPC contains zero ENIs. Do not use `continue-on-error` on either
destroy. Snapshot both remote states on failure, and publish deployment
evidence only after successful teardown.

Ordinary GitHub Actions cancellation still evaluates `if: always()` steps, so
the destroy and leak gate normally run. A second, force-cancel request or job
timeout terminates those steps and is the residual silent-leak path.

## Fail loudly on leaks

No account-side reaper or sweeper exists. The final `always()` step must filter
on both rename-stable repository ID and exported stack, print every relevant
ID, fail the job, and escalate cleanup to the `platform` owner/on-call. This
example includes framework instances, Elastic IP associations, ENIs, and
security groups as well as the overlay resources:

```yaml
- name: Leak gate — fail on surviving tagged resources
  if: ${{ always() }}
  env:
    REPO_ID: ${{ github.repository_id }}
    STACK: ${{ env.TF_STACK }}
  shell: bash
  run: |
    set -euo pipefail
    : "${REPO_ID:?repository id is required}"
    : "${STACK:?TF_STACK must be exported by the identity step}"
    tagf="Name=tag:nwarila:management:repository-id,Values=${REPO_ID}"
    stackf="Name=tag:nwarila:management:stack,Values=${STACK}"
    leaked=0
    emit() {
      local kind="$1" ids
      shift
      ids="$("$@" --output text)"
      if [ -n "${ids}" ] && [ "${ids}" != "None" ]; then
        leaked=1
        echo "::error::LEAKED ${kind}: ${ids}"
      fi
    }

    emit instance aws ec2 describe-instances \
      --filters "${tagf}" "${stackf}" \
      --query 'Reservations[].Instances[].InstanceId'
    emit elastic-ip-association aws ec2 describe-addresses \
      --filters "${tagf}" "${stackf}" \
      --query 'Addresses[?AssociationId!=`null`].[AssociationId,AllocationId,NetworkInterfaceId]'
    emit network-interface aws ec2 describe-network-interfaces \
      --filters "${tagf}" "${stackf}" \
      --query 'NetworkInterfaces[].NetworkInterfaceId'
    emit security-group aws ec2 describe-security-groups \
      --filters "${tagf}" "${stackf}" \
      --query 'SecurityGroups[].GroupId'
    emit elastic-ip aws ec2 describe-addresses \
      --filters "${tagf}" "${stackf}" \
      --query 'Addresses[].AllocationId'
    emit route-table aws ec2 describe-route-tables \
      --filters "${tagf}" "${stackf}" \
      --query 'RouteTables[].[RouteTableId,Associations[].RouteTableAssociationId]'
    emit internet-gateway aws ec2 describe-internet-gateways \
      --filters "${tagf}" "${stackf}" \
      --query 'InternetGateways[].[InternetGatewayId,Attachments[].VpcId]'
    emit subnet aws ec2 describe-subnets \
      --filters "${tagf}" "${stackf}" \
      --query 'Subnets[].SubnetId'
    emit vpc aws ec2 describe-vpcs \
      --filters "${tagf}" "${stackf}" \
      --query 'Vpcs[].VpcId'

    if [ "${leaked}" -ne 0 ]; then
      echo "::error::No automatic sweeper exists. The platform owner/on-call must run the recovery procedure before the next deployment."
      exit 1
    fi
    echo "leak gate: OK — no tagged framework or network resource survives"
```

`make overlay-check` protects this gate's visibility by proving all four
taggable overlay addresses carry all six exact stable `nwarila:*` values in a
real-provider plan. Routes and route-table associations are not taggable.

## Recover a failed deployment

Recovery follows the same dependency direction as normal teardown. Do not
start with overlay destroy.

1. Restore or create the alias file and run `tools/check_alias_file.sh` against
   it. If output state is unavailable, use the lookup-free fallback above.
2. Reinitialize the framework backend and rerun **framework destroy first**,
   passing both the consumer tfvars and validated alias file.
3. Reinitialize the overlay backend and run overlay destroy only after the
   framework destroy succeeds or a zero-ENI probe proves no dependants remain.
4. Run the leak gate. If resources survive, the `platform` owner/on-call owns
   escalation and cleanup.

If state is unavailable, use the IDs printed by the leak gate and delete in
this dependency order:

1. Terminate the listed instance IDs. Disassociate each listed EIP
   `AssociationId`, then release its `AllocationId`.
2. Delete the listed network-interface IDs.
3. Delete the listed security-group IDs after their interfaces are gone.
4. Disassociate each listed route-table association ID, delete the default
   route, then delete the route table ID.
5. Detach each listed internet-gateway ID from its listed VPC ID, then delete
   the gateway.
6. Delete the listed subnet IDs.
7. Delete the listed VPC IDs.

The gate deliberately shows instances, EIP association/allocation pairs,
ENIs, and security groups before the network IDs so the operator never has to
guess which dependency blocks a VPC deletion.

Before a consumer opt-in merges, drill the missing-output path in scratch
state: apply both roots, delete the alias file, execute the fallback and both
destroys, and retain evidence that
`data.aws_subnet.us_east_1_inline_security_group` made zero `DescribeSubnets`
calls.

## IAM requirements

IAM changes belong in the consumer repository and must land before network
opt-in. The network policy has **14 statements before any per-resource-leg
splitting**, all constrained to the requested region:

| # | Responsibility | Required resource legs and tag condition |
|---:|---|---|
| 1 | Create tagged VPC | `vpc/*`; repository-id `RequestTag` |
| 2 | Create tagged subnet | `subnet/*` and parent `vpc/*`; request tag on subnet, resource tag on VPC |
| 3 | Create tagged internet gateway | `internet-gateway/*`; repository-id `RequestTag` |
| 4 | Create tagged route table | `route-table/*` and parent `vpc/*`; request tag on table, resource tag on VPC |
| 5 | Allocate tagged address | `elastic-ip/*`; repository-id `RequestTag` |
| 6 | Tag on create | VPC, subnet, gateway, route-table, and EIP legs; matching `ec2:CreateAction` plus repository-id `RequestTag` |
| 7 | Retag owned network | The same five legs; strict repository-id `ResourceTag = ours`. Do **not** require repository-id `RequestTag`, because a changed-only commit-sha/run-id update may omit it; rely on a separate wrong-identity explicit Deny. |
| 8 | Untag owned network safely | The same five legs; repository-id `ResourceTag = ours`, plus protected tag-key controls |
| 9 | Modify/delete owned VPC | `vpc/*`; repository-id `ResourceTag` |
| 10 | Modify/delete owned subnet | `subnet/*`; repository-id `ResourceTag` |
| 11 | Attach/detach/delete owned gateway | `internet-gateway/*` and `vpc/*` for attach/detach; repository-id `ResourceTag` on both |
| 12 | Mutate owned routing | Route-table and subnet legs where the action authorizes them. `CreateRoute` has the required route-table leg and an optional instance target only; an internet gateway is **not** an IAM resource leg. |
| 13 | Associate/disassociate/release owned address | `elastic-ip/*` and `network-interface/*` where required; repository-id `ResourceTag` |
| 14 | Read for Terraform and the leak gate | `DescribeVpcs`, `DescribeVpcAttribute`, `DescribeSubnets`, `DescribeInternetGateways`, `DescribeRouteTables`, `DescribeAddresses`, and `DescribeNetworkInterfaces` on `*`; no tag condition is supported |

The existing broad lifecycle policy may already allow `DeleteTags`. A narrow
Allow cannot protect identity keys from that broader Allow, so add explicit
Denies for deleting both `nwarila:management:repository-id` **and**
`nwarila:management:stack` (including the missing-`TagKeys` case). The retag
authority must also have an explicit wrong-repository-id Deny.

Five existing consumer Sids also need their literal VPC/subnet pins removed:
`RunInstancesEniInDeploySubnet`,
`RunInstancesSubnetAndGroupsInDeployVpc`, `UseEniSupportingLegs`,
`UseDeployVpcForPocSecurityGroupCreation`, and
`ManageTaggedPocSecurityGroupsInDeployVpc`. The first three must change
`StringEqualsIfExists` to strict `StringEquals`; otherwise an untagged subnet
leg is still allowed after the ARN pin disappears.

Simulator coverage uses own/sibling/untagged triples for every tag-conditioned
create or mutate statement and every migrated Sid. Read-only `Describe*`
statements are exempt from that triple because they support neither resource
tags nor resource-level permissions; test in-region allowed and out-of-region
denied instead. Include a changed-only retag test if policy design deviates from
the strict `ResourceTag` approach above.

Finally, enforce the 6,144 non-whitespace character policy limit, update every
tracked bootstrap list including expected role attachments, and complete the
consumer's full materialize/apply/`--check-drift`/simulator/live-principal
dry-run sequence. A source-only simulator cannot detect a failed live policy
version update.
