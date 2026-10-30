output "state_bucket" {
  value       = aws_s3_bucket.tf_state.id
  description = "S3 bucket name. Passed to `terraform init` in every stack as -backend-config=\"bucket=...\"."
}

output "lock_table" {
  value       = aws_dynamodb_table.tf_lock.name
  description = "DynamoDB table name. Must match dynamodb_table in each environment's .tfbackend file."
}

output "region" {
  value       = var.aws_region
  description = "Region of the bucket and table."
}

output "account_id" {
  value       = data.aws_caller_identity.current.account_id
  description = "AWS account the backend was created in."
}
