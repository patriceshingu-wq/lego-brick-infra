output "instance_ids" {
  value       = aws_instance.this[*].id
  description = "IDs of the instances (they start with i-)."
}

output "public_ips" {
  value       = aws_instance.this[*].public_ip
  description = "Public IPv4 addresses of the instances."
}

output "security_group_id" {
  value       = aws_security_group.this.id
  description = "ID of the instances' security group."
}

output "ami_id" {
  value       = data.aws_ami.selected.id
  description = "AMI ID the lookup selected."
}

output "ami_name" {
  value       = data.aws_ami.selected.name
  description = "Full name of the selected AMI, so you can see exactly which image was picked."
}
