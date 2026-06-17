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

**Related:** See **DN 0004** for the device cleanup mechanism required when reusing hostnames across server recreations — Tailscale's device model requires stale devices to be removed before a new server can register with the same hostname.

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

## DN 0003 Ephemeral Resources with 1Password in OpenTofu

**ID:** DN 0003
**Date:** 2026-06-11
**Status:** Blocked - awaiting upstream provider support
**Blocked By:**

* <https://github.com/1Password/terraform-provider-onepassword/issues/330>
* <https://github.com/1Password/terraform-provider-onepassword/pull/367>

### Problem

OpenTofu stores all resource and data source attributes in state files. Using `data "onepassword_item"` resources exposes credentials in `terraform.tfstate`, creating a security risk even with encrypted S3 backend storage. State files may be accessed by CI/CD systems, backed up, cached locally, or accidentally exposed.

### Solution

OpenTofu 1.11.0 introduced `ephemeral` resources - resources whose values exist only in memory during plan/apply and are never persisted to state. The 1Password provider v3.3.1+ supports `ephemeral "onepassword_item"`, enabling secret retrieval from 1Password vaults without storing credentials in state.

### Implementation Pattern

Basic credential extraction:

```hcl
ephemeral "onepassword_item" "service" {
  vault = var.vault_uuid
  title = "service-name"
}

provider "example_provider" {
  token = ephemeral.onepassword_item.service.credential
}
```

**Requirements:**

* OpenTofu >= 1.11.0
* 1Password provider >= 3.3.1
* `OP_SERVICE_ACCOUNT_TOKEN` environment variable (set via `source .env.sh`)
* `vault_uuid` threaded from root as sensitive variable

### Benefits

* **Zero secrets in state**: Credentials never written to `terraform.tfstate`
* **No `.tfvars` files**: Eliminates need for gitignored credential files
* **Centralized secret management**: Single source of truth in 1Password infrastructure vault
* **Audit trail**: 1Password service account tracks all secret access

### Current Blocker

**Ephemeral `onepassword_item` resources lack section support.** The ephemeral schema is missing critical attributes available in the `data` source:

* `section` (array of section objects)
* `section_map` (map of section name → section object with `field_map`)

This prevents accessing structured secrets organized in 1Password sections, which is how most multi-credential services are stored.

**Example error:**

```
Error: Unsupported attribute
  on modules/dns/main.tf line 18
  dns_section = ephemeral.onepassword_item.cloudflare.section_map["dns"]

This object has no argument, nested block, or exported attribute named "section_map".
```

### Workarounds Considered

#### Option 1: Restructure to username/password fields

* Store all credentials in top-level `username`/`password` fields only
* **Rejected**: Misaligns with 1Password's organizational model. Most services require multiple credentials (client_id, client_secret, account_id, tokens, verification codes) naturally organized in sections.

#### Option 2: Wait for upstream fix (current approach)

* Block migration until PR #367 is merged and released
* Re-implement section-based access once provider supports it

### Migration Impact

Once unblocked, this pattern will replace all `data "onepassword_item"` declarations across:

* **modules/github** - GitHub token and repository metadata (section: "repo")
* **modules/hetzner** - Hetzner Cloud API token
* **modules/dns** - Cloudflare credentials (section: "dns") and ProtonMail verification records
* **modules/tailscale** - OAuth client credentials (section: "oauth")

All modules instantiate their own providers using credentials fetched directly from 1Password (non-standard but intentional per repository pattern).

### Future Implementation

Once `section_map` is available in ephemeral resources:

```hcl
ephemeral "onepassword_item" "tailscale" {
  vault = var.vault_uuid
  title = "tailscale"
}

locals {
  tailscale_section = ephemeral.onepassword_item.tailscale.section_map["oauth"]
  tailscale = {
    client_id     = local.tailscale_section.field_map["client_id"].value
    client_secret = local.tailscale_section.field_map["client_secret"].value
  }
}

provider "tailscale" {
  oauth_client_id     = local.tailscale.client_id
  oauth_client_secret = local.tailscale.client_secret
}
```

## DN 0004 Tailscale Device Cleanup on Server Recreation

**ID:** DN 0004
**Date:** 2026-06-16
**Status:** Resolved — implemented in current commit

### Problem

Tailscale's device model identifies devices by their unique hostname. When reusing hostnames across infrastructure recreation (e.g., always naming the server `node0` for stable MagicDNS entries), stale devices with that hostname must be removed before the new server can register. Tailscale's API offers no native "de-auth" mechanism — when `hcloud_server.node0` is recreated, the old device persists in the network with the same hostname. The new server attempting to register with that hostname will collide with the stale device, preventing clean registration and stable DNS resolution.

### Options Considered

