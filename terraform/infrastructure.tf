data "onepassword_item" "hcloud_token" {
  vault = data.onepassword_vault.infrastructure.uuid
  title = "hetzner"
}

provider "hcloud" {
  token = data.onepassword_item.hcloud_token.credential
}

resource "hcloud_floating_ip" "primary_ip" {
  type              = "ipv4"
  server_id         = hcloud_server.node.id
  delete_protection = true
}

resource "hcloud_firewall" "firewall" {
  name = "firewall"
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
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "${chomp(data.http.external_ip.response_body)}/32"
    ]
  }
}

resource "hcloud_server" "node" {
  name         = "node"
  image        = "ubuntu-22.04"
  datacenter   = "ash-dc1"
  server_type  = "cpx11"
  firewall_ids = [hcloud_firewall.firewall.id]
  user_data    = data.cloudinit_config.provision.rendered
}

resource "hcloud_volume" "data" {
  name              = "data"
  size              = 30 #size in GB. Min is 10
  server_id         = hcloud_server.node.id
  automount         = true
  format            = "ext4"
  delete_protection = true
}

output "node_ip" {
  value = hcloud_floating_ip.primary_ip.ip_address
}
