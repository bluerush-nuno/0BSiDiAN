---
title: RDS Point-in-Time Restore
category: concept
summary: PITR allows restoring an RDS instance to any second within the backup retention window. Bluerush uses it as the primary data corruption recovery path. Restore is to a new instance; swap via SSM endpoint update.
tags: [rds, dr, backup, mysql, aws, recovery]
sources: 1
updated: 2026-04-24
---

# RDS Point-in-Time Restore (PITR)

**Context**: RDS MySQL, `prod-db`, `ca-central-1`. P1 runbook. RTO 15–30 min, RPO ~5 min.

---

## How PITR Works

AWS RDS continuously backs up transaction logs in addition to daily automated snapshots. PITR lets you restore the database to any specific second within the backup retention window (up to 35 days for RDS, 30-day retention configured for Bluerush prod).

Key point: **PITR always restores to a new DB instance** — it does not overwrite the source. This protects against the restore failing partway through.

---

## Bluerush PITR Runbook (Summary)

1. **Confirm corruption** — verify the data problem exists (record count, timestamp check).
2. **Identify target timestamp** — last known good state in ISO 8601 format.
3. **Stop app writes** — put application in read-only mode or stop EC2 instances to prevent further corruption.
4. **Restore**:
   ```powershell
   Restore-RDSDBInstanceToPointInTime \
     -SourceDBInstanceIdentifier "prod-db" \
     -TargetDBInstanceIdentifier "prod-db-restored-<timestamp>" \
     -RestoreTime [DateTime]"2026-03-17T14:30:00Z" \
     -Region ca-central-1 -ProfileName bluroot-td
   ```
5. **Wait** — poll `Get-RDSDBInstance` for `Status=available` (15–30 min).
6. **Validate** — run MySQL queries on the restored endpoint to confirm data integrity.
7. **Swap endpoint** — update SSM:
   ```powershell
   Set-SSMParameter -Name "/prod/database/endpoint" -Value $RestoredEndpoint -Overwrite ...
   ```
8. **Restart EC2** — instances pick up new endpoint from SSM on restart.
9. **Monitor** — verify app health endpoint responds; check DB connection logs.

---

## Differences: PITR vs Snapshot Restore

| | PITR | Snapshot Restore |
|-|------|-----------------|
| Trigger | Data corruption / logic error | DB instance deleted |
| Granularity | To the second | To snapshot time |
| RTO | 15–30 min | 10–20 min |
| RPO | ~5 min | Last snapshot age (usually <1h) |
| PowerShell cmdlet | `Restore-RDSDBInstanceToPointInTime` | `Restore-RDSDBInstanceFromDBSnapshot` |

---

## SSM Endpoint Swap Pattern

Both PITR and snapshot restore use the same endpoint swap pattern:

```
Restored instance endpoint → Set-SSMParameter "/prod/database/endpoint"
                           → Restart-EC2Instance (app re-reads SSM at startup)
```

This decouples the application from the physical DB instance identifier. No code change needed to point at the restored DB.

---

## Pre-requisites

- `BackupRetentionPeriod` must be > 0 (configured to 30 days for Bluerush prod).
- `LatestRestorableTime` reflects the last transaction log flush — check before choosing your target timestamp.
- The restored instance will not be Multi-AZ by default — enable it post-restore if it becomes the long-term primary.

---

## Related Pages

- [[sources/web-app-dr-sop]]
- [[concepts/disaster-recovery]]
- [[concepts/zero-secrets-in-repo]]
- [[entities/bluerush]]
- [[synthesis/dr-and-resilience-strategy]]
