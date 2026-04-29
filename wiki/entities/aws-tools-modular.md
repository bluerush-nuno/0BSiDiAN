---
title: AWS.Tools.* (Modular)
category: entity
summary: Per-service AWS SDK modules for PowerShell. Bluerush uses these exclusively — the monolithic AWSPowerShell module is explicitly forbidden.
tags: [aws, powershell, sdk, modules]
sources: 2
updated: 2026-04-29
---

# AWS.Tools.* — Modular AWS SDK for PowerShell

**Type**: AWS SDK packaging for PowerShell
**Installer**: `AWS.Tools.Installer` → `Install-AWSToolsModule AWS.Tools.<Service>`
**Forbidden alternative**: `AWSPowerShell` (the monolithic module — slow load, huge memory footprint, mixes service surfaces)

---

## Why modular only

- **Selective install**: Only the service modules actually needed (e.g., `AWS.Tools.EC2`, `AWS.Tools.SimpleSystemsManagement`, `AWS.Tools.SecurityToken`, `AWS.Tools.Organizations`).
- **Faster import**: Loading three small modules is much faster than loading one ~900MB monolith.
- **Cleaner surface**: Tab completion and `Get-Command` aren't flooded with irrelevant cmdlets.
- **Updateability**: Per-service version pinning; you can upgrade EC2 without touching IAM.

## Standard install

```powershell
Install-Module -Name AWS.Tools.Installer -Force -AllowClobber
Install-AWSToolsModule -Name @(
    'AWS.Tools.EC2',
    'AWS.Tools.S3',
    'AWS.Tools.IdentityManagement',
    'AWS.Tools.SecurityToken',
    'AWS.Tools.Organizations',
    'AWS.Tools.SimpleSystemsManagement',
    'AWS.Tools.SecretsManager',
    'AWS.Tools.RDS'
) -Force
```

`Tools/Install-Dependencies.ps1` in the [[sources/pscodebase-scaffold]] codifies this.

## Bluerush conventions

- Always pass `-Region` and `-ProfileName` explicitly — never rely on `Set-DefaultAWSRegion` or `AWS_PROFILE`.
- Multi-account: `Get-ORGAccountList` + `Use-STSRole` + `Set-AWSCredential` (see [[concepts/sts-assume-role-pattern]]).
- Pass typed objects through pipelines; convert to JSON only at boundaries.

## Common cmdlets in use

| Cmdlet | Service module | Used for |
|---|---|---|
| `Get-ORGAccountList` | `AWS.Tools.Organizations` | Multi-account enumeration |
| `Use-STSRole` | `AWS.Tools.SecurityToken` | Cross-account role assumption |
| `Set-AWSCredential` | `AWS.Tools.Common` | Set session credentials |
| `Get-SSMParameter` / `Get-SSMParameterValue` | `AWS.Tools.SimpleSystemsManagement` | Pull config/secret paths |
| `Get-SECSecretValue` | `AWS.Tools.SecretsManager` | Pull rotated secrets |
| `Get-EC2Instance` | `AWS.Tools.EC2` | Instance inventory |
| `Restore-RDSDBInstanceToPointInTime` | `AWS.Tools.RDS` | DR restore (see [[concepts/rds-point-in-time-restore]]) |

## Related Pages

- [[sources/pscodebase-scaffold]], [[sources/ps-module-template-plan]]
- [[sources/web-app-dr-sop]]
- [[concepts/sts-assume-role-pattern]], [[concepts/zero-secrets-in-repo]]
- [[entities/aws-organizations]]
