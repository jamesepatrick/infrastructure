terraform {
  required_providers {
    onepassword = {
      source = "1password/onepassword"
    }
    tailscale = {
      source = "tailscale/tailscale"
    }
  }
}

data "onepassword_item" "tailscale" {
  vault = var.vault_uuid
  title = "tailscale"
}

locals {
  tailscale_section = data.onepassword_item.tailscale.section_map["oauth"]
  tailscale = {
    client_id     = local.tailscale_section.field_map["client_id"].value
    client_secret = local.tailscale_section.field_map["client_secret"].value
  }
}

provider "tailscale" {
  oauth_client_id     = local.tailscale.client_id
  oauth_client_secret = local.tailscale.client_secret
}

# This value should also be updated. Due to the short lifespan of the auth keys, we will want to replace this every run.
resource "terraform_data" "last_run_timestamp" {
  input = timestamp()
}

resource "tailscale_tailnet_key" "node0" {
  reusable      = false
  ephemeral     = true
  preauthorized = true
  expiry        = 6000
  tags          = ["tag:prod"]
  description   = "node0 cloud-init auth key"
  lifecycle {
    replace_triggered_by = [terraform_data.last_run_timestamp]
  }
}
