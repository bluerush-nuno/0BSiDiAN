---
title: SecDevOps Repo Framework
category: source
summary: Monorepo layout, security guardrails, scripting conventions, and pipeline patterns for Bluerush multi-account AWS ops.
tags: [secdevops, monorepo, aws, jenkins, opentofu, ansible, bash, powershell, security]
sources: 1
updated: 2026-04-24
source_path: Projects/SecDevOps/SecDevOps_Repo_Framework.md
source_date: 2025-04
authors: [Nuno Serrenho]
ingested: 2026-04-24
---

# SecDevOps Repo Framework

**Original**: `Projects/SecDevOps/SecDevOps_Repo_Framework.md`
**Author**: Nuno Serrenho | **Date**: 2025-04

---

## TL;DR

A disciplined monorepo (`ops/`) that treats everything as code and enforces security at every layer: pre-commit hooks catch secrets and lint errors, destructive scripts are physically segregated with mandatory confirmation gates, no static credentials ever touch the repo, and each environment (`prod/`, `nonprod/`) is isolated by directory structure rather than by flags.

---

## Design Principles (verbatim)

1. **Everything-as-code** — scripts, pipelines, runbooks, SQL, config. If it runs in prod, it lives here.
2. **No secrets in the repo** — ever. SSM Parameter paths or Secrets Manager ARNs as placeholders only.
3. **Environment isolation is structural** — `prod/` and `nonprod/` are sibling directories, never flags/variables.
4. **Every script is self-documenting** — standard header block required.
5. **Pre-commit gates, not post-commit regret** — secrets detection, lint, shellcheck run before push.
6. **Blast radius is always visible** — destructive scripts live in `_destructive/` and require confirmation prompts.

See [[concepts/everything-as-code]], [[concepts/zero-secrets-in-repo]], [[concepts/blast-radius-management]], [[concepts/pre-commit-gating]], [[concepts/directory-based-env-isolation]].

---

## Repository Layout (top-level)

```
ops/
├── ansible/       # Config management, EC2 hardening, dynamic inventory
├── iac/           # OpenTofu modules + per-env root modules
├── jenkins/       # Shared library + Jenkinsfiles
├── scripts/       # bash/ and pwsh/ with _destructive/ subfolders
├── sql/           # Migrations (Flyway-compatible) + procedures + _destructive/
├── config/        # Non-secret config; ssm-parameter-inventory.md catalogue
├── runbooks/      # Markdown runbooks (incidents, maintenance, DR, onboarding)
└── docs/          # ADRs + diagrams
```

### Key structural decisions

- **`iac/environments/`** — never shares Terraform state across environments; each env has its own S3 backend + DynamoDB lock.
- **`ansible/inventories/`** — prod and nonprod have separate `aws_ec2.yml` dynamic inventory files.
- **`jenkins/shared-library/`** — `withAWSRole.groovy` is the STS assume-role wrapper; no credentials stored in Jenkins.
- **`config/ssm-parameter-inventory.md`** — SSM paths catalogued (no values, just paths + types + rotation cadence).

---

## Security Guardrails

### .gitignore exclusions
Covers all credential file extensions (`.pem`, `.key`, `.p12`, `.pfx`, `*_rsa`, `*_ed25519`, `credentials`, `.env*`, `*.tfstate`, `.vault_pass`). See [[concepts/zero-secrets-in-repo]].

### .pre-commit-config.yaml
| Hook | Purpose |
|------|---------|
| `detect-secrets` | Baseline-driven secrets scanning |
| `shellcheck` | Bash linting (SC1091 suppressed for sourced libs) |
| `ansible-lint` | Ansible playbook linting |
| `terraform_fmt` + `terraform_validate` | OpenTofu format and validate |
| `check-yaml`, `check-json`, `trailing-whitespace` | General hygiene |
| `no-commit-to-branch` | Blocks direct push to `main` |

See [[concepts/pre-commit-gating]].

---

## Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Bash scripts | `<verb>-<noun>[-<qualifier>].sh` | `audit-iam-policies.sh` |
| PowerShell scripts | `<ApprovedVerb>-<Noun>[<Qualifier>].ps1` | `Find-WildcardPolicies.ps1` |
| SQL migrations | `V<seq>__<description>.sql` (Flyway-compatible) | `V001__initial_schema.sql` |
| SQL destructive | `<ACTION>--<description>.sql` | `DROP--obsolete-tables.sql` |
| Ansible playbooks | `<target>-<action>.yml` | `ec2-hardening.yml` |
| Runbooks | `<SERVICE>-<incident-type>.md` | `IAM-credential-compromise.md` |

---

## Script Header Blocks

Both Bash and PowerShell headers require: PURPOSE, AUTHOR, VERSION, PROD RISK, BLAST RADIUS, PREREQS, USAGE.

- **Bash**: `set -euo pipefail`; source `common.sh` and `aws.sh` from `lib/`.
- **PowerShell**: `[CmdletBinding(SupportsShouldProcess)]`; `Set-StrictMode -Version Latest`; `$ErrorActionPreference = 'Stop'`; dot-source `Common.psm1` and `AWSHelpers.psm1`.

---

## Shared Library Patterns

### Bash (`scripts/bash/lib/common.sh`)
Key functions: `log_info/warn/error`, `confirm_destructive` (requires `YES` typed), `maybe_run` (respects `$DRY_RUN`), `require_cmd`, cleanup trap.

### PowerShell (`scripts/pwsh/lib/Common.psm1`)
Key functions: `Write-Log`, `Confirm-Destructive`, `Invoke-MaybeRun`. Respects `$script:DryRun` flag.

---

## Jenkins Pipeline Pattern

- Agent: EC2 with instance profile — no static credentials.
- Prod gate: `input` step requires submitter `nuno-serrenho`.
- STS assume-role via `withAWSRole.groovy` shared library step — injects temporary credentials as environment variables.
- DRY_RUN parameter defaults to `true` — plan-only until explicitly disabled.

See [[concepts/sts-assume-role-pattern]], [[entities/jenkins]].

---

## Git Workflow

- Trunk-based: `main` always deployable, protected, no direct push.
- Branch naming: `ops/YYYYMMDD-<slug>`, `fix/YYYYMMDD-<slug>`, `hotfix/<ticket>-<slug>`.
- Commit types: `feat | fix | ops | sec | docs | refactor | chore`; scopes: `ansible | iac | scripts | jenkins | sql | runbooks`.

See [[concepts/trunk-based-development]].

---

## SSM Parameter Store Pattern

`config/ssm-parameter-inventory.md` catalogues paths (no values). Scripts pull values at runtime:
```bash
DB_PASS=$(aws ssm get-parameter --name "/bluerush/${ENV}/db/master_password" --with-decryption ...)
```

Key SSM paths:
- `/bluerush/prod/db/master_password` — SecureString, Secrets Manager 90-day rotation
- `/bluerush/prod/jenkins/github_token` — SecureString, manual rotation
- `/bluerush/prod/app/config/log_level` — String

---

## ADR Record

Three decision records documented:
- **ADR-001**: OpenTofu over Terraform (BSL license risk post-v1.5)
- **ADR-002**: SSM vs Secrets Manager (choice of secrets backend)
- **ADR-003**: Monorepo vs polyrepo

---

## Related Pages

- [[entities/bluerush]], [[entities/jenkins]], [[entities/opentofu]], [[entities/ansible]], [[entities/aws-organizations]]
- [[concepts/everything-as-code]], [[concepts/zero-secrets-in-repo]], [[concepts/blast-radius-management]]
- [[concepts/pre-commit-gating]], [[concepts/sts-assume-role-pattern]], [[concepts/directory-based-env-isolation]]
- [[concepts/trunk-based-development]]
- [[synthesis/secdevops-posture]]
