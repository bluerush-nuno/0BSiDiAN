---
title: Blast Radius Management
category: concept
summary: Destructive operations are physically segregated into _destructive/ subdirectories and require typed confirmation prompts. Blast radius is made visible, not just documented.
tags: [security, operations, safety, principle]
sources: 1
updated: 2026-04-24
---

# Blast Radius Management

**Design Principle #6** of the Bluerush ops monorepo.

> "Blast radius is always visible — destructive scripts live in a `_destructive/` subfolder and require confirmation prompts."

---

## The `_destructive/` Pattern

Every tool category that can produce irreversible side effects has a `_destructive/` subfolder:

| Location | Examples |
|----------|---------|
| `scripts/bash/_destructive/` | `purge-old-snapshots.sh`, `force-terminate-ec2.sh` |
| `scripts/pwsh/_destructive/` | `Remove-OrphanedEBSVolumes.ps1` |
| `ansible/playbooks/_destructive/` | `ec2-terminate.yml` |
| `sql/_destructive/` | `DROP--obsolete-tables.sql`, `TRUNCATE--audit-log.sql` |

**Rule**: Anything with irreversible side effects lives here — no exceptions.

## Mandatory Confirmation Gate

### Bash (`confirm_destructive` in `lib/common.sh`)
```bash
confirm_destructive() {
    ...
    read -r -p "Type YES (uppercase) to continue: " response
    [[ "$response" == "YES" ]] || { log_error "Aborted by user."; exit 1; }
}
```

### PowerShell (`Confirm-Destructive` in `Common.psm1`)
```powershell
$response = Read-Host 'Type YES (uppercase) to continue'
if ($response -ne 'YES') { Write-Log 'Aborted by user.' -Level ERROR; exit 1 }
```

Requires `YES` in uppercase. Any other input aborts. Prevents accidental execution.

## Script Header Blast Radius Declaration

Every script's header block explicitly declares PROD RISK and BLAST RADIUS:

```bash
# ⚠ PROD RISK:  READ-ONLY — no modifications made
# BLAST RADIUS: All accounts in AWS Organization (read-only, no blast)
```

This makes risk visible at the top of every file — no hunting for it.

## SQL Destructive Naming

Destructive SQL files use `<ACTION>--<description>.sql` double-dash convention:
- `DROP--obsolete-tables.sql`
- `TRUNCATE--audit-log.sql`

The double-dash intentionally breaks SQL syntax highlighting in editors — a deliberate visual alarm.

## DRY_RUN Support

Both shared libraries support a dry-run mode:
- **Bash**: `DRY_RUN=true maybe_run aws ec2 terminate-instances ...` — logs what would run, does nothing.
- **PowerShell**: `Invoke-MaybeRun -Action { ... } -Description "..."` — respects `$script:DryRun`.
- **Jenkins**: `DRY_RUN` boolean parameter defaults to `true` (plan-only).

## Prod Gate in Jenkins

For production pipeline runs, an `input` step requires manual approval from `nuno-serrenho` before any action. See [[entities/jenkins]].

---

## Related Pages

- [[sources/secdevops-repo-framework]]
- [[concepts/everything-as-code]]
- [[concepts/pre-commit-gating]]
- [[entities/jenkins]]
- [[synthesis/secdevops-posture]]
