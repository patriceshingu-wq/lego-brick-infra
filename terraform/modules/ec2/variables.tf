variable "name_prefix" {
  type        = string
  description = "Prefix for instance, security group and key pair names. Usually <project>-<stack>-<env>."
}

variable "vpc_id" {
  type        = string
  description = "VPC the security group is created in."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets to launch into. Instances are spread across them round-robin."

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "subnet_ids must contain at least one subnet."
  }
}

# ----------------------------------------------------------------------------
# AMI lookup
# ----------------------------------------------------------------------------

variable "ami_name_filter" {
  type        = string
  description = "Name pattern passed to the aws_ami lookup. '*' is a wildcard; the newest match wins."
}

variable "ami_owners" {
  type        = list(string)
  description = "Account IDs or aliases allowed to own the AMI (e.g. [\"amazon\"]). Stops you picking up a look-alike image from a stranger."
}

# ----------------------------------------------------------------------------
# Instance sizing
# ----------------------------------------------------------------------------

variable "instance_type" {
  type        = string
  description = "EC2 size, e.g. t3.micro."
}

variable "instance_count" {
  type        = number
  default     = 1
  description = "How many identical instances to run."

  validation {
    condition     = var.instance_count >= 0 && var.instance_count <= 5
    error_message = "instance_count must be between 0 and 5 (course guardrail)."
  }
}

variable "root_volume_size_gb" {
  type        = number
  default     = 8
  description = "Root disk size in GB. 30 GB total is covered by the Free Tier."
}

variable "user_data" {
  type        = string
  default     = null
  description = "Optional startup script run on first boot."
}

# ----------------------------------------------------------------------------
# Access
# ----------------------------------------------------------------------------

variable "create_key_pair" {
  type        = bool
  default     = false
  description = "Register public_key with AWS and attach it to the instances. false = no key pair, no SSH login."
}

variable "public_key" {
  type        = string
  default     = ""
  description = "Contents of an SSH public key (ssh-ed25519 ... / ssh-rsa ...). Used when create_key_pair is true."
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  default     = []
  description = "CIDRs allowed to SSH in, e.g. [\"203.0.113.10/32\"]. Empty = SSH closed."
}

variable "allowed_all_traffic_cidrs" {
  type        = list(string)
  default     = []
  description = "CIDRs allowed to send ALL inbound traffic (every protocol and port), e.g. [\"10.10.0.0/16\"]. Empty = no all-traffic rule."

  validation {
    condition     = alltrue([for c in var.allowed_all_traffic_cidrs : can(cidrhost(c, 0))])
    error_message = "Each entry in allowed_all_traffic_cidrs must be a valid IPv4 CIDR, like \"10.10.0.0/16\" or \"203.0.113.10/32\"."
  }
}
