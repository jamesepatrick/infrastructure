variable "vault_uuid" {
  description = "The OnePassword vault name containing infrastructure secrets."
  type        = string
  sensitive   = true
}

variable "ssh_authorized_keys" {
  description = "List of SSH public keys to authorize for the terraform user."
  type        = list(string)
}

variable "node0_tailscale_auth_key" {
  description = "Single use Tailscale auth key for node0."
  type        = string
  sensitive   = true
}
