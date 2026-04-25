---
title: Jenkins
category: entity
summary: Jenkins CI server used by Bluerush for pipeline-as-code; runs on EC2 agents with instance profiles — no static credentials stored.
tags: [jenkins, cicd, pipeline, groovy]
sources: 1
updated: 2026-04-24
---

# Jenkins

**Role**: CI/CD orchestrator for Bluerush ops pipelines
**Pattern**: Shared Library (`bluerush-ops-shared`) registered from `jenkins/shared-library/` in the ops monorepo
**Agent auth**: EC2 instance profile → STS assume-role — no long-lived credentials

---

## Shared Library

Located at `jenkins/shared-library/`. Key vars (callable as pipeline steps):

| Step | Purpose |
|------|---------|
| `withAWSRole` | Assumes a deploy role via STS; injects temp creds as env vars |
| `awsDeploy` | Standardized deploy step |
| `notifySlack` | Posts build status to `#ops-alerts` or `#ops-deploys` |

Loaded in Jenkinsfiles via `@Library('bluerush-ops-shared') _`.

## Pipeline Patterns

- `ENVIRONMENT` parameter: `nonprod` or `prod` — controls which `iac/environments/` directory is used.
- `DRY_RUN` parameter: defaults to `true` (plan-only). Apply requires explicit `false`.
- **Prod gate**: `input` step with `submitter: 'nuno-serrenho'` before any prod action.
- Post stages: `notifySlack` on success/failure; cleanup removes `tfplan` files.

## Credential Model

No credentials stored in Jenkins. Flow:
1. EC2 agent has an instance profile with minimum permissions.
2. `withAWSRole` calls STS `AssumeRole` to get a deploy role token.
3. Token injected as `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN`.
4. Token expires after the pipeline stage.

See [[concepts/sts-assume-role-pattern]], [[concepts/zero-secrets-in-repo]].

## Jenkins Configuration as Code (JCasC)

Config YAML at `config/jenkins/casc/`. Enables reproducible Jenkins configuration without ClickOps.

## Pipelines Defined

| Pipeline | Path | Purpose |
|----------|------|---------|
| `Jenkinsfile.infra-deploy` | `jenkins/pipelines/deploy/` | OpenTofu plan + apply |
| `Jenkinsfile.app-deploy` | `jenkins/pipelines/deploy/` | Application deployment |
| `Jenkinsfile.rds-snapshot` | `jenkins/pipelines/backup/` | RDS manual snapshot |
| `Jenkinsfile.cis-scan` | `jenkins/pipelines/compliance/` | CIS compliance scan |
| `Jenkinsfile.rds-patching` | `jenkins/pipelines/maintenance/` | RDS minor version upgrade |
| `Jenkinsfile.ec2-rotation` | `jenkins/pipelines/maintenance/` | EC2 AMI rotation |

---

## Related Pages

- [[sources/secdevops-repo-framework]]
- [[entities/opentofu]]
- [[concepts/sts-assume-role-pattern]]
- [[concepts/zero-secrets-in-repo]]
- [[synthesis/secdevops-posture]]
