variable "vault_uuid" {
  description = "The OnePassword vault name containing infrastructure secrets."
  type        = string
  sensitive   = true
}
