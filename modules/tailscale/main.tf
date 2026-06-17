terraform {
  required_version = ">= 1.11.0"
  required_providers {
    onepassword = {
      source  = "1password/onepassword"
      version = "3.3.1"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.28"
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

# This value will always replace. Due to the short lifespan of the auth keys, we will want to replace this every run.
# See DN 0001 for more details
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

# There is not a good way to de-auth device to prevent names collision.
# This is a workaround to delete the device with the same name as the one being created in this module.
# Require read/write for devices:core scope with prod tag for the oauth token.
# See DN 0004 for more details
resource "terraform_data" "tailscale_cleanup" {
  for_each = { for trigger in var.change_triggers : trigger.name => trigger.id }

  triggers_replace = {
    change_trigger = "${each.key}:${each.value}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOF
      TOKEN=$(curl -sS -d "client_id=$TS_CLIENT_ID" -d "client_secret=$TS_CLIENT_SECRET" "https://api.tailscale.com/api/v2/oauth/token" | jq -r '.access_token')
      IDS=$(curl -sS -H "Authorization: Bearer $TOKEN" "https://api.tailscale.com/api/v2/tailnet/-/devices" |  jq -r '.devices[] | select(.hostname == "${self.output.name}") | .id')
      echo "$IDS" | xargs -I {} curl -sS -X DELETE -H "Authorization: Bearer $TOKEN" "https://api.tailscale.com/api/v2/device/{}"
    EOF
    environment = {
      TS_CLIENT_ID     = self.output.client_id
      TS_CLIENT_SECRET = self.output.client_secret
    }
  }

  input = {
    name          = each.key
    id            = each.value
    client_id     = local.tailscale.client_id
    client_secret = local.tailscale.client_secret
  }
}
