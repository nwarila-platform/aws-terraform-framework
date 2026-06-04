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
