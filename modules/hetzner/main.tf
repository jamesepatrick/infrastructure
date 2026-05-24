terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
    onepassword = {
      source = "1password/onepassword"
    }
  }
}

data "onepassword_item" "hetzner" {
  vault = var.vault_uuid
  title = "hetzner"
}

provider "hcloud" {
  token = data.onepassword_item.hetzner.credential
}

resource "hcloud_floating_ip" "primary_ip" {
  type              = "ipv4"
  server_id         = hcloud_server.node0.id
  delete_protection = true
}

resource "hcloud_firewall" "firewall" {
  name = "node0"
  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}

resource "hcloud_server" "node0" {
  name        = "node0"
  image       = "centos-stream-10"
  location    = "nbg1"
  server_type = "cx23"
  firewall_ids = [hcloud_firewall.firewall.id]
}

resource "hcloud_volume" "node0" {
  name              = "node0"
  size              = 30 #size in GB. Min is 10
  server_id         = hcloud_server.node0.id
  automount         = true
  format            = "ext4"
  delete_protection = true
}
