terraform {
  required_providers {
    onepassword = {
      source  = "1password/onepassword"
      version = "3.0.1"
    }
    github = {
      source  = "integrations/github"
      version = "6.9.0"
    }
  }
}

data "onepassword_item" "github" {
  vault = var.vault_uuid
  title = "github"
}

locals {
  section_data = data.onepassword_item.github.section[index(data.onepassword_item.github.section[*].label, "repo")]
  repo_fields  = { for field in local.section_data.field : field.label => field.value }
}

provider "github" {
  token = data.onepassword_item.github.credential
  owner = local.repo_fields["owner"]
}

resource "github_repository" "infrastructure" {
  has_issues = false
  name       = local.repo_fields["project"]
  visibility = "public"
  lifecycle {
    prevent_destroy = true
  }
}

data "github_ssh_keys" "public_keys" {}
