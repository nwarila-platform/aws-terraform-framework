# E2E Live-Proof Harness

This directory is a reusable live validation harness for the AWS Terraform framework. It builds a disposable VPC, a public runner, private framework subnets, key material, KMS, IAM profiles, RDS/LB scaffolding, and generated framework tfvars for the max-coverage proof matrix.

The harness is intentionally separate from `terraform/`: it has its own providers, no backend block, and local state only.

## Safety

- No script should be run without owner AWS credentials and an explicit `E2E_OPERATOR_CIDR`.
- The runner is the only public EC2 host. Framework instances are launched in private subnets with no NAT route.
- The framework apply runs from the runner by default so SSH readiness reaches private IPs.
- `MAX_MINUTES` defaults to `180`; `residue-sweep.sh` can trigger teardown if the marker shows the stack has exceeded that window.
- `e2e-down.sh` destroys the framework first, then the harness, then fixture AMIs/snapshots, then runs the independent residue sweep.

## Run

```bash
export E2E_OPERATOR_CIDR="203.0.113.10/32"
export E2E_REGION="us-east-1"
export E2E_NAME_PREFIX="e2e"

make e2e-up
make e2e-verify
# Stop here for the Claude review gate while the stack remains live.
make e2e-down
```

Optional toggles:

```bash
export E2E_USE_RUNNER=true
export E2E_ENABLE_RDS=true
export E2E_ENABLE_LB=true
export E2E_ENABLE_NLB=false
export MAX_MINUTES=180
```

Generated files live under `test/e2e/.generated/` and are ignored, including local state, rendered tfvars, logs, and PEM material.

## Coverage

`framework.auto.tfvars.tftpl` renders five systems in `us_east_1` while keeping `aws_config.regions = ["us_east_1", "us_west_2"]` for validation:

- `e2e-lin-raw`: raw AL2023 AMI, default `ec2-user`, running, two EBS data volumes.
- `e2e-lin-ubu`: raw Ubuntu AMI, `readiness_user = "ubuntu"`, stopped after the readiness gate, Backup tag override.
- `e2e-lin-fam`: self-built `app-linux`, proving newest family resolution.
- `e2e-lin-ver`: self-built `app-linux:1`, proving version pinning.
- `e2e-win-25`: `windows_server_2025_base`, `refresh = true`, SSH readiness over the in-box OpenSSH server, one Windows data volume.

RDS uses a managed master password, gp3, encryption, no public access, `allocated_storage = 20`, `dedicated_log_volume = false` for `db.t3.micro` compatibility, `deletion_protection = false`, and `skip_final_snapshot = true`. The live database name is `e2edb` because the framework passes `db_name` through to the AWS PostgreSQL database name field, which does not accept hyphens.

The internal ALB uses explicit security groups, two private subnets, one target group for `e2e-lin-raw`, and one HTTP listener.

## Verification

`verify.sh` prints PASS/FAIL lines and exits non-zero on any miss. It checks:

- apply completion/readiness log
- EC2 states, AMI IDs, IMDSv2, tags, readiness users, Windows SSH port
- EBS device names, encryption, and `skip_destroy`
- stopped-state ordering for Ubuntu
- RDS managed secret, gp3, encryption, no plaintext state password
- ALB/TG/listener wiring
- the 8-field `aws_instances` output
- OPA on the real plan and a deliberately bad fixture
- idempotency, refresh replacement, and readiness-key precondition behavior

For the Ubuntu host, verification first confirms the instance is stopped after the readiness gate, then briefly starts it for the explicit `ubuntu` SSH assertion and stops it again.

## Residue

The sweep is independent of Terraform state. Harness-owned resources are found by `Project=e2e-${E2E_NAME_PREFIX}`. Framework resources also use `Environment=e2e-${E2E_NAME_PREFIX}` where the current framework schema does not accept an arbitrary top-level `Project` tag for EC2/RDS inputs without changing `terraform/`.

The sweep covers EC2 instances, volumes, snapshots, ENIs, EIPs, key pairs, RDS instances/snapshots/subnet groups, RDS managed `rds!db-*` secrets, load balancers, target groups, IAM profiles/roles, KMS aliases/keys, VPCs, IGWs, subnets, route tables, and security groups. KMS keys already in `PendingDeletion` are reported as informational and are not counted as active residue because AWS does not support immediate key deletion.

## Cost

The default matrix is expected to stay well under the $5 budget: one t3.micro runner, three Linux t3.micro instances, one Windows t3.micro, small EBS volumes, one db.t3.micro PostgreSQL instance with 20 GB gp3, and one internal ALB. A two-hour run should be roughly a few tenths of a dollar in `us-east-1`, with the guard preventing accidental long-lived stacks.
