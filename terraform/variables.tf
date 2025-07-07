variable "protonmail_verification" {
  type        = string
  description = "Verification code for Protonmail"
}

variable "protonmail_dkim" {
  type        = string
  description = "Your Protonmail DKIM public key"
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

