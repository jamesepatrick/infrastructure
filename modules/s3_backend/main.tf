terraform {
  required_providers {
    aws = {
      source  = "opentofu/aws"
      version = "6.27.0"
    }
  }
}
resource "aws_s3_bucket" "terraform_state" {
  bucket = "jpatrick-terraform"
  lifecycle { prevent_destroy = true }
  tags = {
    Name        = "Terraform State"
    Environment = "Terraform"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    blocked_encryption_types = ["SSE-C"]
    bucket_key_enabled       = false

    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}
