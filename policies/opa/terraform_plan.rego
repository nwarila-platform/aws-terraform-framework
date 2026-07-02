package terraform_plan

import rego.v1

encrypted_resource_types := {"aws_ebs_volume"}

deny contains msg if {
	resource := input.resources[_]
	resource.type == "aws_lb"
	object.get(resource.values, "internal", false) != true
	msg := sprintf("%s must be internal; public load balancers are not allowed", [resource.address])
}

deny contains msg if {
	resource := input.resources[_]
	resource.type == "aws_network_interface"
	not has_security_group(resource.values)
	msg := sprintf("%s must attach at least one security group (empty/omitted list uses the VPC default SG)", [resource.address])
}

deny contains msg if {
	resource := input.resources[_]
	encrypted_resource_types[resource.type]
	object.get(resource.values, "encrypted", false) != true
	msg := sprintf("%s must enable encryption", [resource.address])
}

deny contains msg if {
	resource := input.resources[_]
	resource.type == "aws_db_instance"
	object.get(resource.values, "storage_encrypted", false) != true
	msg := sprintf("%s must enable storage_encrypted", [resource.address])
}

deny contains msg if {
	resource := input.resources[_]
	resource.type == "aws_db_instance"
	object.get(resource.values, "publicly_accessible", false) == true
	msg := sprintf("%s must not be publicly_accessible", [resource.address])
}

deny contains msg if {
	resource := input.resources[_]
	resource.type == "aws_instance"
	metadata_options := object.get(resource.values, "metadata_options", {})
	object.get(metadata_options, "http_tokens", "optional") != "required"
	msg := sprintf("%s must enforce IMDSv2 (metadata_options.http_tokens = required)", [resource.address])
}

deny contains msg if {
	resource := input.resources[_]
	resource.type == "aws_instance"
	root_block_device := object.get(resource.values, "root_block_device", {})
	object.get(root_block_device, "encrypted", false) != true
	msg := sprintf("%s root_block_device must set encrypted = true", [resource.address])
}

deny contains msg if {
	resource := input.resources[_]
	resource.type == "aws_instance"
	object.get(resource.values, "associate_public_ip_address", false) == true
	msg := sprintf("%s must not associate a public IP address", [resource.address])
}

has_security_group(values) if {
	sgs := object.get(values, "security_groups", [])
	is_array(sgs)
	count(sgs) > 0
}
