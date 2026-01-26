provider "hcloud" {
  token = var.hcloud_token
}

locals {
  miniflux_env = join("\n",
    [
      "ADMIN_USERNAME=${var.miniflux_admin_user}",
      "ADMIN_PASSWORD=${var.miniflux_admin_pass}",
      "DATABASE_URL=postgres://${var.miniflux_db_user}:${var.miniflux_db_pass}@miniflux_db/miniflux?sslmode=disable",
      "POSTGRES_USER=${var.miniflux_db_user}",
      "POSTGRES_PASSWORD=${var.miniflux_db_pass}",
  ])
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
  image        = "ubuntu-24.04"
  datacenter   = "ash-dc1"
  server_type  = "cpx11"
  backups      = false
  firewall_ids = [hcloud_firewall.firewall.id]
  user_data    = data.cloudinit_config.provision.rendered
  ssh_keys     = data.github_ssh_keys.public_keys.keys
}

resource "hcloud_volume" "data" {
  name              = "data"
  size              = 30 #size in GB. Min is 10
  server_id         = hcloud_server.node.id
  automount         = true
  format            = "ext4"
  delete_protection = true
}


data "archive_file" "docker-files" {
  type        = "zip"
  source_dir  = "${path.module}/../docker"
  output_path = "${path.module}/../tmp/docker.zip"
}

data "cloudinit_config" "provision" {
  gzip          = false
  base64_encode = false
  part {
    content_type = "text/cloud-config"
    content      = templatefile("${path.module}/../cloud-init/setup.cfg.tftpl", {})
    merge_type   = "list(append)+dict(recurse_list)+str(append)"
  }
  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/../cloud-init/docker.cfg.tftpl",
      {
        docker_zip   = filebase64(data.archive_file.docker-files.output_path)
        docker_nix   = file("${path.module}/../nix/docker.nix")
        miniflux_env = local.miniflux_env
      }
    )
    merge_type = "list(append)+dict(recurse_list)+str(append)"
  }
  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/../cloud-init/infect.cfg.tftpl",
      {
        host_nix              = file("${path.module}/../nix/host.nix")
        tailscale_nix         = file("${path.module}/../nix/tailscale.nix")
        tailscale_tailnet_key = tailscale_tailnet_key.prod.key
      }
    )
    merge_type = "list(append)+dict(recurse_list)+str(append)"
  }
}

output "node_ip" {
  value = hcloud_floating_ip.primary_ip.ip_address
}
