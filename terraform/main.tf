
terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "2.1.2"
    }
    porkbun = {
      source  = "cullenmcdermott/porkbun"
      version = ">= 0.3.0"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.44.1"
    }
    tailscale = {
      source = "tailscale/tailscale"
    }
  }
}
provider "onepassword" {
}

data "onepassword_vault" "infrastructure" {
  name = "infrastructure"
}
