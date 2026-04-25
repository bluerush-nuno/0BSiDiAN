---
title: Trunk-Based Development
category: concept
summary: Short-lived feature branches off a protected main branch; PR required for all merges (even solo) to maintain an audit trail.
tags: [git, branching, devops, workflow]
sources: 1
updated: 2026-04-24
---

# Trunk-Based Development

The git workflow used in the Bluerush ops monorepo — simplified trunk-based for a solo/small team.

---

## Branch Structure

```
main                              ← always deployable; protected
  └── ops/YYYYMMDD-<slug>         ← standard ops/feature branch
  └── fix/YYYYMMDD-<slug>         ← bug fix
  └── hotfix/<ticket>-<slug>      ← urgent prod fixes only
```

## Rules

1. `main` is protected: no direct push. PR required for all merges.
2. Even solo work goes through PRs — for the audit trail, not for the review.
3. Branch naming includes the date: `ops/20250422-iam-audit-script`.
4. Feature branches are short-lived (hours to days, not weeks).

## Merge Strategy

- **Squash merges** for script changes — clean, single-commit history on main.
- **Merge commits** for runbooks/docs — preserves the history of how thinking evolved.

## Tagging

Ansible playbooks and OpenTofu modules are tagged at release points:
- `ansible/ec2-hardening/v1.2.0`
- `iac/modules/vpc/v2.0.0`

This enables pipelines to pin a specific version of a module.

## Commit Message Convention

```
<type>(<scope>): <short imperative description>
```

| Type | When |
|------|------|
| `feat` | New capability |
| `fix` | Bug fix |
| `ops` | Operational task (script run, config update) |
| `sec` | Security control added or hardened |
| `docs` | Documentation or runbook update |
| `refactor` | Code restructuring without behavior change |
| `chore` | Tooling, deps, CI config |

Scopes: `ansible`, `iac`, `scripts`, `jenkins`, `sql`, `runbooks`.

Examples:
- `feat(iac): add RDS Aurora module with encryption enforced`
- `sec(ansible): add CIS 4.1 SSH hardening controls to common role`
- `ops(scripts): add dry-run flag to purge-snapshots.sh`

## Pre-commit Integration

`no-commit-to-branch` hook blocks direct pushes to `main`. See [[concepts/pre-commit-gating]].

---

## Related Pages

- [[sources/secdevops-repo-framework]]
- [[concepts/everything-as-code]]
- [[concepts/pre-commit-gating]]
- [[synthesis/secdevops-posture]]
