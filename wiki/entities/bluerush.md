---
title: Bluerush
category: entity
summary: Bluerush — the operator organization. AWS Org owner, primary region ca-central-1, running a mixed Windows/Linux web stack.
tags: [org, aws, operator]
sources: 4
updated: 2026-04-29
---

# Bluerush

**Type**: Private company / IT operator
**Primary AWS region**: `ca-central-1`
**DR region**: `us-east-1`
**AWS profile (primary)**: `bluroot-td`
**GitHub org**: `github.com/bluerush` (currently locked — see [[sources/github-account-recovery]])

---

## AWS Infrastructure Overview

- **Account model**: AWS Organizations multi-account (management + member accounts). See [[entities/aws-organizations]].
- **Compute**: 2x Windows Server EC2 (`host1a-tdkc` in ca-central-1a, `host1b-tdkc` in ca-central-1b) behind an ALB.
- **Database**: RDS MySQL, Multi-AZ, identifier `prod-db`.
- **Storage**: EBS (encrypted) for OS/app; S3 for media backups (`prod-media-backup` primary, `prod-media-backup-dr` DR).
- **CI/CD**: Jenkins with EC2 agents using instance profiles — no static credentials.
- **IaC**: [[entities/opentofu]] for infrastructure; [[entities/ansible]] for config management.

## Ops Repository

Monorepo (`ops/`) on GitHub. All scripts, pipelines, runbooks, SQL, and config live here. See [[sources/secdevops-repo-framework]] for full layout.

Key ops identities:
- Operator: Nuno Serrenho (`nuno@bluerush.com`)
- Prod gate submitter: `nuno-serrenho` (Jenkins)

## SSM Parameter Namespace

`/bluerush/{env}/...` — catalogued in `config/ssm-parameter-inventory.md`. See [[concepts/zero-secrets-in-repo]].

## Current Incidents / Open Items

- **GitHub org recovery**: `github.com/bluerush` account is 2FA-locked. Ticket #4178948 open with GitHub Support. See [[sources/github-account-recovery]].

## PowerShell Tooling

Bluerush has a canonical PowerShell scaffold (`PSCodebase`) and a planned template-repo + bootstrapper for spawning new modules. See [[sources/pscodebase-scaffold]] and [[sources/ps-module-template-plan]]. Standards live in `Projects/Powershell/CLAUDE.md`.

---

## Related Pages

- [[sources/secdevops-repo-framework]]
- [[sources/web-app-dr-sop]]
- [[sources/github-account-recovery]]
- [[sources/pscodebase-scaffold]]
- [[entities/jenkins]], [[entities/opentofu]], [[entities/ansible]], [[entities/aws-organizations]]
- [[entities/pester]], [[entities/psscriptanalyzer]], [[entities/aws-tools-modular]]
- [[synthesis/secdevops-posture]], [[synthesis/dr-and-resilience-strategy]]
