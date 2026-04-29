---
title: Everything-as-Code
category: concept
summary: All runnable ops artifacts — scripts, pipelines, runbooks, SQL, config — live in the repo. If it runs in prod, it must be version-controlled.
tags: [principle, gitops, devops, secdevops]
sources: 3
updated: 2026-04-29
---

# Everything-as-Code

**Design Principle #1** of the Bluerush ops monorepo.

> "Scripts, pipelines, runbooks, SQL, config. If it runs in prod, it lives here."

---

## What This Covers

| Artifact type | Location in `ops/` |
|--------------|-------------------|
| Bash scripts | `scripts/bash/` |
| PowerShell scripts | `scripts/pwsh/` |
| CI/CD pipelines | `jenkins/pipelines/` + `jenkins/shared-library/` |
| IaC (OpenTofu) | `iac/` |
| Config management | `ansible/` |
| SQL migrations + procedures | `sql/` |
| Runbooks | `runbooks/` |
| Non-secret config | `config/` |
| Architecture decisions | `docs/adr/` |
| Diagrams | `docs/diagrams/` (source files — draw.io XML, PlantUML) |

## What Is Explicitly Excluded

- **Secrets and credentials** — never committed, ever. See [[concepts/zero-secrets-in-repo]].
- **Compiled binaries** and generated files (`.tfstate`, `__pycache__`, `node_modules`).
- **IDE-specific settings** (`.vscode/settings.json` — only `extensions.json` allowed).
- **OS artifacts** (`.DS_Store`, `Thumbs.db`).

## Why It Matters

- **Auditability**: Every change to prod is traceable via git history.
- **Reproducibility**: Any team member (or the LLM) can read the repo and understand what runs where.
- **Disaster recovery**: When a server is lost, the scripts to rebuild it are in the repo.
- **Review**: PRs enforce peer review (even solo — for the audit trail).

## Enforcement

- `.gitignore` blocks binary, secret, and generated file extensions.
- `no-commit-to-branch` hook prevents direct pushes to `main`.
- PR required for all merges.

---

## Related Pages

- [[sources/secdevops-repo-framework]], [[sources/pscodebase-scaffold]], [[sources/ps-module-template-plan]]
- [[concepts/zero-secrets-in-repo]]
- [[concepts/pre-commit-gating]]
- [[concepts/trunk-based-development]]
- [[concepts/public-private-module-split]], [[concepts/explicit-module-exports]]
- [[concepts/scaffold-templating]]
- [[synthesis/secdevops-posture]]
