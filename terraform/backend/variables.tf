variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Region the state bucket and lock table live in. Every stack's .tfbackend file must use the same region."
}

# If you change this, also change dynamodb_table in ../ec2/environments/*.tfbackend
# (it is "<project_name>-terraform-locks").
variable "project_name" {
  type        = string
  default     = "zero2ai"
  description = "Prefix for the bucket and lock table names. Keep it short and lowercase: bucket names cap at 63 characters."
}
