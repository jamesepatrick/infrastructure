# Also see
# - ./cloud-init.tf
# - ../nix/tailscale.nix

data "onepassword_item" "tailscale" {
  vault = data.onepassword_vault.infrastructure.uuid
  title = "tailscale"
}

provider "tailscale" {
  tailnet = data.onepassword_item.tailscale.username
  api_key = data.onepassword_item.tailscale.credential
}

resource "tailscale_tailnet_key" "prod" {
  reusable      = true
  ephemeral     = true
  preauthorized = true
  tags          = ["tag:prod"]
}
