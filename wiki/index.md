---
title: Bluerush Ops Wiki — Index
category: index
updated: 2026-04-29
---

# Bluerush Ops Wiki

> **Topic**: SecDevOps — AWS multi-account operations, CI/CD, IaC, DR, scripting standards
> **Initialized**: 2026-04-24
> **Sources ingested**: 5

---

## Sources

| Page | Summary | Date |
|------|---------|------|
| [[sources/secdevops-repo-framework]] | Monorepo layout, security guardrails, scripting standards, Jenkins/OpenTofu/Ansible patterns | 2025-04 |
| [[sources/web-app-dr-sop]] | Disaster recovery SOP for Windows EC2 + RDS MySQL + S3 media stack (ca-central-1) | 2026-03 |
| [[sources/github-account-recovery]] | GitHub org account recovery note for github.com/bluerush | 2026-04 |
| [[sources/pscodebase-scaffold]] | Production-grade PowerShell repo scaffold — Modules/Public/Private split, AWS.Tools modular, SSM-only secrets, Pester 5 with mocking, GitHub Actions CI | 2026-04 |
| [[sources/ps-module-template-plan]] | Plan for a PSModuleTemplate GitHub Template Repository + bootstrap.ps1 initializer (chosen over branches/forks/Plaster/Catesta) | 2026-04 |

---

## Entities

| Page | Summary |
|------|---------|
| [[entities/bluerush]] | Bluerush — the operator org; AWS Org owner, ca-central-1 primary region |
| [[entities/jenkins]] | Jenkins CI — shared-library pipeline-as-code, no long-lived credentials |
| [[entities/opentofu]] | OpenTofu — Terraform-compatible IaC replacing Terraform OSS after BSL license |
| [[entities/ansible]] | Ansible — config management, EC2 hardening, dynamic inventory via aws_ec2 plugin |
| [[entities/aws-organizations]] | AWS Organizations — multi-account structure; member accounts assumed via STS |
| [[entities/pester]] | Pester 5.x — PowerShell test framework, full AWS mocking for unit tests |
| [[entities/psscriptanalyzer]] | PSScriptAnalyzer — PowerShell static analyzer; first gate in CI |
| [[entities/aws-tools-modular]] | AWS.Tools.* — per-service AWS SDK modules; AWSPowerShell monolith forbidden |
| [[entities/psmoduletemplate]] | Planned GitHub Template Repository + bootstrap.ps1 for spawning new PowerShell module repos |

---

## Concepts

| Page | Summary |
|------|---------|
| [[concepts/everything-as-code]] | All runnable ops artifacts live in the repo — scripts, pipelines, SQL, runbooks |
| [[concepts/zero-secrets-in-repo]] | No secrets ever committed; SSM/Secrets Manager ARNs as placeholders |
| [[concepts/blast-radius-management]] | Destructive ops segregated to `_destructive/` + mandatory confirmation prompts |
| [[concepts/pre-commit-gating]] | detect-secrets, shellcheck, ansible-lint, tflint run before push |
| [[concepts/sts-assume-role-pattern]] | EC2 instance profile → STS assume-role; no static creds on agents or in Jenkins |
| [[concepts/directory-based-env-isolation]] | `prod/` and `nonprod/` as sibling directories — never flags or variables |
| [[concepts/trunk-based-development]] | Short-lived branches off `main`; protected branch, PR required even solo |
| [[concepts/disaster-recovery]] | DR strategy: RTO/RPO targets, multi-AZ RDS, S3 cross-region, Windows EC2 runbooks |
| [[concepts/rds-point-in-time-restore]] | PITR pattern — restore to new instance, validate, swap endpoint via SSM |
| [[concepts/public-private-module-split]] | PowerShell module layout — Public/ + Private/, dot-source order, one function per file |
| [[concepts/explicit-module-exports]] | No wildcarded exports; FunctionsToExport is enumerated or dynamically derived from Public/ |
| [[concepts/scaffold-templating]] | GitHub Template Repo + bootstrap.ps1 pattern for spawning project repos — no Plaster/Catesta deps |

---

## Synthesis

| Page | Summary |
|------|---------|
| [[synthesis/secdevops-posture]] | Overall SecDevOps posture — layered controls from repo to runtime |
| [[synthesis/dr-and-resilience-strategy]] | End-to-end resilience architecture for the Bluerush web app stack |