| Option | Summary                                                | Pros                                                                          | Cons                                                                                                  | Decision     |
|--------|--------------------------------------------------------|-------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|--------------|
| 1      | Manual cleanup via Tailscale console before recreation | No code coupling, straightforward                                             | Breaks full automation, requires manual intervention                                                  | Rejected     |
| 2      | Destructive provisioner calling Tailscale API          | Fully automated, cleans up on node recreation, integrates with Tofu lifecycle | Requires OAuth token with elevated scopes, API calls during destroy phase, no built-in error handling | **Selected** |
| 3      | Use unique hostname per server generation              | Avoids collision entirely                                                     | Breaks stable MagicDNS entries, requires clients to discover new hostnames on each recreation         | Rejected     |
| 4      | Use Tailscale tags instead of hostnames                | More flexible, less collision-prone                                           | Adds complexity; tags also require API management, MagicDNS still requires stable names               | Rejected     |
| 5      | Store device ID and rotate it on recreation            | Avoids API calls                                                              | Tailscale doesn't support device ID-based registration, only hostname/auth key                        | Not viable   |

### Implemented Solution (Option 2)

A `terraform_data` resource in `modules/tailscale/main.tf` uses a `local-exec` provisioner with `when = destroy` lifecycle to clean up stale Tailscale devices when the node is recreated.

**Architecture:**

1. **Trigger source**: `module.hetzner` exports `node0_trigger` output containing node name and ID
2. **Root module integration**: `main.tf` passes `change_triggers = [module.hetzner.node0_trigger]` to `module.tailscale`
3. **Resource loop**: `terraform_data.tailscale_cleanup` creates one resource per trigger (keyed by node name via `for_each`)
4. **Replacement condition**: `triggers_replace` watches the trigger value; when node is recreated, trigger changes and resource is marked for replacement
5. **Destroy phase**: Provisioner executes with `when = destroy` and:
   * Obtains an access token from Tailscale OAuth API using client credentials
   * Queries `/api/v2/tailnet/-/devices` to find all devices matching the node's hostname
   * Deletes matching devices via `DELETE /api/v2/device/{id}`

**Code in `modules/tailscale/main.tf`:**

```hcl
resource "terraform_data" "tailscale_cleanup" {
  for_each = { for trigger in var.change_triggers : trigger.name => trigger.id }

  triggers_replace = {
    change_trigger = "${each.key}:${each.value}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOF
      TOKEN=$(curl -sS -d "client_id=$TS_CLIENT_ID" -d "client_secret=$TS_CLIENT_SECRET" "https://api.tailscale.com/api/v2/oauth/token" | jq -r '.access_token')
      IDS=$(curl -sS -H "Authorization: Bearer $TOKEN" "https://api.tailscale.com/api/v2/tailnet/-/devices" |  jq -r '.devices[] | select(.hostname == "${self.output.name}") | .id')
      echo "$IDS" | xargs -I {} curl -sS -X DELETE -H "Authorization: Bearer $TOKEN" "https://api.tailscale.com/api/v2/device/{}"
    EOF
    environment = {
      TS_CLIENT_ID     = self.output.client_id
      TS_CLIENT_SECRET = self.output.client_secret
    }
  }

  input = {
    name          = each.key
    id            = each.value
    client_id     = local.tailscale.client_id
    client_secret = local.tailscale.client_secret
  }
}
```

**Flow:**

* **Node recreated**: `node0_trigger` value changes → `terraform_data.tailscale_cleanup` is marked for replacement
* **On destroy**: Provisioner executes, finds old device by hostname via API, deletes it
* **On apply**: New `terraform_data` created with new trigger value
* **Next node registration**: Tailscale network no longer has a stale device with that hostname; new auth succeeds cleanly

### Trade-offs and Limitations

**OAuth Scope Elevation:** Tailscale OAuth token requires `devices:core` scope with `prod` tag (both read and write access). This is broader than the existing `tailnet:write` scope used for auth key generation. Must be explicitly configured in the Tailscale admin console. Adding this scope to an existing token requires console login and manual approval.

**Destroy Phase Execution:** The provisioner runs during the destroy phase of `tofu apply` (when the resource is replaced), not during `tofu destroy` of the entire infrastructure. If network is unavailable during this phase, the API calls will fail and stale devices will persist. Destruction errors don't block apply completion.

**No Built-in Error Handling:** If API calls fail (invalid token, rate limiting, network errors), provisioner errors are logged to stderr but don't prevent apply from succeeding. Stale devices may persist; manual cleanup via Tailscale console required.

**Assumes Unique Hostname:** The cleanup logic deletes all devices matching the node's hostname. Currently safe because node names are unique (`node0`, `node1`, etc.), but this assumption must be preserved during future multi-node expansion.

### Related

See **DN 0001** for the auth key lifecycle problem that motivates frequent key regeneration, which in turn necessitates this cleanup mechanism.

### Future Enhancements

* Add explicit error handling and alerting if API calls fail during destroy phase
* Extend to multi-node scenarios where `change_triggers` includes triggers from multiple nodes
* Implement retry logic with exponential backoff for transient API failures
* Add external alerting (webhook, Tailscale golink) when stale devices are detected but cleanup fails
