variable "vault_uuid" {
  description = "The OnePassword vault name containing infrastructure secrets."
  type        = string
  sensitive   = true
}

variable "ssh_authorized_keys" {
  description = "List of SSH public keys to authorize for the terraform user."
  type        = list(string)
}

variable "tailscale_auth_key" {
  description = "Tailscale shortlived auth key for joining the tailnet."
  type        = string
  sensitive   = true
}
