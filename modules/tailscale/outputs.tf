output "auth_key_node0" {
  description = "Tailscale ephemeral auth key for node registration. This key is regenerated on each run and will only be valid for a short time, so it should be used immediately after terraform apply to join new nodes to the tailnet."
  value       = tailscale_tailnet_key.node0.key
  sensitive   = true
}
