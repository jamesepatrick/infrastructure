terraform {
  required_version = ">= 1.11.0"
  required_providers {
    onepassword = {
      source  = "1password/onepassword"
      version = "3.3.1"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }
}


locals {
  zone_id     = resource.cloudflare_zone.jpatrick_io.id
  dns_section = data.onepassword_item.cloudflare.section_map["dns"]
  dns = {
    token      = local.dns_section.field_map["token"].value
    account_id = local.dns_section.field_map["account id"].value
  }
  protonmail_section = data.onepassword_item.protonmail.section_map[""]
  protonmail = {
    verification = local.protonmail_section.field_map["verification"].value
    dkim         = local.protonmail_section.field_map["dkim"].value
  }
}

provider "cloudflare" {
  api_token = local.dns.token
}

data "onepassword_item" "cloudflare" {
  vault = var.vault_uuid
  title = "cloudflare"
}

data "onepassword_item" "protonmail" {
  vault = var.vault_uuid
  title = "protonmail"
}

resource "cloudflare_zone" "jpatrick_io" {
  account = {
    id = local.dns.account_id
  }
  name = "jpatrick.io"
  type = "full"
}

resource "cloudflare_dns_record" "node0" {
  zone_id = local.zone_id
  comment = "legacy DO droplet record, will be removed after migration to Hetzner is complete"
  name    = "node0"
  content = "159.89.245.134"
  type    = "A"
  ttl     = 600
  proxied = false
}

resource "cloudflare_dns_record" "node1" {
  zone_id = local.zone_id
  comment = "Hetzer node1 record, will replace node0 after migration is complete"
  name    = "node1"
  content = var.node1_ip
  type    = "A"
  ttl     = 600
  proxied = false
}

resource "cloudflare_dns_record" "node1_services" {
  for_each = toset(["audiobooks", "traefik"])

  zone_id = local.zone_id
  name    = each.key
  content = "node1.${resource.cloudflare_zone.jpatrick_io.name}"
  type    = "CNAME"
  ttl     = 600
  proxied = false
}

resource "cloudflare_dns_record" "node0_services" {
  for_each = toset(["cloud", "git", "pops", "rss", "@"])

  zone_id = local.zone_id
  name    = each.key
  content = "node0.${resource.cloudflare_zone.jpatrick_io.name}"
  type    = "CNAME"
  ttl     = 600
  proxied = false
}

resource "cloudflare_dns_record" "mail" {
  zone_id  = local.zone_id
  name     = "@"
  content  = "mail.protonmail.ch"
  type     = "MX"
  priority = 10
  ttl      = 3600
}

resource "cloudflare_dns_record" "verification" {
  zone_id = local.zone_id
  name    = "@"
  content = "\"protonmail-verification=${local.protonmail.verification}\""
  type    = "TXT"
  ttl     = 1
}

resource "cloudflare_dns_record" "spf" {
  zone_id = local.zone_id
  name    = "@"
  content = "\"v=spf1 include:_spf.protonmail.ch mx ~all\""
  type    = "TXT"
  ttl     = 1
}

resource "cloudflare_dns_record" "dkim" {
  zone_id = local.zone_id
  name    = "protonmail._domainkey"
  content = "\"v=DKIM1; k=rsa; p=${local.protonmail.dkim}\""
  type    = "TXT"
  ttl     = 1
}
