variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region to build in. Must match the region in environments/<env>.tfbackend."
}

# ----------------------------------------------------------------------------
# Identity / naming
# ----------------------------------------------------------------------------

variable "project_name" {
  type        = string
  default     = "zero2ai"
  description = "Project name. Becomes part of every resource name and the Project tag."
}

variable "environment" {
  type        = string
  description = "Which environment this run builds. Set in environments/<env>.tfvars."

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment must be one of: dev, qa, prod."
  }
}

variable "owner" {
  type        = string
  default     = "T2S-Mentorship"
  description = "Who is responsible for these resources. Goes into the Owner tag."
}

# ----------------------------------------------------------------------------
# Networking
# ----------------------------------------------------------------------------

variable "vpc_cidr" {
  type        = string
  description = "IPv4 range for this environment's VPC. Use a different range per env so they never overlap."
}

variable "public_subnet_count" {
  type        = number
  default     = 2
  description = "Number of public subnets (one per Availability Zone)."
}

# ----------------------------------------------------------------------------
# AMI: chosen dynamically at plan time. Change these to switch operating
# system without touching any module code.
# ----------------------------------------------------------------------------

variable "ami_name_filter" {
  type        = string
  default     = "al2023-ami-2023.*-x86_64"
  description = <<-EOT
    Name pattern for the AMI lookup; the newest match is used. Examples:
      Amazon Linux 2023 (x86): al2023-ami-2023.*-x86_64
      Amazon Linux 2023 (ARM): al2023-ami-2023.*-arm64   (use a t4g.* instance_type)
      Ubuntu 24.04 LTS (x86):  ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*
  EOT
}

variable "ami_owners" {
  type        = list(string)
  default     = ["amazon"]
  description = "Who must own the AMI. \"amazon\" for Amazon Linux; \"099720109477\" (Canonical) for Ubuntu."
}

# ----------------------------------------------------------------------------
# Instances
# ----------------------------------------------------------------------------

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 size. t3.micro and t3.small are Free Tier eligible on new accounts."
}

variable "instance_count" {
  type        = number
  default     = 1
  description = "How many identical servers to run in this environment."
}

variable "root_volume_size_gb" {
  type        = number
  default     = 8
  description = "Root disk size per server, in GB."
}

# ----------------------------------------------------------------------------
# Access
# ----------------------------------------------------------------------------

variable "ssh_private_key_path" {
  type        = string
  description = <<-EOT
    Path to the private key (.pem) you created for this environment with ssh-keygen,
    e.g. "~/.ssh/zero2ai-ec2-dev.pem". The public key must sit next to it as <path>.pub.
    Terraform reads only the .pub file; the .pem never leaves your machine.
  EOT

  validation {
    condition     = fileexists(pathexpand(var.ssh_private_key_path)) && fileexists("${pathexpand(var.ssh_private_key_path)}.pub")
    error_message = "SSH key not found. Create it first (Part 4), e.g.: ssh-keygen -t rsa -b 4096 -m PEM -f ~/.ssh/zero2ai-ec2-dev.pem  (this also writes the .pem.pub file)."
  }
}
variable "allow_my_ip" {
  type        = bool
  default     = true
  description = "Look up this machine's public IP and allow SSH from it. Set false to use only allowed_ssh_cidrs."
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  default     = []
  description = "Extra IP addresses allowed to SSH in, as CIDRs like \"203.0.113.10/32\". Your own IP is added automatically when allow_my_ip is true."
}

variable "allowed_all_traffic_cidrs" {
  type        = list(string)
  default     = []
  description = <<-EOT
    CIDRs allowed to send ALL inbound traffic (every protocol and port) to the servers.
    Empty (the default) = no all-traffic rule. Use trusted ranges only, e.g. this
    environment's VPC range ("10.10.0.0/16") or one address ("203.0.113.10/32").
    Avoid "0.0.0.0/0": it opens every port to the whole internet.
  EOT
}
