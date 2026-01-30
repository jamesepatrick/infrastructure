variable "region" {
  description = "The region where resources will be created."
  type        = string
}

variable "bucket_name" {
  description = "The name of the S3 bucket for Terraform state."
  type        = string
}
