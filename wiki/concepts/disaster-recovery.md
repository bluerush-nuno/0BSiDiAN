---
title: Disaster Recovery
category: concept
summary: Bluerush DR strategy for the web app stack: multi-AZ RDS, S3 cross-region media backup, Windows EC2 manual runbooks, and quarterly drills.
tags: [dr, resilience, rds, ec2, s3, rto, rpo, ca-central-1]
sources: 1
updated: 2026-04-24
---

# Disaster Recovery

**Applies to**: Bluerush web app — 2x Windows EC2 + Multi-AZ RDS MySQL + S3 media, `ca-central-1`

---

## Design Principle

> Automated backups (RDS snapshots, S3 media sync); manual runbooks for instance/database failures. The operator is the execution engine — procedures are step-by-step with PowerShell, not GUI walkthroughs.

---

## RTO/RPO Targets

| Scenario | RTO | RPO |
|----------|-----|-----|
| Single EC2 failure | 5–15 min | <1 min |
| Both EC2 instances down | 30–60 min | <1 min code + media from S3 |
| RDS Multi-AZ auto failover | 1–3 min | <1 min |
| RDS data corruption (PITR) | 15–30 min | Last hourly snapshot |
| RDS deletion | 10–20 min | Last automated snapshot |
| Single AZ outage | 5–30 min | <1 min |
| Full region loss | 2–4 hours | S3 DR + RDS snapshot export |
| Media deleted | 5–30 min | Last hourly S3 sync |

---

## Backup Architecture

### EC2
- **No automated AMI backup** — instances are static, code is in the ops repo. If lost, recreate from latest AMI with same config parameters.
- **EBS**: encrypted, but not separately snapshotted on a schedule (as of v1.0 SOP).

### RDS MySQL
- **Multi-AZ**: standby in opposite AZ. Auto failover in 1–3 minutes.
- **Automated snapshots**: daily, 30-day retention.
- **PITR**: continuous transaction log backup — can restore to any point within retention window.
- **Manual snapshots**: created by `Jenkinsfile.rds-snapshot` pipeline and quarterly DR drill.
- **Deletion protection**: should be enabled (`Edit-RDSDBInstance -DeletionProtection $true`).

### Media Files (S3)
- Local media at `D:\media` on each EC2 instance.
- **Primary backup**: hourly sync to `s3://prod-media-backup` (ca-central-1, STANDARD class).
- **DR backup**: replicated from primary to `s3://prod-media-backup-dr` (us-east-1, STANDARD_IA).
- **S3 versioning**: enabled on primary bucket — can restore a specific version of any file.
- Sync script: `media-sync-to-s3.ps1`, runs as Windows Scheduled Task every hour.

---

## Recovery Operations

All recovery uses PowerShell + AWS.Tools module (never AWS CLI) per [[entities/bluerush]] conventions.

Key cmdlets:
- `Get-EC2Instance`, `Restart-EC2Instance`, `New-EC2Instance`, `Remove-EC2Instance`
- `Get-ELB2TargetHealth`, `Register-ELB2Target`, `Unregister-ELB2Target`
- `Get-RDSDBInstance`, `Restore-RDSDBInstanceToPointInTime`, `Restore-RDSDBInstanceFromDBSnapshot`
- `Get-S3Object`, `Read-S3Object`
- `Set-SSMParameter` — endpoint swap after DB restore
- `Get-CTEvent`, `Get-GDFinding` — forensic investigation

---

## Validation Cadence

| Script | Frequency | Purpose |
|--------|-----------|---------|
| `dr-preflight-check.ps1` | Weekly (Mon 08:00) | Validate EC2, ALB, RDS Multi-AZ, snapshot age, S3 sync |
| `backup-verify.ps1` | Weekly | Snapshot age, S3 object count, DR bucket |
| `dr-drill.ps1` | Quarterly | Full PITR restore + media recovery test + cleanup |

---

## Open Gaps (as of v1.0)

- No automated EC2 AMI snapshots — relies on static AMI at launch.
- No full cross-region EC2 DR automation — region loss requires manual provisioning (2–4 hour RTO).
- No RDS cross-region read replica for faster regional failover.

See [[synthesis/dr-and-resilience-strategy]] for the full posture assessment.

---

## Related Pages

- [[sources/web-app-dr-sop]]
- [[concepts/rds-point-in-time-restore]]
- [[concepts/zero-secrets-in-repo]]
- [[entities/bluerush]]
- [[synthesis/dr-and-resilience-strategy]]
