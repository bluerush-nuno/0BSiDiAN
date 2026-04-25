---
title: OpenTofu
category: entity
summary: OpenTofu is the Terraform-compatible IaC tool chosen by Bluerush after Terraform's BSL license change. Used for all AWS infrastructure provisioning.
tags: [opentofu, terraform, iac, aws]
sources: 1
updated: 2026-04-24
---

# OpenTofu

**Type**: IaC tool (Terraform-compatible fork)
**Why chosen**: Terraform OSS moved to BSL license post-v1.5; OpenTofu remains MPL-licensed. See ADR-001 in `docs/adr/ADR-001-iac-tooling-opentofu.md`.
**CLI binary**: `tofu` (drop-in for `terraform`)

---

## Module Structure (`iac/`)

```
iac/
├── _shared/         # Cross-env data sources, provider config
├── modules/         # Reusable parameterized modules
│   ├── vpc/
│   ├── ec2-asg/
│   ├── rds-aurora/
│   ├── iam-role/
│   └── s3-secure/   # Forced encryption + versioning + logging
└── environments/    # Root modules — one per environment, never share state
    ├── prod/
    ├── nonprod/
    └── mgmt/        # Management/tooling account (Jenkins, logging)
```

## Key Practices

- **Root modules** contain only module calls — no resource blocks directly.
- **State**: S3 backend + DynamoDB locking, per-environment. Never shared across envs.
- **Vars**: `terraform.tfvars` for non-sensitive; secrets via SSM data sources at runtime.
- **Secrets**: never in `.tfvars` — pulled via `aws_ssm_parameter` data source.
- **Module README**: every module must have a `README.md` with inputs, outputs, usage example.
- **Pipeline**: `tofu init` → `tofu plan -out=tfplan` → `tofu apply tfplan`. DRY_RUN skips apply.

## `.gitignore` exclusions for IaC

`*.tfstate`, `*.tfstate.backup`, `.terraform/`, `terraform.tfvars.local` — never committed. See [[concepts/zero-secrets-in-repo]].

## Modules Available

| Module | Notes |
|--------|-------|
| `vpc` | Network foundation |
| `ec2-asg` | Auto Scaling Group pattern |
| `rds-aurora` | Aurora with encryption enforced |
| `iam-role` | IAM role + policy attachment |
| `s3-secure` | S3 with forced encryption, versioning, access logging |

---

## Related Pages

- [[sources/secdevops-repo-framework]]
- [[entities/jenkins]]
- [[entities/bluerush]]
- [[concepts/directory-based-env-isolation]]
- [[concepts/zero-secrets-in-repo]]
- [[synthesis/secdevops-posture]]
