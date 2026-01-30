output "bucket_name" {
  description = "The name of the S3 bucket used for Terraform state storage."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "region" {
  description = "The AWS region where the S3 bucket is located."
  value       = aws_s3_bucket.terraform_state.region
}
