---
title: Pre-Commit Gating
category: concept
summary: Secrets detection, linting, and format checks run via pre-commit hooks before any push. Catches problems at the point of authorship, not after merge.
tags: [security, devops, git, ci, linting]
sources: 1
updated: 2026-04-24
---

# Pre-Commit Gating

**Design Principle #5** of the Bluerush ops monorepo.

> "Pre-commit gates, not post-commit regret — secrets detection, lint, shellcheck run before push."

---

## Hooks Configured (`.pre-commit-config.yaml`)

| Hook | Source | Scope | Purpose |
|------|--------|-------|---------|
| `detect-secrets` v1.5.0 | Yelp | All files | Secrets scanning against `.secrets.baseline` |
| `shellcheck` v0.10.0.1 | shellcheck-py | `scripts/bash/.*\.sh$` | Bash linting (SC1091 suppressed for sourced libs) |
| `ansible-lint` v24.2.0 | ansible | `ansible/.*\.(yml\|yaml)$` | Ansible playbook linting |
| `terraform_fmt` | antonbabenko/pre-commit-terraform v1.92.0 | `*.tf` | OpenTofu format enforcement |
| `terraform_validate` | same | `*.tf` | OpenTofu validation |
| `trailing-whitespace` | pre-commit-hooks v4.6.0 | All | Whitespace hygiene |
| `end-of-file-fixer` | same | All | Consistent file endings |
| `check-merge-conflict` | same | All | Catches unresolved merge markers |
| `check-yaml` | same | `*.yml`, `*.yaml` | YAML syntax |
| `check-json` | same | `*.json` | JSON syntax |
| `no-commit-to-branch` | same | `main` branch | Blocks direct push to main |

## Setup

```bash
pip install pre-commit detect-secrets
pre-commit install
detect-secrets scan > .secrets.baseline
git add .secrets.baseline
pre-commit run --all-files  # Verify
```

## How `detect-secrets` Works

Uses a `.secrets.baseline` file to track known false positives. New secrets detected fail the hook. The baseline is committed to the repo (it contains secret locations, not values).

## Why SC1091 Is Suppressed

ShellCheck warns when a `source` target can't be followed statically. Bluerush scripts source from `lib/` using `$(dirname "$0")/../lib/common.sh` — a dynamic path. SC1091 is suppressed globally for the repo; the sourcing pattern is documented in CONTRIBUTING.md.

## Baseline Regeneration

When adding a new intentional high-entropy string (e.g., a test fixture), update the baseline:
```bash
detect-secrets scan --baseline .secrets.baseline
```

---

## Related Pages

- [[sources/secdevops-repo-framework]]
- [[concepts/zero-secrets-in-repo]]
- [[concepts/everything-as-code]]
- [[concepts/trunk-based-development]]
- [[synthesis/secdevops-posture]]
