# Ephemeral Network Overlays Reference

The `overlays/` directory is a separate Terraform root that creates throwaway,
single-subnet public networks in its own state. Apply it before the framework
root and destroy it only after the framework root is gone.

Its `network_aliases` output is the typed seam into the framework. Both roots
also share the same deployment-identity tag contract so failed-run cleanup can
find only the intended repository and stack resources.

<!-- BEGIN_TF_DOCS -->
## Resources

| Name | Type |
| ---- | ---- |
| [aws_internet_gateway.us_east_1](https://registry.terraform.io/providers/hashicorp/aws/6.47.0/docs/resources/internet_gateway) | resource |
| [aws_route.us_east_1_default](https://registry.terraform.io/providers/hashicorp/aws/6.47.0/docs/resources/route) | resource |
| [aws_route_table.us_east_1](https://registry.terraform.io/providers/hashicorp/aws/6.47.0/docs/resources/route_table) | resource |
| [aws_route_table_association.us_east_1](https://registry.terraform.io/providers/hashicorp/aws/6.47.0/docs/resources/route_table_association) | resource |
| [aws_subnet.us_east_1](https://registry.terraform.io/providers/hashicorp/aws/6.47.0/docs/resources/subnet) | resource |
| [aws_vpc.us_east_1](https://registry.terraform.io/providers/hashicorp/aws/6.47.0/docs/resources/vpc) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| environment | Deployment environment tag value applied to managed AWS resources. | `string` | n/a | yes |
| networks | Throwaway per-deployment networks. Each entry creates one VPC, public subnet, internet gateway,<br/>route table, default route, and route-table association. The map key becomes the symbolic alias<br/>emitted to the framework; the empty default creates no resources. | <pre>map(object({<br/>    availability_zone = string<br/>    vpc_cidr          = string<br/>    subnet_cidr       = string<br/>    tags              = map(string)<br/>  }))</pre> | `{}` | no |
| resource\_metadata | Deployment identity stamped onto every taggable AWS resource through provider default\_tags.<br/>Stable fields answer who owns and manages a resource; commit\_sha and run\_id trace it to the<br/>exact commit and workflow run. The deploy workflow populates this through<br/>TF\_VAR\_resource\_metadata; the null default emits zero identity tags. | <pre>object({<br/>    repository    = string<br/>    repository_id = string<br/>    stack         = string<br/>    owner         = string<br/>    commit_sha    = string<br/>    run_id        = string<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| deployment\_tags | Deployment identity tags shared with the framework root. |
| network\_aliases | Framework-ready alias map. vpc\_id is always non-null so framework teardown never needs a DescribeSubnets lookup. |
| subnet\_ids | Created subnet ids keyed by symbolic network name. |
| vpc\_ids | Created VPC ids keyed by symbolic network name. |
<!-- END_TF_DOCS -->
