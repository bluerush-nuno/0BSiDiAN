---
title: Bluerush SecDevOps Posture
category: synthesis
summary: End-to-end view of the security and operations posture — from repo controls through runtime, covering tooling choices, control gaps, and layered defense principles.
tags: [secdevops, security, posture, aws, synthesis]
sources: 1
updated: 2026-04-24
---

# Bluerush SecDevOps Posture

A synthesis of the security and operational practices documented in [[sources/secdevops-repo-framework]].

---

## Layered Control Model

The Bluerush approach applies controls at every layer — not relying on any single gate.

```
Layer 1 — Developer workstation
  └── pre-commit: detect-secrets, shellcheck, ansible-lint, terraform fmt/validate
  └── no-commit-to-branch: blocks direct push to main

Layer 2 — Repository
  └── .gitignore: blocks secret file types
  └── Branch protection: PR required, no force push
  └── Commit convention: typed scope + type for changelog legibility

Layer 3 — Pipeline (Jenkins)
  └── STS assume-role: no static creds; temp tokens, auto-expire
  └── Prod gate: input step requires named approver
  └── DRY_RUN default: plan-only unless explicitly disabled
  └── Shared library: consistent security patterns across all pipelines

Layer 4 — Infrastructure (OpenTofu / Ansible)
  └── Environment isolation: directory-based, never flags
  └── State isolation: separate S3 backend + DynamoDB lock per env
  └── CIS hardening: ec2-hardening playbook applies L1 baseline
  └── SSM agent: on every host for Session Manager (no SSH bastion needed)

Layer 5 — Runtime (AWS)
  └── Secrets: SSM Parameter Store / Secrets Manager (never in code)
  └── Encryption: EBS encrypted, S3 SSE-S3/KMS, RDS encrypted
  └── Multi-AZ: RDS standby; EC2 in 2 AZs behind ALB
  └── GuardDuty: referenced in IR runbook
  └── CloudTrail: org-wide; referenced in audit and IR scripts
```

---

## Tooling Decisions

| Tool | Alternative rejected | Reason |
|------|---------------------|--------|
| OpenTofu | Terraform OSS | BSL license risk post-v1.5 (ADR-001) |
| Ansible | AWS Systems Manager / Chef | Existing competency; aws_ec2 dynamic inventory fits well |
| Jenkins | GitHub Actions | Self-hosted; existing infrastructure |
| SSM Parameter Store | HashiCorp Vault | Already on AWS; lower operational overhead |
| detect-secrets (Yelp) | TruffleHog, gitleaks | Baseline model allows false-positive management |

---

## Strengths

1. **No static credentials anywhere** — instance profiles + STS is the gold standard. See [[concepts/sts-assume-role-pattern]].
2. **Pre-commit gates** catch secrets before they reach the remote. See [[concepts/pre-commit-gating]].
3. **Destructive ops are physically segregated** with mandatory confirmation. See [[concepts/blast-radius-management]].
4. **Directory-based isolation** eliminates "wrong environment" deployment errors. See [[concepts/directory-based-env-isolation]].
5. **Everything is code** — runbooks, SQL migrations, config all auditable via git. See [[concepts/everything-as-code]].
6. **Self-documenting scripts** — every script header declares PROD RISK and BLAST RADIUS.

---

## Gaps and Risks (as of 2025-04)

| Gap | Risk | Mitigation available |
|-----|------|---------------------|
| No automated AMI snapshots | EC2 rebuild requires manual config capture | Standardize `UserData` script; enable EC2 Image Builder |
| Jenkins is self-hosted | Jenkins itself is a single point of failure | Backup JCasC; document bootstrap procedure |
| GitHub org locked | Source control inaccessible | Local clones; open ticket #4178948 — see [[sources/github-account-recovery]] |
| No RDS cross-region read replica | Regional loss requires 2–4h restore | Add Aurora global database if RTO < 1h is required |
| SQL destructive files require PR approval | No technical gate on `DROP--` files | Add a `git diff --name-only` check in CI to flag `_destructive/` changes |
| `ansible-lint` may pass bad playbooks | Lint is not a security audit | Add `ansible-lint` profile `production` and checkov for IaC |

---

## Cross-Reference: DR Integration

The SecDevOps repo framework and the DR SOP are complementary:
- Ops repo holds the scripts, runbooks, and IaC to build and maintain infrastructure.
- DR SOP provides the step-by-step recovery procedures for when infrastructure fails.
- Both use the same credential model (SSM + STS), same tooling (PowerShell + AWS.Tools), same profile (`bluroot-td`).

See [[synthesis/dr-and-resilience-strategy]], [[sources/web-app-dr-sop]].

---

## Related Pages

- [[sources/secdevops-repo-framework]]
- [[entities/bluerush]], [[entities/jenkins]], [[entities/opentofu]], [[entities/ansible]]
- [[concepts/everything-as-code]], [[concepts/zero-secrets-in-repo]], [[concepts/blast-radius-management]]
- [[concepts/pre-commit-gating]], [[concepts/sts-assume-role-pattern]], [[concepts/directory-based-env-isolation]]
- [[concepts/trunk-based-development]]
