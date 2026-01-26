# Also see
# - ./cloud-init.tf
# - ../nix/tailscale.nix

provider "tailscale" {
  api_key = var.tailscale_token
  tailnet = var.tailscale_tailnet
}

resource "tailscale_tailnet_key" "prod" {
  reusable      = true
  ephemeral     = true
  preauthorized = true
  tags          = ["tag:prod"]
}
