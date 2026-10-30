###############################################################################
# EC2 stack: one root, three environments (dev, qa, prod).
#
# This file is intentionally thin. Every real resource lives in a module under
# ../modules/; the root just wires them together and sets the tags.
#
# The backend settings are NOT written here. They come from
# environments/<env>.tfbackend plus the bucket name at `terraform init` time,
# so the same code writes dev, qa and prod to separate state files:
#   s3://<bucket>/ec2/dev/terraform.tfstate
#   s3://<bucket>/ec2/qa/terraform.tfstate
#   s3://<bucket>/ec2/prod/terraform.tfstate
###############################################################################

terraform {
  required_version = ">= 1.5"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

# default_tags are added to every resource this stack creates, so the modules
# don't need to know about Environment or Owner at all.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Stack       = local.stack
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "terraform"
    }
  }
}

locals {
  # The stack name keeps this chapter's resources apart from Chapter 10's
  # eks stack when both run in the same account and environment.
  stack       = "ec2"
  name_prefix = "${var.project_name}-${local.stack}-${var.environment}"

  # The key pair you created with ssh-keygen. Terraform only ever reads the
  # PUBLIC half (.pub). The private .pem stays on your machine and never ends
  # up in the state file, the same way a real team handles production keys.
  ssh_private_key_path = pathexpand(var.ssh_private_key_path)
  ssh_public_key       = trimspace(file("${local.ssh_private_key_path}.pub"))

  # Your public IP as a /32 CIDR (only that one address), added to whatever is
  # listed in allowed_ssh_cidrs.
  my_ip_cidrs       = var.allow_my_ip ? ["${trimspace(data.http.my_ip[0].response_body)}/32"] : []
  allowed_ssh_cidrs = distinct(concat(var.allowed_ssh_cidrs, local.my_ip_cidrs))
}

# Look up the public IP of the machine running Terraform, so SSH is opened to
# you without editing a .tfvars file. It runs on every plan, so if your IP
# changes, the next apply updates the security group rule.
data "http" "my_ip" {
  count = var.allow_my_ip ? 1 : 0

  url = "https://checkip.amazonaws.com"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200 && can(cidrhost("${trimspace(self.response_body)}/32", 0))
      error_message = "Could not look up your public IP from checkip.amazonaws.com. Set allow_my_ip = false and list your IP in allowed_ssh_cidrs instead."
    }
  }
}

module "vpc" {
  source = "../modules/vpc"

  name_prefix         = local.name_prefix
  cidr_block          = var.vpc_cidr
  public_subnet_count = var.public_subnet_count
}

module "ec2" {
  source = "../modules/ec2"

  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.public_subnet_ids

  ami_name_filter = var.ami_name_filter
  ami_owners      = var.ami_owners

  instance_type       = var.instance_type
  instance_count      = var.instance_count
  root_volume_size_gb = var.root_volume_size_gb

  create_key_pair   = true
  public_key        = local.ssh_public_key
  allowed_ssh_cidrs = local.allowed_ssh_cidrs

  allowed_all_traffic_cidrs = var.allowed_all_traffic_cidrs
}
