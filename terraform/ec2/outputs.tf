output "environment" {
  value       = var.environment
  description = "Environment this state file represents."
}

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC the servers run in."
}

output "instance_ids" {
  value       = module.ec2.instance_ids
  description = "IDs of the servers."
}

output "server_ips" {
  value       = module.ec2.public_ips
  description = "Public IP address of each server."
}

output "ami_id" {
  value       = module.ec2.ami_id
  description = "AMI ID that the lookup selected."
}

output "ami_name" {
  value       = module.ec2.ami_name
  description = "Name of the AMI that the lookup selected."
}

output "ssh_private_key_path" {
  value       = local.ssh_private_key_path
  description = "Private key (.pem) on your machine that matches this environment's key pair."
}

output "ssh_allowed_cidrs" {
  value       = local.allowed_ssh_cidrs
  description = "Addresses the security group allows to SSH in."
}

output "ssh_commands" {
  value = [
    for ip in module.ec2.public_ips :
    "ssh -i ${local.ssh_private_key_path} ec2-user@${ip}"
  ]
  description = "Ready-to-paste SSH commands (Amazon Linux user is ec2-user; Ubuntu is ubuntu)."
}
