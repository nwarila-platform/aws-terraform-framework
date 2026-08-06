# Changelog

## [2.2.0](https://github.com/nwarila-platform/aws-terraform-framework/compare/v2.1.0...v2.2.0) (2026-08-06)


### Features

* **ec2:** allow a stable public address on bring-your-own subnets ([#104](https://github.com/nwarila-platform/aws-terraform-framework/issues/104)) ([2b48b34](https://github.com/nwarila-platform/aws-terraform-framework/commit/2b48b34e65525bacb15330a79ef7eea2417d4572))
* **variables:** environment is a closed lowercase set (dev, test, prod) ([#102](https://github.com/nwarila-platform/aws-terraform-framework/issues/102)) ([0e25eef](https://github.com/nwarila-platform/aws-terraform-framework/commit/0e25eef80fe4faf4d0e0345380bc99220b29e953))

## [2.1.0](https://github.com/nwarila-platform/aws-terraform-framework/compare/v2.0.0...v2.1.0) (2026-08-05)


### Features

* **ec2:** resolve symbolic subnet aliases to existing subnets ([#100](https://github.com/nwarila-platform/aws-terraform-framework/issues/100)) ([a5ded6f](https://github.com/nwarila-platform/aws-terraform-framework/commit/a5ded6f2b107c5289537176486508350939d85a5))

## [2.0.0](https://github.com/nwarila-platform/aws-terraform-framework/compare/v1.1.0...v2.0.0) (2026-07-30)


### ⚠ BREAKING CHANGES

* **ec2:** a security group belongs to the interface it protects ([#94](https://github.com/nwarila-platform/aws-terraform-framework/issues/94))
* **ec2:** systems own their security groups; drop the standalone group map ([#93](https://github.com/nwarila-platform/aws-terraform-framework/issues/93))

### Features

* **ec2:** a security group belongs to the interface it protects ([#94](https://github.com/nwarila-platform/aws-terraform-framework/issues/94)) ([ae6ea1e](https://github.com/nwarila-platform/aws-terraform-framework/commit/ae6ea1e2942bae92fd86a16c8208ce1d09fa3962))
* **ec2:** bootstrap the SSM agent on AMIs that omit it, and own the backend invariants ([#89](https://github.com/nwarila-platform/aws-terraform-framework/issues/89)) ([4f18b30](https://github.com/nwarila-platform/aws-terraform-framework/commit/4f18b3034bcb7e13bce090986fd3f1075c07a7cd))
* **ec2:** guard a pinned interface address, and let AWS pick by default ([#96](https://github.com/nwarila-platform/aws-terraform-framework/issues/96)) ([f4086e0](https://github.com/nwarila-platform/aws-terraform-framework/commit/f4086e0be413433e31e66187b23752451c8adc68))
* **ec2:** name generated security groups &lt;hostname&gt;-sg-&lt;index&gt;, matching the module's own convention ([#92](https://github.com/nwarila-platform/aws-terraform-framework/issues/92)) ([500f449](https://github.com/nwarila-platform/aws-terraform-framework/commit/500f449b5ba5c24f0af8c68e63c5ef81051a151f))
* **ec2:** optional per-system inline security group, and an allowlist guard that runs ([#91](https://github.com/nwarila-platform/aws-terraform-framework/issues/91)) ([fd2ae35](https://github.com/nwarila-platform/aws-terraform-framework/commit/fd2ae3544ae18ff95df43117677b209fbf287f28))
* **ec2:** systems own their security groups; drop the standalone group map ([#93](https://github.com/nwarila-platform/aws-terraform-framework/issues/93)) ([c5e850d](https://github.com/nwarila-platform/aws-terraform-framework/commit/c5e850d5f18b5dd5dcf72a908b445cd9cc98de18))

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
