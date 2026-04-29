---
title: STS Assume-Role Pattern
category: concept
summary: EC2 instance profiles provide the initial identity; STS AssumeRole grants scoped, temporary credentials for cross-account or elevated operations. No static credentials anywhere.
tags: [aws, iam, sts, security, credentials, multi-account]
sources: 3
updated: 2026-04-29
---

# STS Assume-Role Pattern

The credential model used throughout Bluerush ops: **instance profile → STS → scoped temporary token**. No IAM user access keys, no static credentials stored in Jenkins, no `.aws/credentials` files committed.

---

## The Flow

```
EC2 agent (instance profile)
    └── sts:AssumeRole → CICDDeployRole (target account)
            └── AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN (env vars, scoped to stage)
```

1. The EC2 Jenkins agent has an **instance profile** with a minimal IAM role — only `sts:AssumeRole` on specific target roles.
2. The pipeline calls `withAWSRole(roleArn: env.DEPLOY_ROLE, region: ...)` (Groovy shared library step).
3. STS issues temporary credentials (default 1 hour, auto-expire).
4. Credentials are injected as environment variables for the duration of the pipeline stage.
5. Credentials expire automatically — no revocation needed post-run.

## Cross-Account Audit Pattern (PowerShell)

```powershell
# Invoke-MultiAccountAudit.ps1 — Loops Get-ORGAccountList + STS assume per account
foreach ($Account in Get-ORGAccountList) {
    # Assume OrgAuditRole in each member account
    # Run audit; temp creds scope to one account at a time
}
```

This is how `scripts/pwsh/aws/iam/Invoke-MultiAccountAudit.ps1` and `Get-AllAccountResources.ps1` work.

## Why This Matters

- **No credential sprawl**: No IAM users to rotate, no static keys to leak.
- **Least privilege**: Deploy role has only the permissions needed for that pipeline.
- **Audit trail**: CloudTrail records each `AssumeRole` call — who assumed what, when.
- **Auto-expiry**: Even if a token leaked, it expires within the session duration.

## Roles in Use

| Role ARN pattern | Assumed by | Purpose |
|-----------------|-----------|---------|
| `arn:aws:iam::<account>:role/CICDDeployRole` | Jenkins EC2 agent | Deploy operations |
| `arn:aws:iam::<account>:role/OrgAuditRole` | Management EC2 | Read-only org-wide audit |

## DR Context

The DR runbook PowerShell scripts all use `-ProfileName bluroot-td` — a named AWS profile on the operator's machine, not a static key. The SSM cmdlet `Set-SSMParameter` updates the `/prod/database/endpoint` path after a restore. See [[sources/web-app-dr-sop]], [[concepts/zero-secrets-in-repo]].

## Module-level Pattern

The [[sources/pscodebase-scaffold]] codifies the operational form for use inside scripts:

```powershell
try {
    $creds = (Use-STSRole -RoleArn $RoleArn -RoleSessionName $session -Region $Region).Credentials
    Set-AWSCredential -AccessKey $creds.AccessKeyId -SecretKey $creds.SecretAccessKey `
                      -SessionToken $creds.SessionToken
    # ... do work ...
}
finally {
    Clear-AWSCredential
}
```

The `finally` block matters — it scrubs the session credential even if the work block throws.

---

## Related Pages

- [[sources/secdevops-repo-framework]]
- [[sources/web-app-dr-sop]]
- [[sources/pscodebase-scaffold]]
- [[entities/jenkins]]
- [[entities/aws-organizations]], [[entities/aws-tools-modular]]
- [[concepts/zero-secrets-in-repo]]
- [[synthesis/secdevops-posture]]
