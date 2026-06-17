variable "vault_uuid" {
  description = "The OnePassword vault name containing infrastructure secrets."
  type        = string
  sensitive   = true
}

variable "change_triggers" {
  description = "List of values to trigger changes when they change. Used to trigger updates to secrets when underlying values change."
  type        = list(map(string))
  default     = []
}
