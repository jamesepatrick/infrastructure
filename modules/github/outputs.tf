output "ssh_public_keys" {
  description = "The SSH public keys associated with the authenticated GitHub account."
  value       = data.github_user.current.ssh_keys
}
