variable "name_prefix" {
  type        = string
  description = "Prefix for Name tags on the VPC, IGW, subnets and route table. Usually <project>-<stack>-<env>."
}

variable "cidr_block" {
  type        = string
  description = "Primary IPv4 CIDR for the VPC. /16 recommended; the module carves /24 public subnets out of it."

  validation {
    condition     = can(cidrnetmask(var.cidr_block))
    error_message = "cidr_block must be a valid IPv4 CIDR (e.g. 10.10.0.0/16)."
  }
}

variable "public_subnet_count" {
  type        = number
  default     = 2
  description = "Number of public subnets, each in a different AZ. EKS (Chapter 10) needs at least 2."

  validation {
    condition     = var.public_subnet_count >= 1 && var.public_subnet_count <= 6
    error_message = "public_subnet_count must be between 1 and 6."
  }
}

variable "subnet_tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags added to every public subnet (e.g. Kubernetes discovery tags in Chapter 10)."
}
