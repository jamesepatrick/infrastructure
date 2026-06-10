# AGENTS.md

Agent orientation for this OpenTofu infrastructure repository.

## Toolchain

- **OpenTofu** (`tofu`) >= 1.11.0 — primary IaC tool (Terraform fork; use `tofu`, not `terraform`)
- **1Password CLI** (`op`) — secrets injection; requires `OP_SERVICE_ACCOUNT_TOKEN` in env
- **AWS S3** — remote state backend with native OpenTofu locking (`use_lockfile = true`; no DynamoDB needed)
- No package manager, no build framework, no test harness

## Setup (required before any tofu command)

```bash
source .env.sh   # exports OP_SERVICE_ACCOUNT_TOKEN + AWS credentials — gitignored, must exist locally
```

Without this, `tofu plan`/`tofu apply` fail immediately.

## Core Commands

```bash
tofu init                          # after provider/module changes
tofu plan
tofu apply
tofu apply -target=module.hetzner  # focused apply for a single module
tofu providers lock                # update .terraform.lock.hcl after provider changes
```

No lint, test, or format commands are configured. `tflint` is used ad-hoc (no `.tflint.hcl` present).

## Repository Structure

```
main.tf              # root: wires all modules, S3 backend, outputs node_ipv4 + SSH keys
providers.tf         # provider declarations and version pins
secrets.tf           # single 1Password vault data source (vault: "infrastructure")
.terraform.lock.hcl  # committed provider hash lock — do not delete
docs/
  development_notes.md  # Design decisions, problem analysis, and implementation notes
modules/
  dns/               # Cloudflare DNS for jpatrick.io (zone, records, ProtonMail config)
  github/            # GitHub repo management; outputs SSH public keys for VPS auth
  hetzner/           # Hetzner VPS (node0/cx23/nbg1), floating IP, firewall, 30GB volume
    cloud-init/      # Multi-part cloud-init templates (setup, tailscale, secrets)
  tailscale/         # Tailscale ephemeral auth key generation via OAuth
  s3_backend/        # AWS S3 bucket for remote state storage
  infra/             # LEGACY — old workspace targeting node0; not active, ignore it
```

## Architecture Quirks

**Providers declared inside modules, not passed from root.** Every module instantiates its own provider using credentials fetched directly from 1Password. This is intentional but non-standard.

**`vault_uuid` is threaded from root to all modules** as a sensitive variable — it's the 1Password vault ID.

**`prevent_destroy = true`** is set on: S3 bucket, Hetzner floating IP, Hetzner data volume, GitHub repo. Destroying these requires manually removing the lifecycle block first.

**Self-bootstrapping S3 backend:** The `jpatrick-terraform` S3 bucket holding remote state is itself managed by `module.s3_backend`. First-time setup requires:

```bash
tofu apply -target=module.s3_backend   # create bucket first
tofu init                               # then init with S3 backend
```

**`modules/infra/` is dead code.** It has its own `.terraform/` state and targets node0 with an older provider version. Do not plan or apply it.

## Secrets

All credentials live in the `"infrastructure"` 1Password vault. Nothing is hardcoded or in `.tfvars`.

| 1Password Item                    | Used By             |
|-----------------------------------|---------------------|
| `"github"`                        | `modules/github`    |
| `"hetzner"`                       | `modules/hetzner`   |
| `"cloudflare"` (section `"dns"`)  | `modules/dns`       |
| `"protonmail"`                    | `modules/dns`       |
| `"tailscale"` (section `"oauth"`) | `modules/tailscale` |
| `"ssh"`                           | `modules/hetzner`   |

AWS credentials are env vars only (not in 1Password).

## Active Migration State

Migration from DigitalOcean (`node0`, `159.89.245.134`) to Hetzner (`node1`/`node2`) is in progress:

- **Already on Hetzner**: `audiobooks.jpatrick.io`, `traefik.jpatrick.io`
- **Still on DigitalOcean**: `cloud`, `git`, `pops`, `rss`, apex `@`
- The `node0.jpatrick.io` A record and related CNAMEs are marked for future removal in `modules/dns`

## No CI/CD

All infrastructure changes are applied manually: `source .env.sh && tofu apply`. There are no GitHub Actions workflows.

## Hetzner Cloud-Init Multi-Part Merge

Three cloud-config files are merged with `list(append)+dict(recurse_list)+str(append)`. Order matters: `setup.yaml.tftpl` → `tailscale.yaml.tftpl` → `secrets.yaml.tftpl`.

Auth key lifecycle and server recreation logic is managed via hash-based content normalization (see `docs/development_notes.md`).

## Development Notes

All architectural decisions, problems encountered, and implemented solutions are documented in `docs/development_notes.md`. This file should be updated whenever:

- A new problem or blocker is discovered
- A design decision is reached (especially when multiple options were considered)
- An implementation is completed that resolves a documented issue

This serves as the authoritative record of why the infrastructure is designed the way it is, and prevents rediscovery of solved problems.

## Active Branch

Current working branch is `feature/v2_refactor`. `main` is stable.

## Future Goals

- The current plan is to move all of this to GitHub Actions for CI/CD. This is most important goal
- We want to eventually move the s3 backend module into its own tofu package. Likely at `.init/`

## Agent Behavior

- Prioritize security & use best security practices. (!)
- Verify results before declaring something is complete.
- If you have questions ask.
- Do not run `tofu apply`. Leave that to a human.
