package terraform_plan

test_public_load_balancer_is_denied if {
	result := deny with input as {"resources": [{
		"address": "aws_lb.public",
		"type": "aws_lb",
		"values": {"internal": false},
	}]}
	"aws_lb.public must be internal; public load balancers are not allowed" in result
}

test_network_interface_without_security_groups_is_denied if {
	result := deny with input as {"resources": [
		{
			"address": "aws_network_interface.empty",
			"type": "aws_network_interface",
			"values": {"security_groups": []},
		},
		{
			"address": "aws_network_interface.null",
			"type": "aws_network_interface",
			"values": {"security_groups": null},
		},
		{
			"address": "aws_network_interface.missing",
			"type": "aws_network_interface",
			"values": {},
		},
	]}
	"aws_network_interface.empty must attach at least one security group (empty/omitted list uses the VPC default SG)" in result
	"aws_network_interface.null must attach at least one security group (empty/omitted list uses the VPC default SG)" in result
	"aws_network_interface.missing must attach at least one security group (empty/omitted list uses the VPC default SG)" in result
}

test_network_interface_with_security_groups_is_allowed if {
	result := deny with input as {"resources": [{
		"address": "aws_network_interface.attached",
		"type": "aws_network_interface",
		"values": {"security_groups": ["sg-123"]},
	}]}
	count(result) == 0
}

test_scoped_security_group_ingress_is_allowed if {
	result := deny with input as {"resources": [{
		"address": "aws_vpc_security_group_ingress_rule.scoped",
		"type": "aws_vpc_security_group_ingress_rule",
		"values": {"cidr_ipv4": "10.0.0.0/8"},
	}]}
	count(result) == 0
}

test_world_open_ipv4_security_group_ingress_is_denied if {
	result := deny with input as {"resources": [{
		"address": "aws_vpc_security_group_ingress_rule.world_ipv4",
		"type": "aws_vpc_security_group_ingress_rule",
		"values": {"cidr_ipv4": "0.0.0.0/0"},
	}]}
	"aws_vpc_security_group_ingress_rule.world_ipv4 must not allow world-open ingress" in result
}

test_world_open_ipv6_security_group_ingress_is_denied if {
	result := deny with input as {"resources": [{
		"address": "aws_vpc_security_group_ingress_rule.world_ipv6",
		"type": "aws_vpc_security_group_ingress_rule",
		"values": {"cidr_ipv6": "::/0"},
	}]}
	"aws_vpc_security_group_ingress_rule.world_ipv6 must not allow world-open ingress" in result
}

test_unencrypted_ebs_volume_is_denied if {
	result := deny with input as {"resources": [{
		"address": "aws_ebs_volume.unencrypted",
		"type": "aws_ebs_volume",
		"values": {"encrypted": false},
	}]}
	"aws_ebs_volume.unencrypted must enable encryption" in result
}

test_unencrypted_db_instance_is_denied if {
	result := deny with input as {"resources": [{
		"address": "aws_db_instance.unencrypted",
		"type": "aws_db_instance",
		"values": {"storage_encrypted": false},
	}]}
	"aws_db_instance.unencrypted must enable storage_encrypted" in result
}

test_public_db_instance_is_denied if {
	result := deny with input as {"resources": [{
		"address": "aws_db_instance.public",
		"type": "aws_db_instance",
		"values": {"storage_encrypted": true, "publicly_accessible": true},
	}]}
	"aws_db_instance.public must not be publicly_accessible" in result
}

test_private_db_instance_is_allowed if {
	result := deny with input as {"resources": [{
		"address": "aws_db_instance.private",
		"type": "aws_db_instance",
		"values": {"storage_encrypted": true, "publicly_accessible": false},
	}]}
	count(result) == 0
}

test_instance_without_required_imdsv2_is_denied if {
	result := deny with input as {"resources": [{
		"address": "aws_instance.optional_imds",
		"type": "aws_instance",
		"values": {"metadata_options": {"http_tokens": "optional"}, "root_block_device": {"encrypted": true}},
	}]}
	"aws_instance.optional_imds must enforce IMDSv2 (metadata_options.http_tokens = required)" in result
}

test_instance_without_metadata_options_is_denied if {
	result := deny with input as {"resources": [{
		"address": "aws_instance.missing_imds",
		"type": "aws_instance",
		"values": {"root_block_device": {"encrypted": true}},
	}]}
	"aws_instance.missing_imds must enforce IMDSv2 (metadata_options.http_tokens = required)" in result
}

