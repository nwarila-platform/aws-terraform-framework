# Changelog

## [1.1.0](https://github.com/nwarila-platform/aws-terraform-framework/compare/v1.0.0...v1.1.0) (2026-07-22)


### Features

* expose validated IMDS hop limit and pin remaining metadata hardcodes ([#87](https://github.com/nwarila-platform/aws-terraform-framework/issues/87)) ([b99b7aa](https://github.com/nwarila-platform/aws-terraform-framework/commit/b99b7aac4ed59ddf26c888b6dfeecd6641b6da55))

## 1.0.0 (2026-07-22)

### Features

* Provide a single-region AWS framework for `us_east_1`.
* Support an SSH/SSM-only Windows path.
* Offer managed key pairs, security groups, networking, and Elastic IP addresses.
* Expose Packer-compatible, fully explicit variable surfaces.
* Apply a hard-code-first security baseline with footgun validations.
* Validate the framework through a 109-test mocked suite and policy-free gate chain.
