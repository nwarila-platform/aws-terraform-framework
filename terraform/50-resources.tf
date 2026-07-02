#% =========================================================================================== %#
#% = File: 50-resources.tf                                       | Category: Resources (50-59) %#
#% ----- [ Description ] --------------------------------------------------------------------- %#
#% Resources are the most important element in the Terraform language. Each resource block     %#
#%   describes one or more infrastructure objects, such as virtual networks, compute           %#
#%   instances, or higher-level components such as DNS records.                                %#
#% =========================================================================================== %#

resource "terraform_data" "refresh" {
  input = var.refresh_serial
}
