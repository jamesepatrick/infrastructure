
terraform {
  required_providers {
    onepassword = {
      source  = "1password/onepassword"
      version = "3.0.1"
    }
    aws = {
      source  = "opentofu/aws"
      version = "6.27.0"
    }
    github = {
      source  = "integrations/github"
      version = "6.9.0"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.58.0"
    }
  }
}

provider "onepassword" {
  # OP_SERVICE_ACCOUNT_TOKEN is set in the environment.
}

provider "aws" {
  region = "us-west-1"
}
