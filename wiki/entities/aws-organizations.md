---
title: AWS Organizations
category: entity
summary: AWS Organizations multi-account structure used by Bluerush; management account holds org-level permissions; member accounts assumed via STS OrgAuditRole or CICDDeployRole.
tags: [aws, organizations, iam, sts, multi-account]
sources: 3
updated: 2026-04-29
---

# AWS Organizations

**Role**: Multi-account governance for Bluerush AWS infrastructure
**Model**: Management account + member accounts (prod, nonprod, mgmt/tooling)

---

## Account Structure

| Account | Purpose |
|---------|---------|
| Management / root | Org-level IAM, consolidated billing, CloudTrail aggregation |
| `prod` | Production workloads (EC2, RDS, S3) |
| `nonprod` | Non-production workloads |
| `mgmt` | Tooling: Jenkins, logging infrastructure |

## Cross-Account Access Pattern

Scripts and pipelines never use long-lived credentials for member accounts. The pattern:

1. Management/tooling EC2 instance has an **instance profile** with `sts:AssumeRole` permission.
2. Scripts assume the target-account role (e.g., `OrgAuditRole` for read-only, `CICDDeployRole` for deploy).
3. Temporary credentials are scoped to the pipeline stage duration.

PowerShell example: `Invoke-MultiAccountAudit.ps1` loops `Get-ORGAccountList` + STS assume per account.

See [[concepts/sts-assume-role-pattern]].

## Roles

| Role | Accounts | Purpose |
|------|----------|---------|
| `OrgAuditRole` | All member accounts | Read-only org-wide audit |
| `CICDDeployRole` | prod, nonprod | Jenkins deploy operations |

## Inventory Scripts

- `scripts/bash/aws/org/assume-role-all-accounts.sh` — Bash version of multi-account assume
- `scripts/pwsh/aws/org/Get-AllAccountResources.ps1` — PowerShell version
- `scripts/pwsh/aws/iam/Invoke-MultiAccountAudit.ps1` — IAM policy audit across all accounts
- `Modules/AWS/Public/Get-ActiveOrgAccounts.ps1` (in [[sources/pscodebase-scaffold]]) — typed enumeration with exclusion list, returns `Amazon.Organizations.Model.Account[]`

## IaC Environments

Each AWS account maps to an OpenTofu environment root module (`iac/environments/{prod,nonprod,mgmt}`). State is never shared between accounts. See [[entities/opentofu]], [[concepts/directory-based-env-isolation]].

---

## Related Pages

- [[sources/secdevops-repo-framework]], [[sources/pscodebase-scaffold]], [[sources/tdkc-environments]]
- [[entities/bluerush]], [[entities/aws-tools-modular]], [[entities/tdkc]]
- [[entities/jenkins]]
- [[concepts/sts-assume-role-pattern]]
- [[concepts/directory-based-env-isolation]]
- [[synthesis/secdevops-posture]]
