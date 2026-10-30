###############################################################################
# Backend bootstrap: the S3 bucket and DynamoDB table that every other stack
# (ec2/ in Chapter 08, eks/ in Chapter 10) stores its Terraform state in.
#
# This stack keeps its OWN state locally (backend/terraform.tfstate), because
# the bucket it creates doesn't exist yet when it runs: chicken-and-egg.
# Run it once, and keep it until you've finished Chapter 10.
###############################################################################

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
      Purpose   = "terraform-state"
    }
  }
}

# Read our own account ID without hardcoding it. Bucket names are global
# across ALL of AWS, so adding the account ID makes the name unique.
data "aws_caller_identity" "current" {}

# S3 bucket that holds one state file per stack per environment:
#   ec2/dev/terraform.tfstate, ec2/qa/terraform.tfstate, ec2/prod/...
#   eks/dev/terraform.tfstate, ... (Chapter 10)
resource "aws_s3_bucket" "tf_state" {
  bucket = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"

  # Versioning is on (below), so a plain destroy would fail with
  # BucketNotEmpty. force_destroy lets `terraform destroy` empty every version
  # first. Fine for a course account; don't copy this to a shared team bucket.
  force_destroy = true

  tags = {
    Name = "${var.project_name}-tfstate"
  }
}

# Keep every version of every state file, so a bad apply can be rolled back.
resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest: state files can contain secrets.
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access: state must never be readable from the internet.
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking. While one person runs apply, Terraform
# writes a row here; anyone else who tries at the same time is told to wait.
# PAY_PER_REQUEST costs fractions of a cent at course usage.
resource "aws_dynamodb_table" "tf_lock" {
  name         = "${var.project_name}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-terraform-locks"
  }
}
