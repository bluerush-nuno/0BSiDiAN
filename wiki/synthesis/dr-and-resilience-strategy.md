---
title: DR and Resilience Strategy
category: synthesis
summary: End-to-end resilience architecture for the Bluerush web app stack — RTO/RPO analysis, backup coverage, current gaps, and prioritized improvement path.
tags: [dr, resilience, aws, rds, ec2, s3, synthesis]
sources: 1
updated: 2026-04-24
---

# Bluerush DR and Resilience Strategy

A synthesis of [[sources/web-app-dr-sop]] — the disaster recovery posture for the Bluerush web application running in `ca-central-1`.

---

## Stack Overview

```
ca-central-1
├── ca-central-1a: host1a-tdkc (Windows EC2) + RDS primary
├── ca-central-1b: host1b-tdkc (Windows EC2) + RDS standby (Multi-AZ)
├── ALB: distributes traffic across both EC2 instances
└── S3: prod-media-backup (primary media backup)

us-east-1 (DR region)
└── S3: prod-media-backup-dr (STANDARD_IA, hourly replication from primary)
```

---

## Resilience Coverage by Tier

### Compute (EC2)

| Scenario | Coverage | Gap |
|----------|----------|-----|
| Single instance failure | ALB continues on healthy instance; P2 runbook | Manual remediation required |
| Both instances down | P1 runbook; recreate in healthy AZ | 30–60 min RTO; no auto-scaling |
| AZ outage | Remaining instance serves; replace in healthy AZ | Media re-sync required |
| Region loss | Manual: provision EC2 in us-east-1; 2–4h RTO | No standing DR EC2; no automated failover |

**Gap**: No Auto Scaling Group. Instances are static. Recovery is purely manual and scripted.

### Database (RDS MySQL Multi-AZ)

| Scenario | Coverage | RTO |
|----------|----------|-----|
| Primary AZ failure | Automatic Multi-AZ failover | 1–3 min |
| Data corruption | PITR to new instance + SSM endpoint swap | 15–30 min |
| Instance deletion | Snapshot restore + SSM swap | 10–20 min |
| Storage exhaustion | `Edit-RDSDBInstance -AllocatedStorage` | 5–15 min (brief downtime) |
| Region loss | RDS snapshot export to us-east-1 | 2–4h (no read replica) |

**Strength**: PITR + SSM endpoint swap is an elegant, decoupled recovery pattern. See [[concepts/rds-point-in-time-restore]].

**Gap**: No cross-region read replica. Regional DB loss requires restoring from an exported snapshot — slow.

### Media Files (S3)

| Scenario | Coverage | RPO |
|----------|----------|-----|
| Files deleted from EC2 | Restore from S3 `prod-media-backup` | Last hourly sync |
| S3 primary bucket loss | Restore from DR bucket `prod-media-backup-dr` (us-east-1) | Last hourly sync |
| Accidental deletion (S3) | S3 versioning enabled | Any version |
| Region loss | DR bucket in us-east-1 available | Last hourly sync |

**Strength**: Cross-region S3 replication to STANDARD_IA provides cheap, durable DR for media. Versioning protects against accidental deletion.

**Gap**: S3 Object Lock not mentioned — consider enabling for compliance-grade immutability.

---

## Validation Cadence

| Activity | Frequency | What's Tested |
|----------|-----------|--------------|
| `dr-preflight-check.ps1` | Weekly (Mon 08:00) | EC2 state, ALB health, RDS Multi-AZ, snapshot age, S3 sync |
| `backup-verify.ps1` | Weekly | Snapshot age thresholds, S3 object counts |
| `dr-drill.ps1` | Quarterly | Full PITR restore, media download from S3, cleanup |

The drill proves the runbook works end-to-end — not just that backups exist. This is the critical difference between theoretical and practiced DR.

---

## Severity Response Model

| Severity | Response time | Who executes | Channel |
|----------|--------------|-------------|---------|
| P1 — system down / data loss | <15 min | Nuno Serrenho | Slack + email |
| P2 — partial outage | <30 min | Nuno Serrenho | Slack |
| P3 — degraded / one instance | <1 hour | Monitor first | Slack update |

---

## Prioritized Improvement Path

Based on gap analysis, in priority order:

1. **Enable RDS deletion protection** (`Edit-RDSDBInstance -DeletionProtection $true`) — zero cost, prevents P1 scenario. Should already be done.
2. **Add CloudWatch alarm for `FreeStorageSpace < 10%`** — pre-empts the P2 storage exhaustion scenario.
3. **S3 Object Lock on DR bucket** — immutability for regulatory / ransomware protection.
4. **Auto Scaling Group for EC2** — eliminates the 30–60 min "both instances down" RTO; brings it to ASG replacement time (~5 min).
5. **RDS cross-region read replica (Aurora Global)** — reduces regional DB RTO from 2–4h to <1 min.
6. **Automated EC2 AMI rotation** — use `Jenkinsfile.ec2-rotation` to keep a current AMI; reduces recreate time.
7. **VPC Flow Logs** — referenced in EC2 compromise runbook as prevention action; enable on all VPCs.

---

## Integration with SecDevOps Repo

The DR SOP and the ops monorepo are tightly coupled:
- DR scripts (`dr-preflight-check.ps1`, `backup-verify.ps1`, `dr-drill.ps1`) should be checked into `ops/scripts/pwsh/dr/`.
- Media sync script (`media-sync-to-s3.ps1`) should be in `ops/scripts/pwsh/aws/s3/`.
- All scripts should follow the standard PowerShell header pattern.
- DR runbooks belong in `ops/runbooks/dr/`.

See [[synthesis/secdevops-posture]], [[sources/secdevops-repo-framework]].

---

## Related Pages

- [[sources/web-app-dr-sop]]
- [[sources/secdevops-repo-framework]]
- [[concepts/disaster-recovery]]
- [[concepts/rds-point-in-time-restore]]
- [[concepts/zero-secrets-in-repo]]
- [[concepts/sts-assume-role-pattern]]
- [[entities/bluerush]]
- [[synthesis/secdevops-posture]]
