---
title: Web App Disaster Recovery SOP
category: source
summary: Step-by-step DR runbooks for a 2x Windows EC2 + Multi-AZ RDS MySQL + S3 media stack in ca-central-1, with PowerShell automation scripts.
tags: [dr, rds, ec2, s3, windows, powershell, runbook, ca-central-1]
sources: 1
updated: 2026-04-24
source_path: chats/Web App Disaster Recovery SOP.md
source_date: 2026-03
authors: [Operations Team]
ingested: 2026-04-24
---

# Web App Disaster Recovery SOP

**Original**: `chats/Web App Disaster Recovery SOP.md`
**Version**: 1.0 | **Date**: 2026-03-18 | **Review**: Quarterly

---

## TL;DR

Operator-executed runbooks (PowerShell + AWS.Tools module) for a production stack in `ca-central-1`: two static Windows Server EC2 instances (one per AZ) behind an ALB, Multi-AZ RDS MySQL, and media files backed up hourly to S3 with a cross-region DR bucket in `us-east-1`. No auto-scaling; recovery is manual but fully scripted.

Stack identifiers:
- EC2: `host1a-tdkc` (ca-central-1a), `host1b-tdkc` (ca-central-1b)
- AWS profile: `bluroot-td`
- Primary region: `ca-central-1` | DR region: `us-east-1`
- S3 buckets: `prod-media-backup` (primary), `prod-media-backup-dr` (DR)
- RDS identifier: `prod-db`
- DB endpoint SSM path: `/prod/database/endpoint`

---

## Recovery Objectives

| Scenario | RTO | RPO |
|----------|-----|-----|
| Single EC2 failure | 5–15 min | <1 min |
| Both EC2 instances down | 30–60 min | <1 min (code) + media from S3 |
| RDS Multi-AZ automatic failover | 1–3 min | <1 min |
| RDS data corruption (PITR) | 15–30 min | Last hourly snapshot |
| RDS snapshot restore (deletion) | 10–20 min | Last automated snapshot |
| Single AZ outage | 5–30 min | <1 min |
| Full region loss | 2–4 hours | Latest cross-region S3 + RDS snapshot export |
| Media accidentally deleted | 5–30 min | Last S3 versioned snapshot (hourly) |

---

## Runbooks Summary

### Single EC2 Instance Failure (P2)
1. Identify down instance via `Get-EC2Instance` filtering by `Environment=prod` tag.
2. Verify ALB detected failure via `Get-ELB2TargetHealth`.
3. **Option A (reboot)**: `Restart-EC2Instance -Force`; poll status until `ok/ok`.
4. **Option B (recreate)**: Capture original config → `Remove-EC2Instance` → `New-EC2Instance` with same AMI/type/subnet/SG → register with ALB via `Register-ELB2Target`.
5. Verify ALB health passes; restore media from S3 if EBS was lost.

### Both EC2 Instances Down (P1)
Similar flow; if AZ is truly down, recreate both instances in the healthy AZ. Follow with Media Restore runbook.

### Single AZ Outage (P1)
Remaining instance serves traffic; launch replacement in healthy AZ; monitor RDS Multi-AZ failover.

### Media Restore from S3 (P2)
1. List S3 objects in `prod-media-backup` to confirm availability.
2. Download to `D:\media` using `Read-S3Object` per-file or `aws s3 sync` for bulk.
3. Sync to both EC2 instances. Re-enable uploads via app endpoint.

### RDS Failover Validation (P2)
Check `Get-RDSDBInstance` for `MultiAZ=true` and `Status=available`. If stuck, trigger manual failover: `Restart-RDSDBInstance -ForceFailover $true`.

### RDS Point-in-Time Restore (P1) — RTO 15–30 min
1. Confirm corruption; identify target timestamp.
2. Stop app writes (put in read-only mode or stop EC2).
3. `Restore-RDSDBInstanceToPointInTime` to a new instance ID.
4. Validate data via MySQL query on restored endpoint.
5. Update `/prod/database/endpoint` in SSM via `Set-SSMParameter`.
6. Restart EC2 instances to pick up new endpoint.

See [[concepts/rds-point-in-time-restore]].

### RDS Restore from Snapshot (P1) — RTO 10–20 min
1. Confirm DB is deleted. List snapshots via `Get-RDSDBSnapshot`.
2. Stop EC2 instances (`Stop-EC2Instance`).
3. `Restore-RDSDBInstanceFromDBSnapshot` to new instance.
4. Update SSM endpoint parameter; restart EC2.
5. Enable deletion protection afterwards: `Edit-RDSDBInstance -DeletionProtection $true`.

### RDS Emergency Scale — Storage Exhaustion (P2)
`Edit-RDSDBInstance -AllocatedStorage <new_size> -ApplyImmediately $true`. Brief downtime on Multi-AZ (applies to standby first, then fails over).

### EC2 Compromise / Incident Response (P1)
1. `Unregister-ELB2Target` — remove from load balancer immediately.
2. Disassociate public IP (`Unregister-EC2Address`).
3. Move to `forensics-isolation` security group (`Edit-EC2InstanceAttribute`).
4. Snapshot all EBS volumes (`New-EC2Snapshot`) before termination — evidence preservation.
5. Review CloudTrail (`Get-CTEvent`), GuardDuty findings (`Get-GDFinding`).
6. Terminate (do not reboot): `Remove-EC2Instance`. Launch clean replacement.
7. Check healthy instance for lateral movement via Windows Security Event Log.

---

## Automation Scripts

### media-sync-to-s3.ps1 (hourly, Windows Scheduled Task)
Syncs `D:\media` → `s3://prod-media-backup` (STANDARD) → `s3://prod-media-backup-dr` (STANDARD_IA, us-east-1). Non-fatal if DR sync fails.

### dr-preflight-check.ps1 (weekly, Monday 08:00)
Validates: EC2 running state, ALB target health, RDS Multi-AZ enabled, backup retention ≥30d, latest automated snapshot age, S3 sync recency (<2h). Exits non-zero on any error.

### backup-verify.ps1 (weekly)
Checks automated RDS snapshot age (threshold: 26h), primary S3 object count + last-modified, DR bucket object count.

### dr-drill.ps1 (quarterly)
Full DR drill: creates manual RDS snapshot → restores to test instance → validates connectivity → downloads S3 sample → cleans up test resources.

---

## Communication & Escalation

| Severity | Response | Action |
|----------|----------|--------|
| P1 (data loss / system down) | <15 min | Exec summary Slack + email; execute runbook |
| P2 (partial outage) | <30 min | Slack + ops team |
| P3 (degraded / one instance) | <1 hour | Monitor; escalate if needed |

Post-incident report template: Timeline → Root Cause → Impact → Remediation Steps → Action Items → Prevention.

---

## Related Pages

- [[entities/bluerush]]
- [[concepts/disaster-recovery]]
- [[concepts/rds-point-in-time-restore]]
- [[concepts/zero-secrets-in-repo]]
- [[synthesis/dr-and-resilience-strategy]]
