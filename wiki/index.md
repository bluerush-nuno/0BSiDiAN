---
title: Bluerush Ops Wiki — Index
category: index
updated: 2026-04-24
---

# Bluerush Ops Wiki

> **Topic**: SecDevOps — AWS multi-account operations, CI/CD, IaC, DR, scripting standards
> **Initialized**: 2026-04-24
> **Sources ingested**: 3

---

## Sources

| Page | Summary | Date |
|------|---------|------|
| [[sources/secdevops-repo-framework]] | Monorepo layout, security guardrails, scripting standards, Jenkins/OpenTofu/Ansible patterns | 2025-04 |
| [[sources/web-app-dr-sop]] | Disaster recovery SOP for Windows EC2 + RDS MySQL + S3 media stack (ca-central-1) | 2026-03 |
| [[sources/github-account-recovery]] | GitHub org account recovery note for github.com/bluerush | 2026-04 |

---

## Entities

| Page | Summary |
|------|---------|
| [[entities/bluerush]] | Bluerush — the operator org; AWS Org owner, ca-central-1 primary region |
| [[entities/jenkins]] | Jenkins CI — shared-library pipeline-as-code, no long-lived credentials |
| [[entities/opentofu]] | OpenTofu — Terraform-compatible IaC replacing Terraform OSS after BSL license |
| [[entities/ansible]] | Ansible — config management, EC2 hardening, dynamic inventory via aws_ec2 plugin |
| [[entities/aws-organizations]] | AWS Organizations — multi-account structure; member accounts assumed via STS |

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

---

## Synthesis

| Page | Summary |
|------|---------|
| [[synthesis/secdevops-posture]] | Overall SecDevOps posture — layered controls from repo to runtime |
| [[synthesis/dr-and-resilience-strategy]] | End-to-end resilience architecture for the Bluerush web app stack |
