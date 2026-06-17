output "node_ipv4" {
  description = "The IPv4 address of the created node."
  value       = hcloud_floating_ip.primary_ip.ip_address
}

output "node0_trigger" {
  description = "A value that changes when the node0 server is changed or recreated."
  value       = { name = hcloud_server.node0.name, id = hcloud_server.node0.id }
}
