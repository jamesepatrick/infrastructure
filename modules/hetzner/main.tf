terraform {
  required_version = ">= 1.11.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.58.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "2.4.0"
    }
    onepassword = {
      source  = "1password/onepassword"
      version = "3.3.1"
    }
  }
}

data "onepassword_item" "hetzner" {
  vault = var.vault_uuid
  title = "hetzner"
}

data "onepassword_item" "node0_service_account" {
  vault = var.vault_uuid
  title = "node0 service account"
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


locals {
  node0_secret_mappings = [
    { op_ref = "foo" },
    # Example secret mappings - add your secrets here
    # {
    #   op_ref        = "op://node0/database/password"
    #   docker_secret = "db_password"
    # },
    # {
    #   op_ref        = "op://node0/api/token"
    #   docker_secret = "api_token"
    # },
  ]
}

locals {
  cloudinit_parts = [
    templatefile("${path.module}/cloud-init/setup.yaml.tftpl", {
      ssh_authorized_keys = var.ssh_authorized_keys
    }),
    templatefile("${path.module}/cloud-init/tailscale.yaml.tftpl", {
      tailscale_auth_key = var.node0_tailscale_auth_key
    }),
    templatefile("${path.module}/cloud-init/secrets.yaml.tftpl", {
      op_service_account_token = data.onepassword_item.node0_service_account.credential
      secret_mappings_yaml     = yamlencode({ secrets = local.node0_secret_mappings })
    }),
    templatefile("${path.module}/cloud-init/containers.yaml.tftpl", {
    }),
  ]

}

data "cloudinit_config" "node0" {
  gzip          = false
  base64_encode = false

  dynamic "part" {
    for_each = local.cloudinit_parts
    content {
      content_type = "text/cloud-config"
      content      = part.value
      merge_type   = "list(append)+dict(recurse_list)+str(append)"
    }
  }
}

resource "terraform_data" "modification_trigger" {
  input = {
    cloudinit_folder_hash = sha512(join("", [
      for f in fileset("${path.module}/cloud-init", "*.tftpl") : file("${path.module}/cloud-init/${f}")
    ]))
    ssh_authorized_keys      = var.ssh_authorized_keys
    op_service_account_token = data.onepassword_item.node0_service_account.credential
    secret_mappings_yaml     = yamlencode({ secrets = local.node0_secret_mappings })
  }
}

resource "hcloud_server" "node0" {
  name         = "node0"
  image        = "centos-stream-10"
  location     = "nbg1"
  server_type  = "cx23"
  user_data    = data.cloudinit_config.node0.rendered
  firewall_ids = [hcloud_firewall.firewall.id]

  # Since the tailscale key is always regenerated, we want to ignore changes to the user_data that are solely due to the auth key changing.
  lifecycle {
    ignore_changes       = [user_data]
    replace_triggered_by = [terraform_data.modification_trigger]
  }
}

resource "hcloud_volume" "node0" {
  name              = "node0"
  size              = 30 #size in GB. Min is 10
  server_id         = hcloud_server.node0.id
  automount         = true
  format            = "ext4"
  delete_protection = true
}
