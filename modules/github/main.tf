provider "github" {
  token = var.github_token
  owner = var.github_owner
}

resource "github_repository" "repository" {
  has_issues = false
  name       = var.github_name
  visibility = "public"
  lifecycle {
    prevent_destroy = true
  }
}

data "github_ssh_keys" "public_keys" {}
