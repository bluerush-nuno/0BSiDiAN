---
title: Zero Secrets in Repo
category: concept
summary: No credentials, keys, tokens, or secret values are ever committed to the ops repo. SSM Parameter Store paths and Secrets Manager ARNs are used as placeholders instead.
tags: [security, secrets, ssm, gitops, principle]
sources: 3
updated: 2026-04-29
---

# Zero Secrets in Repo

**Design Principle #2** of the Bluerush ops monorepo.

> "No secrets in the repo — ever. SSM Parameter paths or Secrets Manager ARNs as placeholders only."

---

## How Secrets Are Handled

### At rest
Secrets live in:
- **SSM Parameter Store** (SecureString type) — for config-like secrets (DB passwords, API tokens, Slack webhooks)
- **AWS Secrets Manager** — for secrets requiring automated rotation (RDS master password, 90-day cycle)

### In scripts
Scripts reference SSM paths, not values:
```bash
DB_PASS=$(aws ssm get-parameter --name "/bluerush/${ENV}/db/master_password" --with-decryption ...)
```
```powershell
$DBEndpoint = Get-SSMParameter -Name "/prod/database/endpoint" -WithDecryption $true ...
```

### Catalogue
`config/ssm-parameter-inventory.md` — a human-readable catalogue of all SSM paths (paths + types + rotation cadence, never values).

## .gitignore Enforced Exclusions

| Pattern | What it blocks |
|---------|---------------|
| `**/.env`, `**/.env.*` | Dotenv files |
| `**/terraform.tfvars.local` | Local Terraform overrides with secrets |
| `**/*.tfstate`, `**/*.tfstate.backup` | State files (may contain resource secrets) |
| `**/*.pem`, `**/*.key`, `**/*.p12`, `**/*.pfx` | Certificates and private keys |
| `**/*_rsa`, `**/*_ed25519` | SSH private keys |
| `**/credentials`, `**/.aws/credentials` | AWS credential files |
| `**/.vault_pass`, `**/*.vault` | Ansible Vault password files |

## Pre-commit Detection

`detect-secrets` with a `.secrets.baseline` runs on every commit attempt. Catches high-entropy strings, API key patterns, and known secret formats before they hit the remote. See [[concepts/pre-commit-gating]].

## SSM Parameter Naming Convention

`/bluerush/{env}/{service}/{key}` — e.g.:
- `/bluerush/prod/db/master_password`
- `/bluerush/prod/jenkins/github_token`
- `/bluerush/nonprod/db/master_password`
- `/bluerush/common/slack_webhook`
- `/bluerush/prod/app/config/log_level`

## DR Context

The DR SOP updates the DB endpoint in SSM after a restore (`Set-SSMParameter`), so applications pick up the new endpoint on restart without any code change. This is the runtime secrets pattern in action. See [[sources/web-app-dr-sop]], [[concepts/rds-point-in-time-restore]].

## Module-level Reinforcement

The [[sources/pscodebase-scaffold]] makes this rule structural at the config-file layer: environment configs (`Config/Environments/prod.psd1`) reference SSM paths only, never values. Pulled at runtime via `Get-SSMParameterValue` / `Get-SECSecretValue`. Schemas in `Config/Schemas/` validate that no field looks like a secret value.

---

## Related Pages

- [[sources/secdevops-repo-framework]]
- [[sources/web-app-dr-sop]]
- [[sources/pscodebase-scaffold]]
- [[concepts/everything-as-code]]
- [[concepts/pre-commit-gating]]
- [[concepts/sts-assume-role-pattern]]
- [[synthesis/secdevops-posture]]
