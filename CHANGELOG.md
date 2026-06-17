# Changelog

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
