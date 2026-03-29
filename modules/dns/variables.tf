
variable "vault_uuid" {
  description = "The OnePassword vault name containing infrastructure secrets."
  type        = string
  sensitive   = true
}

variable "node1_ip" {
  description = "Ipv4 address of node1 VPS."
  type        = string

}
