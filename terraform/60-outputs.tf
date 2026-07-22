#% =========================================================================================== %#
#% Outputs: 60-outputs.tf                                          | Category: Outputs (60-69) %#
#% ----- [ Description ] --------------------------------------------------------------------- %#
#% Output values make information about your infrastructure available on the command line, and %#
#%   can expose information for other Terraform configurations to use. Output values are       %#
#%   similar to return values in programming languages.                                        %#
#% =========================================================================================== %#

output "deployment_tags" {
  description = "Effective deployment-identity tag map derived from var.resource_metadata. Empty when metadata was not supplied (local plans, consumers that have not opted in). These keys are stamped onto every taggable AWS resource via provider default_tags and merged into EC2 root volume tags."
  value       = local.deployment_tags
}
