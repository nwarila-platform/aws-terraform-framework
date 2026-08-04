# Ephemeral POC network profile for the separate overlays Terraform root.
#
# Pass this file only to terraform -chdir=overlays. It sets environment as well as networks, so
# phase 1 needs no extra -var; a consumer may override it with a trailing -var environment=<value>.
# Export TF_VAR_resource_metadata for both Terraform roots. Without the shared repository-id and
# stack tags, the workflow leak gate cannot identify a surviving network safely.
#
# This entry creates one VPC, one public subnet, an internet gateway, a route table with a
# 0.0.0.0/0 route, and the route-table association. The subnet keeps map_public_ip_on_launch =
# false. Framework systems that need public egress set associate_public_ip = true so a stable
# Elastic IP is attached to the pre-created primary ENI. If subnet auto-assignment were enabled,
# it would also assign an address to that pre-created primary ENI.
#
# Egress TCP 443 and TCP/UDP 53 is only the SSM and DNS baseline. Application ports remain
# consumer-owned. The 10.1.10.0/24 range matches existing consumer security-group CIDR rules.
# Sibling deployments may reuse it only because every VPC is isolated; overlapping VPCs can never
# later be peered or joined to the same routed network.
#
# Each instance using this public path consumes one Elastic IP. The default regional Elastic IP
# quota is five, and this profile also consumes one of the default five VPCs; both quotas are shared
# by sibling repositories. Escalate quota pressure to the platform owner/on-call for a quota
# increase, or use an ADR before changing the subnet auto-assignment posture.
#
# Key pairs and IAM stay consumer-owned. The deploy role needs tag-conditioned authority for the
# full overlay lifecycle before this profile can be used; see
# docs/how-to/deploy-with-ephemeral-network.md. A failed destroy, force-cancel, or timeout can leave
# the network and framework Elastic IPs standing. No account-side reaper exists. The workflow leak
# gate is the backstop for ordinary failures and sends manual cleanup to the platform owner/on-call.

environment = "poc"

networks = {
  "poc-net" = {
    availability_zone = "us-east-1a"
    vpc_cidr          = "10.1.0.0/16"
    subnet_cidr       = "10.1.10.0/24"
    tags              = {}
  }
}
