output "ssh_public_keys" {
  description = "The SSH public keys fetched from GitHub."
  value       = data.github_ssh_keys.public_keys.keys
}
