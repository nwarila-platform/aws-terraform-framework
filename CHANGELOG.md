# Changelog

## [4.0.0](https://github.com/nwarila-platform/aws-terraform-framework/compare/v3.1.2...v4.0.0) (2026-09-02)


### ⚠ BREAKING CHANGES

* **ebs:** shared_ebs_volumes is a list(object) carrying resource_key instead of a map keyed by it; rewrite each map entry as a list element with resource_key set to its former key.
* root_block_device.delete_on_termination, ami_block_device_overrides[*].delete_on_termination and ebs_block_devices[*].skip_destroy leave the consumer surface; the module fixes them true/true/false. Remove them from tfvars. A consumer already writing those values sees no plan diff. One holding skip_destroy = true in state must apply this alone before any destroy or refresh_serial bump.
* **ebs:** attachments on systems with refresh enabled move resource address, because the refresh-specific attachment resource no longer exists. For each affected state, move every such attachment before applying:

### Features

* **ebs:** let one volume serve the several instances that share it ([5841f50](https://github.com/nwarila-platform/aws-terraform-framework/commit/5841f507eb41bdb9451a4d01057c423033342868))
* **ec2:** install OpenSSH on Windows 2022 from a staged Feature-on-Demand cab ([#127](https://github.com/nwarila-platform/aws-terraform-framework/issues/127)) ([51d7c0e](https://github.com/nwarila-platform/aws-terraform-framework/commit/51d7c0e8e302db0ff45381309856f4a8cb98c8b2))
* **ec2:** let one interface carry the several addresses a cluster needs ([#126](https://github.com/nwarila-platform/aws-terraform-framework/issues/126)) ([36710d6](https://github.com/nwarila-platform/aws-terraform-framework/commit/36710d6a15eaa50a0ef70f886c0875fb930bf14a))
* **ingress:** grant a human their own way in ([#122](https://github.com/nwarila-platform/aws-terraform-framework/issues/122)) ([987839e](https://github.com/nwarila-platform/aws-terraform-framework/commit/987839e46739f38b4e33fa15db9a2304db6fd6db))
* **ingress:** open WinRM over HTTP for the operator address ([#131](https://github.com/nwarila-platform/aws-terraform-framework/issues/131)) ([1abf5ae](https://github.com/nwarila-platform/aws-terraform-framework/commit/1abf5aee0b988f52c3472196a05d4e3793476eee))
* make every pattern uniform and every silent failure loud ([#129](https://github.com/nwarila-platform/aws-terraform-framework/issues/129)) ([330c95c](https://github.com/nwarila-platform/aws-terraform-framework/commit/330c95c5b722d24e91254578a64cff16af72082c))
* **tags:** publish the transport as a Connection tag ([#128](https://github.com/nwarila-platform/aws-terraform-framework/issues/128)) ([c301813](https://github.com/nwarila-platform/aws-terraform-framework/commit/c3018131c3a3abf2bd66d48ad9e15a77e010e13d))


### Bug Fixes

* **ingress:** attach the group an operator was promised, and say who each rule is for ([#124](https://github.com/nwarila-platform/aws-terraform-framework/issues/124)) ([546d80b](https://github.com/nwarila-platform/aws-terraform-framework/commit/546d80b1ea75d4a98870bbbb137e5ca329b33697))


### Code Refactoring

* **ebs:** record the shared_ebs_volumes shape change in the changelog ([#130](https://github.com/nwarila-platform/aws-terraform-framework/issues/130)) ([e05cbcf](https://github.com/nwarila-platform/aws-terraform-framework/commit/e05cbcf5e01fbae1bbddf6e66e5d2e247b8d4830))

## [3.1.2](https://github.com/nwarila-platform/aws-terraform-framework/compare/v3.1.1...v3.1.2) (2026-08-09)


### Bug Fixes

* **ec2:** make the EIP association wait for the instance to leave pending ([#120](https://github.com/nwarila-platform/aws-terraform-framework/issues/120)) ([c1ea7f3](https://github.com/nwarila-platform/aws-terraform-framework/commit/c1ea7f3b5c30c80c08eb28fda34327feff61f44e))

## [3.1.1](https://github.com/nwarila-platform/aws-terraform-framework/compare/v3.1.0...v3.1.1) (2026-08-09)


### Bug Fixes

* **ec2:** open inbound TCP 22 in the Windows SSH bootstrap ([#119](https://github.com/nwarila-platform/aws-terraform-framework/issues/119)) ([9bc479c](https://github.com/nwarila-platform/aws-terraform-framework/commit/9bc479c8f8ad779f4b8fa8f5d238208216921b09))
* stop silently discarding consumer tags on systems and databases ([#117](https://github.com/nwarila-platform/aws-terraform-framework/issues/117)) ([52ea43e](https://github.com/nwarila-platform/aws-terraform-framework/commit/52ea43edd91b8fb16704d4e0a255b9f8d49b445f))

## [3.1.0](https://github.com/nwarila-platform/aws-terraform-framework/compare/v3.0.0...v3.1.0) (2026-08-09)


### Features

* **ec2:** accept two vendor accounts for directly pinned images ([#111](https://github.com/nwarila-platform/aws-terraform-framework/issues/111)) ([027faa4](https://github.com/nwarila-platform/aws-terraform-framework/commit/027faa4cb67ce389c7059fe5266020e53570c8d4))
* **ec2:** name the transport channel, and skip runner ingress for tunnelled systems ([#113](https://github.com/nwarila-platform/aws-terraform-framework/issues/113)) ([1f280fa](https://github.com/nwarila-platform/aws-terraform-framework/commit/1f280fabdf0f52e0c85502b531079181f2d7b7ce))


### Bug Fixes

* **ec2:** bootstrap the SSM agent on Linux again, for vendor images ([#116](https://github.com/nwarila-platform/aws-terraform-framework/issues/116)) ([7643272](https://github.com/nwarila-platform/aws-terraform-framework/commit/764327228ae382a23e495ff0ce1f498e3c5a21fe))
* **ec2:** put identity tags in the launch request, not only on the resource ([#114](https://github.com/nwarila-platform/aws-terraform-framework/issues/114)) ([2e00722](https://github.com/nwarila-platform/aws-terraform-framework/commit/2e0072224606b8c93909a022ed7b22ae99d1bdbb))

## [3.0.0](https://github.com/nwarila-platform/aws-terraform-framework/compare/v2.2.0...v3.0.0) (2026-08-09)


### ⚠ BREAKING CHANGES

* **ec2:** address images through a version catalog instead of discovering them ([#110](https://github.com/nwarila-platform/aws-terraform-framework/issues/110))
* **variables:** flatten resource_metadata into individual deployment-identity variables ([#105](https://github.com/nwarila-platform/aws-terraform-framework/issues/105))

### Features

* **ec2:** address images through a version catalog instead of discovering them ([#110](https://github.com/nwarila-platform/aws-terraform-framework/issues/110)) ([c4a5316](https://github.com/nwarila-platform/aws-terraform-framework/commit/c4a5316752bca8a6701b21c01e510174bded4d2d))
* run-scoped runner ingress, WinRM transport selection, and audit remediation ([#107](https://github.com/nwarila-platform/aws-terraform-framework/issues/107)) ([34aa20a](https://github.com/nwarila-platform/aws-terraform-framework/commit/34aa20a2511675c996e78c7a1d5618d8234b8c84))
* **variables:** flatten resource_metadata into individual deployment-identity variables ([#105](https://github.com/nwarila-platform/aws-terraform-framework/issues/105)) ([15fe4a0](https://github.com/nwarila-platform/aws-terraform-framework/commit/15fe4a01065b00aca1a34de6b4827c235bd816c2))

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
