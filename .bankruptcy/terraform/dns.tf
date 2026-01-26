# If you are connecting from a new IP you may need setup a new whitelist IP
# https://ap.www.namecheap.com/settings/tools/apiaccess/whitelisted-ips
data "http" "external_ip" {
  url = "http://ipv4.icanhazip.com"
}

provider "porkbun" {
  api_key    = var.porkbun_api_key
  secret_key = var.porkbun_secret_key
}

resource "porkbun_dns_record" "node0" {
  name    = "node0"
  domain  = "jpatrick.io"
  type    = "A"
  content = "159.89.245.134"
}

resource "porkbun_dns_record" "node" {
  name    = hcloud_server.node.name
  domain  = "jpatrick.io"
  type    = "A"
  content = hcloud_server.node.ipv4_address
}
resource "porkbun_dns_record" "audiobooks" {
  name    = "audiobooks"
  domain  = "jpatrick.io"
  type    = "CNAME"
  content = "node.jpatrick.io"
}

resource "porkbun_dns_record" "root" {
  name    = "@"
  domain  = "jpatrick.io"
  type    = "CNAME"
  content = "node0.jpatrick.io"
}

resource "porkbun_dns_record" "cloud" {
  name    = "cloud"
  domain  = "jpatrick.io"
  type    = "CNAME"
  content = "node0.jpatrick.io"
}
resource "porkbun_dns_record" "git" {
  name    = "git"
  domain  = "jpatrick.io"
  type    = "CNAME"
  content = "node0.jpatrick.io"
}
resource "porkbun_dns_record" "pops" {
  name    = "pops"
  domain  = "jpatrick.io"
  type    = "CNAME"
  content = "node0.jpatrick.io"
}
resource "porkbun_dns_record" "rss" {
  name    = "rss"
  domain  = "jpatrick.io"
  type    = "CNAME"
  content = "node0.jpatrick.io"
}
resource "porkbun_dns_record" "rss2" {
  name    = "rss2"
  domain  = "jpatrick.io"
  type    = "A"
  content = hcloud_server.node.ipv4_address
}
resource "porkbun_dns_record" "traefik" {
  name    = "traefik"
  domain  = "jpatrick.io"
  type    = "A"
  content = hcloud_server.node.ipv4_address
}

resource "porkbun_dns_record" "mail" {
  name    = "@"
  domain  = "jpatrick.io"
  type    = "MX"
  content = "mail.protonmail.ch."
}
resource "porkbun_dns_record" "mail_verification" {
  name    = "@"
  domain  = "jpatrick.io"
  type    = "TXT"
  content = "protonmail-verification=${var.protonmail_verification}"
}
resource "porkbun_dns_record" "spf" {
  name    = "@"
  domain  = "jpatrick.io"
  type    = "TXT"
  content = "v=spf1 include:_spf.protonmail.ch mx ~all"
}
resource "porkbun_dns_record" "dkim" {
  name    = "protonmail._domainkey"
  domain  = "jpatrick.io"
  type    = "TXT"
  content = "v=DKIM1; k=rsa; p=${var.protonmail_dkim}"
}

