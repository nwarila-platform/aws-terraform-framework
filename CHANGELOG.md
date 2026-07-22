# Changelog

## [0.3.0](https://github.com/nwarila-platform/aws-terraform-framework/compare/v0.2.0...v0.3.0) (2026-07-22)


### ⚠ BREAKING CHANGES

* v1.0 platform overhaul - single-region SSH-only framework, packer-compatible surfaces, hardcode-first doctrine ([#85](https://github.com/nwarila-platform/aws-terraform-framework/issues/85))

### Features

* v1.0 platform overhaul - single-region SSH-only framework, packer-compatible surfaces, hardcode-first doctrine ([#85](https://github.com/nwarila-platform/aws-terraform-framework/issues/85)) ([1066356](https://github.com/nwarila-platform/aws-terraform-framework/commit/10663560e0d2ec5cd2f4f37a552928575f6ed4dd))

## [0.2.0](https://github.com/nwarila-platform/aws-terraform-framework/compare/v0.1.0...v0.2.0) (2026-07-01)


### ⚠ BREAKING CHANGES

* the red_hat_enterprise_linux_8 alias is removed (default ami is now ttc-rhel8); self-built resolution expects AMI Names shaped <family>_v<version>_<build>, so previously-resolved RHEL instances may re-resolve and replace.
* Windows user_data change forces Windows instance replacement; the readiness gate now needs inbound TCP 5986 (not 5985) from the Terraform apply host.
* get_password_data removed from all_systems input; Windows user_data change forces Windows instance replacement.
* deployments must own matching RHEL AMIs in-account; the resolved RHEL AMI may change, which can replace existing RHEL EC2 instances on apply.
* the Windows user_data changes (DefaultShell step removed), forcing replacement of existing Windows EC2 instances on apply.
* `terraform apply` now runs an SSH readiness gate that requires ssh_readiness_private_key_paths to be populated (key_name => private key path) and SSH reachability from the apply host; pipelines must set it. The Windows user_data also changes (restart removed), forcing replacement of existing Windows EC2 instances on apply.
* the Windows user_data bytes change, forcing replacement of existing Windows EC2 instances on apply (user_data_replace_on_change = true).
* changes which Windows AMI resolves (public base vs custom golden image) and expands the Windows user_data, forcing replacement of existing Windows instances. OpenSSH capability install pulls from Windows Update at first boot, so Windows instances need egress on first boot (air-gapped subnets need a pre-baked image).
* removes the required all_systems.ansible_group input and the transport/ansible_* fields and Ansible* tags from the aws_instances output; Ansible now derives connection/grouping itself from the neutral facts and generic tags.
* EC2 user_data changes from SSM-agent-ensure to SSH-readiness, which forces replacement of existing instances; the aws_instances output facts (transport, ansible_connection, ansible_host, plus the new ansible_user) change shape.

### Features

* direct-AMI lookup + platform-based OS classification ([#68](https://github.com/nwarila-platform/aws-terraform-framework/issues/68)) ([07520ce](https://github.com/nwarila-platform/aws-terraform-framework/commit/07520ce30a97b72df347fb74340a5a8b1d8c96a9))
* flip EC2 management transport from SSM to SSH ([1a80b79](https://github.com/nwarila-platform/aws-terraform-framework/commit/1a80b79a93b63398186f234e1ba19aad7044d77d))
* gate terraform apply on SSH readiness via native remote-exec ([525889d](https://github.com/nwarila-platform/aws-terraform-framework/commit/525889df9027610f2077ef62fec2619f3c13bb9f))
* harden Windows OpenSSH user_data and extract user_data into named locals ([8491fd7](https://github.com/nwarila-platform/aws-terraform-framework/commit/8491fd7ade9e44c4bbdf7337467974405b5ef4d2))
* make EC2 inventory orchestrator-neutral ([7694680](https://github.com/nwarila-platform/aws-terraform-framework/commit/7694680994825cf2d6499653394032a68ede1464))
* name-based AMI version resolution (family / family:version / ami-id) + OS via platform ([#73](https://github.com/nwarila-platform/aws-terraform-framework/issues/73)) ([5eccbbf](https://github.com/nwarila-platform/aws-terraform-framework/commit/5eccbbfcca4ef6ccb5c5f82452b76c804dc300a7))
* source RHEL AMIs from self-owned account ([cd1c5cf](https://github.com/nwarila-platform/aws-terraform-framework/commit/cd1c5cff4323af20177bb823e5d1bb4d05783b1d))
* use public Windows base AMI and install OpenSSH via user_data ([53e4c9e](https://github.com/nwarila-platform/aws-terraform-framework/commit/53e4c9e2294d8bbddf9c578f1eb5661b78b30ed8))
* WinRM readiness shim for Windows (offline-safe) ([#67](https://github.com/nwarila-platform/aws-terraform-framework/issues/67)) ([f3f1890](https://github.com/nwarila-platform/aws-terraform-framework/commit/f3f1890b6cda542207fc2f2008c11eb59dbe5930))


### Bug Fixes

* repair the Windows SSH readiness gate (cmd default shell + full EC2Launch path) ([0692548](https://github.com/nwarila-platform/aws-terraform-framework/commit/069254841e833977c521257ebfdaffdb3def74d7))
* upload the Linux readiness script to a configurable exec dir ([#69](https://github.com/nwarila-platform/aws-terraform-framework/issues/69)) ([052afc8](https://github.com/nwarila-platform/aws-terraform-framework/commit/052afc8e5b303a0d66de77af33ff497473b2d26d))
* WinRM readiness over HTTPS/5986 (NTLM/HTTP-5985 could not authenticate) ([#71](https://github.com/nwarila-platform/aws-terraform-framework/issues/71)) ([998e1ba](https://github.com/nwarila-platform/aws-terraform-framework/commit/998e1ba8b937ea06bafe8b5ec2d13912144422e2))

## 0.1.0 (2026-06-17)


### Features

* add Ansible-discovery tags + required ansible_group ([#56](https://github.com/nwarila-platform/aws-terraform-framework/issues/56)) ([f881887](https://github.com/nwarila-platform/aws-terraform-framework/commit/f881887ad2fa8b4eafa0dfd55d0182eee7720c37))
* add aws_instances inventory output ([#54](https://github.com/nwarila-platform/aws-terraform-framework/issues/54)) ([f0cb022](https://github.com/nwarila-platform/aws-terraform-framework/commit/f0cb02251f656927293dd3f00068bccaf2390df2))
* add IMDSv2 OPA gate and RDS managed master password ([#48](https://github.com/nwarila-platform/aws-terraform-framework/issues/48)) ([ab88291](https://github.com/nwarila-platform/aws-terraform-framework/commit/ab88291a4a948022bfe069f50e04141f1ff063b0))
* add load balancer listeners, rules, and certificates ([#40](https://github.com/nwarila-platform/aws-terraform-framework/issues/40)) ([77d8f5f](https://github.com/nwarila-platform/aws-terraform-framework/commit/77d8f5f1cb838785618bd4c2c2806f6aa430ff8c))
* add load balancer outputs and worked example ([#41](https://github.com/nwarila-platform/aws-terraform-framework/issues/41)) ([f739f59](https://github.com/nwarila-platform/aws-terraform-framework/commit/f739f598b1bad991e1638ddc7f0be332243d4793))
* add load balancer routing schema ([#38](https://github.com/nwarila-platform/aws-terraform-framework/issues/38)) ([4d6540d](https://github.com/nwarila-platform/aws-terraform-framework/commit/4d6540d7f576d1cb7b7a057c6034f5acb27bd760))
* add load balancer target groups ([#39](https://github.com/nwarila-platform/aws-terraform-framework/issues/39)) ([0c13bb1](https://github.com/nwarila-platform/aws-terraform-framework/commit/0c13bb11032fca03b403688e2447bd20dfe310f6))
* add reusable IaC security scan caller ([#6](https://github.com/nwarila-platform/aws-terraform-framework/issues/6)) ([f48903f](https://github.com/nwarila-platform/aws-terraform-framework/commit/f48903f43241a3a096580aa2d8c72f5dcfd08a17))
* add windows_server_2025_base AMI support ([#52](https://github.com/nwarila-platform/aws-terraform-framework/issues/52)) ([f832c96](https://github.com/nwarila-platform/aws-terraform-framework/commit/f832c96f81dbfb7f0b4f78cf411de4897d01267c))
* **ci:** adopt pr-validation (contract-and-lint mode) ([#17](https://github.com/nwarila-platform/aws-terraform-framework/issues/17)) ([a5dfdac](https://github.com/nwarila-platform/aws-terraform-framework/commit/a5dfdac5308665a9022d02f031944394fc10f026))
* **ci:** graduate to mode: full validation ([#21](https://github.com/nwarila-platform/aws-terraform-framework/issues/21)) ([f594872](https://github.com/nwarila-platform/aws-terraform-framework/commit/f5948723ddcbd2f580c68ee1f4f24c3d9d4d6b9c))
* **ci:** lint_advisory + bump to 1c92039 + prep renovate.json5 ([#18](https://github.com/nwarila-platform/aws-terraform-framework/issues/18)) ([750d129](https://github.com/nwarila-platform/aws-terraform-framework/commit/750d129bcf0903d933e7c5baecdb3408ea1a97d7))
* complete contract scaffold + .gitignore allowlist ([#20](https://github.com/nwarila-platform/aws-terraform-framework/issues/20)) ([0f98542](https://github.com/nwarila-platform/aws-terraform-framework/commit/0f98542bb7e95ec98da924c323c006adc2fb8a79))
* consume reusable CodeQL workflow ([#15](https://github.com/nwarila-platform/aws-terraform-framework/issues/15)) ([faf6bc5](https://github.com/nwarila-platform/aws-terraform-framework/commit/faf6bc528e3da72dc869c1f64c9aafe6be6f6a58))
* contract scaffold + pin bump to ecb7a74 ([#11](https://github.com/nwarila-platform/aws-terraform-framework/issues/11)) ([372f3cd](https://github.com/nwarila-platform/aws-terraform-framework/commit/372f3cd74fe47686863a6945af25d49c2a196913))
* expand aws_instances to full Ansible target facts ([#57](https://github.com/nwarila-platform/aws-terraform-framework/issues/57)) ([40bd180](https://github.com/nwarila-platform/aws-terraform-framework/commit/40bd180a6851ccf7fcd3b2d97e25e069dd57d0a6))
* onboard NWarila/terraform-template@aeb3d18 (sync only) ([#1](https://github.com/nwarila-platform/aws-terraform-framework/issues/1)) ([b703f75](https://github.com/nwarila-platform/aws-terraform-framework/commit/b703f75c252d249deaed66979b11785d42770169))
* require consumer-supplied iam_instance_profile on all_systems ([#50](https://github.com/nwarila-platform/aws-terraform-framework/issues/50)) ([a0943cd](https://github.com/nwarila-platform/aws-terraform-framework/commit/a0943cd2ea96c75fb229eec70aa027cc7d88b849))
* **security:** adopt OpenSSF Scorecard + bump pin to 9d354ff ([#27](https://github.com/nwarila-platform/aws-terraform-framework/issues/27)) ([04eb0c5](https://github.com/nwarila-platform/aws-terraform-framework/commit/04eb0c5675371dd5b9166b25ab8130ecf295ba21))
* user_data ensures the SSM Agent service is started ([#53](https://github.com/nwarila-platform/aws-terraform-framework/issues/53)) ([dbfa9bd](https://github.com/nwarila-platform/aws-terraform-framework/commit/dbfa9bd8b046a487b5391fb85b2ade75a38c1285))
* validate Windows hostnames are NetBIOS-safe (&lt;=15 chars) ([#51](https://github.com/nwarila-platform/aws-terraform-framework/issues/51)) ([c25fddb](https://github.com/nwarila-platform/aws-terraform-framework/commit/c25fddb319871d292c6d2f9d9ddc3fa888bcd2a6))


### Bug Fixes

* **ci:** drop forbidden *_advisory inputs on security caller ([#30](https://github.com/nwarila-platform/aws-terraform-framework/issues/30)) ([c97b368](https://github.com/nwarila-platform/aws-terraform-framework/commit/c97b3681f4373782186a23e78a3f18f152b7dfd9))
* enforce IMDSv2 and default get_password_data to false ([#42](https://github.com/nwarila-platform/aws-terraform-framework/issues/42)) ([5aca4c1](https://github.com/nwarila-platform/aws-terraform-framework/commit/5aca4c18a416a909737080743606f3b14595f599))
* harden encryption at resource layer and tooling cleanup ([#47](https://github.com/nwarila-platform/aws-terraform-framework/issues/47)) ([155bff5](https://github.com/nwarila-platform/aws-terraform-framework/commit/155bff5be6dc6eae8e8b385dfb942dafe7bf08ba))
* harden input validation parity and contracts ([#43](https://github.com/nwarila-platform/aws-terraform-framework/issues/43)) ([18460ef](https://github.com/nwarila-platform/aws-terraform-framework/commit/18460ef6dca30532f51a9c67a53bbcb3616efc37))
* mark all_databases credentials sensitive ([#44](https://github.com/nwarila-platform/aws-terraform-framework/issues/44)) ([0f8dabe](https://github.com/nwarila-platform/aws-terraform-framework/commit/0f8dabe2189103366d3584bbf8614df9ba63e199))
* restore terraform consumer CI ([#31](https://github.com/nwarila-platform/aws-terraform-framework/issues/31)) ([fe164b4](https://github.com/nwarila-platform/aws-terraform-framework/commit/fe164b47d582674234bbcf72e41192db19d691eb))
* sanitize public-facing identifiers ([#46](https://github.com/nwarila-platform/aws-terraform-framework/issues/46)) ([cf8e11a](https://github.com/nwarila-platform/aws-terraform-framework/commit/cf8e11ae1f94678dfb315b5e5b20f32d4d944fc8))
* **workflows:** restore corrupted template_ref key ([#13](https://github.com/nwarila-platform/aws-terraform-framework/issues/13)) ([83aa920](https://github.com/nwarila-platform/aws-terraform-framework/commit/83aa9203e859efa0aee809fc56968af90e9d149d))

## Changelog

Generated by release-please. Do not edit by hand.
