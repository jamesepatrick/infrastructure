variable "protonmail_verification" {
  type        = string
  description = "Verification code for Protonmail"
}

variable "protonmail_dkim" {
  type        = string
  description = "Your Protonmail DKIM public key"
}

variable "github_token" {
  type        = string
  description = "Your Github OAuth token"
}

variable "github_owner" {
  type        = string
  description = "The owner of the Github repository"
}

variable "github_name" {
  type        = string
  description = "The name of the Github repository"
}

variable "hcloud_token" {
  sensitive   = true
  type        = string
  description = "API token to access Hetzner's Cloud resources."
}

variable "tailscale_token" {
  sensitive   = true
  type        = string
  description = "API token to access Hetzner's Cloud resources."
}

variable "tailscale_tailnet" {
  sensitive   = true
  type        = string
  description = "API token to access Hetzner's Cloud resources."
}

variable "miniflux_admin_user" {
  type        = string
  description = "miniflux admin username"
}

variable "miniflux_admin_pass" {
  sensitive   = true
  type        = string
  description = "miniflux admin passphrase"
}

variable "miniflux_db_user" {
  type        = string
  description = "miniflux postgres database username"
}

variable "miniflux_db_pass" {
  sensitive   = true
  type        = string
  description = "miniflux postgres database passphrase"
}

variable "porkbun_api_key" {
  type        = string
  sensitive   = true
  description = "api key for DNS provider Porkbun"
}

variable "porkbun_secret_key" {
  type        = string
  sensitive   = true
  description = "secret key to be used in parallel with porkbun_api_key for DNS provider Porkbun"
}
