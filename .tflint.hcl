// Core Terraform rules only. This repo does not enable tflint-ruleset-aws
// because CI does not run `tflint --init` or download provider-specific
// plugins during `make ci`.
config {
  call_module_type = "none"
}
