---
title: Bluerush
category: entity
summary: Bluerush — the operator organization. AWS Org owner, primary region ca-central-1, running a mixed Windows/Linux web stack including the TDKC TD Knowledge Centre and the IndiVideo data pipelines.
tags: [org, aws, operator]
sources: 7
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
- **Compute**: 2x Windows Server EC2 (`host1a-tdkc` in ca-central-1a, `host1b-tdkc` in ca-central-1b) behind an ALB — these run the TDKC web property. See [[entities/tdkc]].
- **Database**: RDS MySQL 8, Multi-AZ. The DR SOP refers to it as `prod-db`; the TDKC source identifies it as `mysql8-tdkc-rds.clgyqom42adb.ca-central-1.rds.amazonaws.com`.
- **Storage**: EBS (encrypted) for OS/app; S3 for media backups (`prod-media-backup` primary, `prod-media-backup-dr` DR).
- **CI/CD**: Jenkins with EC2 agents using instance profiles — no static credentials.
- **IaC**: [[entities/opentofu]] for infrastructure; [[entities/ansible]] for config management.

## Hosted Properties

- [[entities/tdkc]] — TD Knowledge Centre (`td-digitalreach-html`); the production target the DR SOP restores.

## Vendor Engagements

- [[entities/nationwide]] — NW-002 Pet IndiVideo data automation (US-soil residency required; see [[concepts/data-residency]] for the regional knock-ons).

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
- [[sources/pscodebase-scaffold]], [[sources/ps-module-template-plan]]
- [[sources/tdkc-environments]], [[sources/nw-002-pet-data-automation]]
- [[entities/jenkins]], [[entities/opentofu]], [[entities/ansible]], [[entities/aws-organizations]]
- [[entities/pester]], [[entities/psscriptanalyzer]], [[entities/aws-tools-modular]], [[entities/psmoduletemplate]]
- [[entities/tdkc]], [[entities/nationwide]]
- [[concepts/data-residency]]
- [[synthesis/secdevops-posture]], [[synthesis/dr-and-resilience-strategy]]
