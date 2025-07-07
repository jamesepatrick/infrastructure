data "onepassword_item" "miniflux" {
  vault = data.onepassword_vault.infrastructure.uuid
  title = "miniflux"
}

# Locals for extracting Miniflux credentials from the OnePassword item.
locals {
  section = {
    miniflux = {
      admin    = [for section in data.onepassword_item.miniflux.section : section if section.label == "admin"][0]
      database = [for section in data.onepassword_item.miniflux.section : section if section.label == "database"][0]
    }
  }
  miniflux = {
    admin = {
      user = [for field in local.section.miniflux.admin.field : field.value if field.label == "user"][0]
      pass = [for field in local.section.miniflux.admin.field : field.value if field.label == "password"][0]
    }
    database = {
      owner = [for field in local.section.miniflux.database.field : field.value if field.label == "owner"][0]
      pass  = [for field in local.section.miniflux.database.field : field.value if field.label == "password"][0]
    }
  }
}

# .env files
locals {
  miniflux_env = join("\n",
    [
      "ADMIN_USERNAME=${local.miniflux.admin.user}",
      "ADMIN_PASSWORD=${local.miniflux.admin.pass}",
      "DATABASE_URL=postgres://${local.miniflux.database.owner}:${local.miniflux.database.pass}@miniflux_db/miniflux?sslmode=disable",
      "POSTGRES_USER=${local.miniflux.database.owner}",
      "POSTGRES_PASSWORD=${local.miniflux.database.pass}",
  ])
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
