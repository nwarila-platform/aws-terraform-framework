package terraform_plan

test_public_load_balancer_is_denied if {
	result := deny with input as {"resources": [{
		"address": "aws_lb.public",
		"type": "aws_lb",
		"values": {"internal": false},
	}]}
	"aws_lb.public must be internal; public load balancers are not allowed" in result
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

test_instance_without_required_imdsv2_is_denied if {
	result := deny with input as {"resources": [{
		"address": "aws_instance.optional_imds",
		"type": "aws_instance",
		"values": {"metadata_options": {"http_tokens": "optional"}},
	}]}
	"aws_instance.optional_imds must enforce IMDSv2 (metadata_options.http_tokens = required)" in result
}

test_instance_without_metadata_options_is_denied if {
	result := deny with input as {"resources": [{
		"address": "aws_instance.missing_imds",
		"type": "aws_instance",
		"values": {},
	}]}
	"aws_instance.missing_imds must enforce IMDSv2 (metadata_options.http_tokens = required)" in result
}

test_encrypted_internal_resources_are_allowed if {
	result := deny with input as {"resources": [
		{"address": "aws_lb.internal", "type": "aws_lb", "values": {"internal": true}},
		{"address": "aws_ebs_volume.encrypted", "type": "aws_ebs_volume", "values": {"encrypted": true}},
		{"address": "aws_db_instance.encrypted", "type": "aws_db_instance", "values": {"storage_encrypted": true}},
		{"address": "aws_instance.imdsv2", "type": "aws_instance", "values": {"metadata_options": {"http_tokens": "required"}}},
	]}
	count(result) == 0
}