test_instance_unencrypted_root_block_device_is_denied if {
	result := deny with input as {"resources": [{
		"address": "aws_instance.unencrypted_root",
		"type": "aws_instance",
		"values": {"metadata_options": {"http_tokens": "required"}, "root_block_device": {"encrypted": false}},
	}]}
	"aws_instance.unencrypted_root root_block_device must set encrypted = true" in result
}

test_instance_encrypted_root_block_device_is_allowed if {
	result := deny with input as {"resources": [{
		"address": "aws_instance.encrypted_root",
		"type": "aws_instance",
		"values": {"metadata_options": {"http_tokens": "required"}, "root_block_device": {"encrypted": true}},
	}]}
	count(result) == 0
}

test_instance_public_ip_association_is_denied if {
	result := deny with input as {"resources": [{
		"address": "aws_instance.public_ip",
		"type": "aws_instance",
		"values": {"metadata_options": {"http_tokens": "required"}, "root_block_device": {"encrypted": true}, "associate_public_ip_address": true},
	}]}
	"aws_instance.public_ip must not associate a public IP address" in result
}

test_instance_without_public_ip_association_is_allowed if {
	result := deny with input as {"resources": [{
		"address": "aws_instance.private_ip",
		"type": "aws_instance",
		"values": {"metadata_options": {"http_tokens": "required"}, "root_block_device": {"encrypted": true}, "associate_public_ip_address": false},
	}]}
	count(result) == 0
}

test_encrypted_internal_resources_are_allowed if {
	result := deny with input as {"resources": [
		{"address": "aws_lb.internal", "type": "aws_lb", "values": {"internal": true}},
		{"address": "aws_network_interface.attached", "type": "aws_network_interface", "values": {"security_groups": ["sg-123"]}},
		{"address": "aws_ebs_volume.encrypted", "type": "aws_ebs_volume", "values": {"encrypted": true}},
		{"address": "aws_db_instance.encrypted", "type": "aws_db_instance", "values": {"storage_encrypted": true, "publicly_accessible": false}},
		{"address": "aws_instance.imdsv2", "type": "aws_instance", "values": {"metadata_options": {"http_tokens": "required"}, "root_block_device": {"encrypted": true}, "associate_public_ip_address": false}},
	]}
	count(result) == 0
}

test_complete_identity_tags_are_allowed if {
	result := deny with input as {"resources": [{
		"address": "aws_ebs_volume.tagged",
		"type": "aws_ebs_volume",
		"values": {"encrypted": true, "tags": {
			"nwarila:management:managed-by": "terraform",
			"nwarila:management:repository": "nwarila-platform/aws-terraform-framework",
			"nwarila:management:repository-id": "123456789",
			"nwarila:management:stack": "wsus-poc-us-east-1",
			"nwarila:management:environment": "poc",
			"nwarila:operations:owner": "platform-engineering",
		}},
	}]}
	count(result) == 0
}

test_partial_identity_tags_are_denied if {
	result := deny with input as {"resources": [{
		"address": "aws_ebs_volume.half_tagged",
		"type": "aws_ebs_volume",
		"values": {"encrypted": true, "tags": {
			"nwarila:management:managed-by": "terraform",
			"nwarila:management:repository": "nwarila-platform/aws-terraform-framework",
		}},
	}]}
	count(result) == 1
}

test_partial_identity_tags_all_are_denied if {
	result := deny with input as {"resources": [{
		"address": "aws_ebs_volume.tags_all_half_tagged",
		"type": "aws_ebs_volume",
		"values": {
			"encrypted": true,
			"tags": {
				"nwarila:management:managed-by": "terraform",
				"nwarila:management:repository": "nwarila-platform/aws-terraform-framework",
				"nwarila:management:repository-id": "123456789",
				"nwarila:management:stack": "wsus-poc-us-east-1",
				"nwarila:management:environment": "poc",
				"nwarila:operations:owner": "platform-engineering",
			},
			"tags_all": {
				"nwarila:management:managed-by": "terraform",
				"nwarila:management:repository": "nwarila-platform/aws-terraform-framework",
			},
		},
	}]}
	count(result) == 1
}

test_partial_root_block_device_identity_tags_are_denied if {
	result := deny with input as {"resources": [{
		"address": "aws_instance.half_tagged_root",
		"type": "aws_instance",
		"values": {
			"associate_public_ip_address": false,
			"metadata_options": {"http_tokens": "required"},
			"root_block_device": {
				"encrypted": true,
				"tags": {
					"nwarila:management:managed-by": "terraform",
					"nwarila:management:repository": "nwarila-platform/aws-terraform-framework",
				},
			},
		},
	}]}
	count(result) == 1
}
