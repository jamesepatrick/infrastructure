# Development Notes

This document details design decisions. The purpose of this document is to serve as a less structured ADR.

* New Development Notes should be append to this file.
* Each Development Note should be compact, but explain the issue, options considered, and eventual implementation.
* This is meant to be a living document. If a design decision is changed the associated development note should be updated as well.

## DN 0000 Template for Development Notes

**ID:** DN 0000
**Date:** 2026-06-10
**Updated:** 2026-06-11
**Status:** Revolved -

### Problem

Basically the same as ADR, but with a focus on brevity. Brevity & readability are king. AI tooling makes great use of more information, but it also costs more tokens.

### Options Considered

* ADR. Long.
* Unstructured notes. Harder to keep organized.
* No notes. Eh.
* Detailed Git Commits. Harder to discover.
* This. Seems like ADR by a different name.

### Implementation Solution

This. Only required part is the ID, Date, & Status. There is no required or default sections. A loose suggestion of including Problem, Options Considered, and Implementation Solution to the shape of the decision. But this should not be a default.

## DN 0001 Tailscale Auth Key Lifecycle

**ID:** DN 0001
**Date:** 2026-05-24
**Status:** Resolved — implemented 2026-06-10 (Option 2 - Hash-based selective ignore)

### Problem

`tailscale_tailnet_key` is consumed by `hcloud_server` via cloud-init. A circular dependency exists: replacing `hcloud_server` should trigger a new key, but the new key is an input to the server — OpenTofu cannot plan both replacements simultaneously.

The current trigger chain in state:

```
hcloud_server.node0.id
  → node0_change_trigger (output)
    → module.tailscale: node0_authkey_recreation_trigger (input)
      → replaces tailscale_tailnet_key.node0
        → auth_key (output)
          → module.hetzner: tailscale_auth_key (input)
            → rendered into cloud-init → hcloud_server.node0 (CYCLE)
```

### Options Considered

| Option | Summary                                                                  | Cycle-free | No manual steps | Notes                                                                                      |
|--------|--------------------------------------------------------------------------|------------|-----------------|--------------------------------------------------------------------------------------------|
| 1      | Taint tailscale auth key                                                 | Yes        | NO              |                                                                                            |
| 2      | Hash non-auth-key content. Ignore `user_data` & trigger on hash change   | Yes        | Yes             | **Implemented** — cleanest in-Tofu solution                                                |
| 3      | `reusable = true`, longer expiry in Tofu state                           | Yes        | Yes             | Massive security issue. Key reuse requires `reusable = true` & would be stored in tfstate. |
| 4      | Generate key in a pre-apply script; pass via `TF_VAR_tailscale_auth_key` | Yes        | Yes             | Good for CI/CD — aligns with future GitHub Actions goal. Step lives outside TF             |
| 5      | Node fetches OAuth creds from 1Password CLI at boot, self-registers      | Yes        | Yes             | All issues of #2. SSH is planned to be only be accessible via tailscale connection.        |
| 6      | Device approval workflow (no pre-auth key)                               | Yes        | No              | Requires manual approval in Tailscale console                                              |
| 7      | Store a long-lived key in 1Password, manage rotation out-of-band         | Yes        | Mostly          | Consistent with existing credential pattern; simplest near-term fix                        |
| 8      | `local-exec` provisioner generates key during `tofu apply`               | Yes        | Yes             | Fragile; couples apply to local machine environment                                        |

### Implemented Solution (Option 2)

Use `replace()` to normalize the auth key in the rendered cloud-init, then hash the normalized output.

**In `modules/hetzner/main.tf`:**

```hcl
locals {
  cloudinit_parts = [
    templatefile("${path.module}/cloud-init/setup.yaml.tftpl", {
      ssh_authorized_keys = var.ssh_authorized_keys
    }),
    templatefile("${path.module}/cloud-init/tailscale.yaml.tftpl", {
      tailscale_auth_key = var.node0-tailscale_auth_key
    }),
    templatefile("${path.module}/cloud-init/secrets.yaml.tftpl", {
    }),
  ]

  # Create a version of the cloud-init content with the auth key redacted for stable hashing
  # This allows us to always trigger a new auth key generation on each run, while only replacing the server when other content changes
  stablized_cloud_init = replace(data.cloudinit_config.node0.rendered, "/${var.node0-tailscale_auth_key}/", "[REDACTED]")
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

resource "terraform_data" "stablized_cloud_init_hash" {
  input = sha512(stablized_cloud_init)
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
    replace_triggered_by = [terraform_data.stablized_cloud_init_hash]
  }
}
```

**Behavior:**

* Auth key changes (`tskey-abc123` → `tskey-xyz789`): normalized hash stays the same → **server not recreated**
* SSH keys change: hash changes → **server recreated**
* Packages/secrets change: hash changes → **server recreated**
* Server type/location/image changes: **server recreated** (normal behavior)

**Advantages:**

* Solves the problem entirely within Tofu — no external scripts needed
* Keeps `module.tailscale` working as-is (continues to regenerate key on each apply)
* Server only recreates when non-auth-key content actually changes
* Easy to understand and maintain

**Trade-off:**

* Auth key is baked into `user_data`, but since cloud-init only runs once on first boot, the server won't actually reconfigure if the key changes (it's idempotent for our use case).
  * Using `cloud-init clean` on deployed server will result in attempting to re-auth with an invalid key.
* If machine is deauthed for Tailscale, the machine will need to be recreated.

## DN 0002 NixOS Anywhere Cross-Architecture Deployment

**ID:** DN 0002
**Date:** 2026-06-10
**Status:** Draft

### Problem

Deploying a `x86_64-linux` NixOS system from an `aarch64-darwin` (Apple Silicon) Mac using the `nixos-anywhere` all-in-one Terraform module fails with a platform mismatch error, even when `build_on_remote = true` is set.

### Root Cause

The all-in-one Terraform module has two separate stages. Stage 1 (local evaluation and build) always executes *locally* regardless of the `build_on_remote` flag — it invokes `nix build` to produce store paths for the system and disko partitioner derivations. The module fails here on `aarch64-darwin` when attempting to build `x86_64-linux` derivations natively. Only Stage 2 (remote installation) respects `build_on_remote`, but is never reached because Stage 1 fails first.

### Options


#### local-exec to nixos-anywhere

Use the `nixos-anywhere` CLI directly via a `null_resource` and `local-exec` provisioner with the `--build-on-remote` flag. This skips the pre-build stage entirely and delegates all Nix evaluation and building to the remote `x86_64-linux` host:

```hcl
resource "null_resource" "nixos_anywhere" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      nix run nixpkgs#nixos-anywhere -- \
        --build-on-remote \
        --flake "./nixos#node2" \
        --target-host "root@${var.target_host}" \
        --ssh-option "IdentityFile=$KEY_FILE" \
        --ssh-option "StrictHostKeyChecking=no"
    EOT

    environment = {
      DEPLOY_KEY      = data.onepassword_item.ssh.private_key
      AUTHORIZED_KEYS = join("\n", var.authorized_keys)
    }
  }
}
```

Using `nix run nixpkgs#nixos-anywhere` eliminates the need for manual CLI installation.

#### Wait for Issue to be resolved

See <https://github.com/nix-community/nixos-anywhere/issues/590>

#### Stay on NixOS-Infect

Activity seems pretty dead. Also slow & unstable for deploys.

#### Winner: Don't use NixOS

Use a more traditional distro. Setup with cloud-init for setup.
