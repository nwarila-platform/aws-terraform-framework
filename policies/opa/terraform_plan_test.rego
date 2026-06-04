package terraform_plan

test_public_load_balancer_is_denied if {
	result := deny with input as {"resources": [{
		"address": "aws_lb.public",
		"type": "aws_lb",
		"values": {"internal": false},
	}]}
	"aws_lb.public must be internal; public load balancers are not allowed" in result
}

test_encrypted_internal_resources_are_allowed if {
	result := deny with input as {"resources": [
		{"address": "aws_lb.internal", "type": "aws_lb", "values": {"internal": true}},
		{"address": "aws_ebs_volume.encrypted", "type": "aws_ebs_volume", "values": {"encrypted": true}},
		{"address": "aws_db_instance.encrypted", "type": "aws_db_instance", "values": {"storage_encrypted": true}},
	]}
	count(result) == 0
}
