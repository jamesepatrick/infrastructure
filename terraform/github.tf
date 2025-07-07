data "onepassword_item" "github" {
  vault = data.onepassword_vault.infrastructure.uuid
  title = "github"
}

locals {
  repo_section = [for section in data.onepassword_item.github.section : section if section.label == "repo"]
  repo_project = [for field in local.repo_section[0].field : field.value if field.label == "project"][0]
  repo_owner   = [for field in local.repo_section[0].field : field.value if field.label == "owner"][0]
}

provider "github" {
  token = data.onepassword_item.github.credential
  owner = local.repo_owner
}

resource "github_repository" "repository" {
  has_issues = false
  name       = local.repo_project
  visibility = "public"
}
