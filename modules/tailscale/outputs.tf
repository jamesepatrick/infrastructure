output "auth_key" {
  description = "Tailscale ephemeral auth key for node registration."
  value       = tailscale_tailnet_key.node0.key
  sensitive   = true
}
