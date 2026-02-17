output "node_ipv4" {
  description = "The IPv4 address of the created node."
  value       = hcloud_floating_ip.primary_ip.ip_address
}
