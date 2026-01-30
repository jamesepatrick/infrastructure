terraform {
  required_version = ">= 1.11.0"
  backend "s3" {
    bucket       = local.s3_backend_bucket_name
    key          = "state/terraform.tfstate"
    region       = local.s3_backend_region
    encrypt      = true
    use_lockfile = true
  }
}

locals {
  s3_backend_bucket_name = "jpatrick-terraform"
  s3_backend_region      = "us-west-1"
}

module "s3_backend" {
  source      = "./modules/s3_backend"
  region      = local.s3_backend_region
  bucket_name = local.s3_backend_bucket_name
}
