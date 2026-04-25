# Ops Repository Framework
## SecDevOps Monorepo — Multi-Account AWS · Jenkins · Ansible · OpenTofu · Bash/PowerShell · MySQL

---

## Design Principles

1. **Everything-as-code** — scripts, pipelines, runbooks, SQL, config. If it runs in prod, it lives here.
2. **No secrets in the repo** — ever. SSM Parameter paths or Secrets Manager ARNs as placeholders only.
3. **Environment isolation is structural** — `prod/` and `nonprod/` are sibling directories, never flags/variables.
4. **Every script is self-documenting** — standard header block required (see conventions below).
5. **Pre-commit gates, not post-commit regret** — secrets detection, lint, shellcheck run before push.
6. **Blast radius is always visible** — destructive scripts live in a `_destructive/` subfolder and require confirmation prompts.

---

## Repository Structure

```
ops/
│
├── .gitignore                        # Stack-specific ignores (see below)
├── .pre-commit-config.yaml           # detect-secrets, shellcheck, ansible-lint, tflint
├── .editorconfig                     # Consistent indent/EOL across editors
├── README.md                         # Repo overview + onboarding quickstart
├── CONTRIBUTING.md                   # Conventions, PR rules, naming standards
│
├── ansible/                          # Config management, ad-hoc ops, EC2 hardening
│   ├── ansible.cfg                   # Repo-scoped config (roles_path, inventory, etc.)
│   ├── inventories/
│   │   ├── prod/
│   │   │   ├── aws_ec2.yml           # Dynamic inventory (aws_ec2 plugin)
│   │   │   └── group_vars/
│   │   │       ├── all.yml           # Non-sensitive vars (region, tags, paths)
│   │   │       └── webservers.yml
│   │   └── nonprod/
│   │       ├── aws_ec2.yml
│   │       └── group_vars/
│   │           └── all.yml
│   ├── playbooks/
│   │   ├── ec2-hardening.yml         # CIS L1 hardening baseline
│   │   ├── jenkins-agent-setup.yml
│   │   ├── rds-maintenance.yml
│   │   └── _destructive/             # Playbooks that terminate/wipe — extra gate required
│   │       └── ec2-terminate.yml
│   ├── roles/
│   │   ├── common/                   # Applied to every host (syslog, auditd, etc.)
│   │   │   ├── tasks/main.yml
│   │   │   ├── handlers/main.yml
│   │   │   ├── defaults/main.yml
│   │   │   └── templates/
│   │   ├── cis-hardening/            # CIS AWS L1 controls
│   │   ├── aws-ssm-agent/            # Ensure SSM agent installed + running
│   │   ├── cloudwatch-agent/
│   │   └── mysql-client/
│   └── collections/
│       └── requirements.yml          # ansible-galaxy collection deps
│
├── iac/                              # OpenTofu (Terraform-compatible)
│   ├── _shared/                      # Cross-env data sources, locals, provider config
│   │   └── providers.tf
│   ├── modules/                      # Reusable, parameterized modules
│   │   ├── vpc/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── README.md             # Required: inputs, outputs, usage example
│   │   ├── ec2-asg/
│   │   ├── rds-aurora/
│   │   ├── iam-role/
│   │   └── s3-secure/                # Bucket with forced encryption, versioning, logging
│   └── environments/                 # Root modules per environment (never share state)
│       ├── prod/
│       │   ├── main.tf               # Module calls only — no resource blocks here
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   ├── backend.tf            # S3 backend + DynamoDB lock
│       │   └── terraform.tfvars      # Non-sensitive vars; secrets via SSM data sources
│       ├── nonprod/
│       │   └── ...
│       └── mgmt/                     # Management/tooling account (Jenkins, logging, etc.)
│           └── ...
│
├── jenkins/                          # All pipeline-as-code content
│   ├── shared-library/               # If using Jenkins Shared Library pattern
│   │   ├── vars/                     # Global vars (callable as steps in Jenkinsfiles)
│   │   │   ├── awsDeploy.groovy
│   │   │   ├── notifySlack.groovy
│   │   │   └── withAWSRole.groovy    # STS assume-role wrapper
│   │   └── src/
│   │       └── com/bluerush/         # Package path
│   │           └── AWSUtils.groovy
│   ├── pipelines/                    # Individual Jenkinsfiles per workflow
│   │   ├── deploy/
│   │   │   ├── Jenkinsfile.app-deploy
│   │   │   └── Jenkinsfile.infra-deploy
│   │   ├── backup/
│   │   │   └── Jenkinsfile.rds-snapshot
│   │   ├── compliance/
│   │   │   └── Jenkinsfile.cis-scan
│   │   └── maintenance/
│   │       ├── Jenkinsfile.rds-patching
│   │       └── Jenkinsfile.ec2-rotation
│   └── config/
│       └── job-dsl/                  # Job DSL seed scripts (if using Job DSL plugin)
│
├── scripts/                          # Imperative automation — Bash and PowerShell
│   ├── bash/
│   │   ├── lib/                      # Sourced function libraries (not run directly)
│   │   │   ├── common.sh             # Logging, error handling, confirmation prompts
│   │   │   ├── aws.sh                # AWS CLI wrappers (profile/region injection)
│   │   │   └── db.sh                 # MySQL client helpers
│   │   ├── aws/
│   │   │   ├── ec2/
│   │   │   │   ├── list-stale-snapshots.sh
│   │   │   │   └── rotate-launch-template.sh
│   │   │   ├── iam/
│   │   │   │   ├── audit-unused-roles.sh
│   │   │   │   └── find-wildcard-policies.sh
│   │   │   ├── rds/
│   │   │   │   ├── take-snapshot.sh
│   │   │   │   └── list-public-snapshots.sh    # ⚠ security audit
│   │   │   └── org/
│   │   │       └── assume-role-all-accounts.sh
│   │   ├── db/
│   │   │   ├── mysql-health-check.sh
│   │   │   └── export-schema.sh
│   │   ├── sys/
│   │   │   ├── disk-usage-alert.sh
│   │   │   └── auditd-review.sh
│   │   └── _destructive/             # ⛔ Scripts with irreversible side effects
│   │       ├── purge-old-snapshots.sh
│   │       └── force-terminate-ec2.sh
│   │
│   └── pwsh/
│       ├── lib/                      # Dot-sourced modules
│       │   ├── Common.psm1           # Logging, error handling, dry-run flag
│       │   ├── AWSHelpers.psm1       # AWS.Tools wrappers with explicit -ProfileName/-Region
│       │   └── DBHelpers.psm1
│       ├── aws/
│       │   ├── ec2/
│       │   │   ├── Get-StaleSnapshots.ps1
│       │   │   └── Set-InstanceTag.ps1
│       │   ├── iam/
│       │   │   ├── Find-WildcardPolicies.ps1
│       │   │   └── Invoke-MultiAccountAudit.ps1   # Loops Get-ORGAccountList + STS assume
│       │   ├── rds/
│       │   │   └── New-RDSSnapshot.ps1
│       │   └── org/
│       │       └── Get-AllAccountResources.ps1
│       ├── windows/                  # Windows/WinRM-targeted scripts
│       │   └── Configure-WinRM.ps1
│       └── _destructive/             # ⛔ Same rule as bash/_destructive
│           └── Remove-OrphanedEBSVolumes.ps1
│
├── sql/                              # MySQL scripts (structured, versioned)
│   ├── migrations/                   # Sequential, never modified after merge
│   │   ├── V001__initial_schema.sql
│   │   ├── V002__add_audit_columns.sql
│   │   └── V003__index_optimisation.sql
│   ├── procedures/                   # Stored procedures and functions
│   │   ├── sp_audit_log_cleanup.sql
│   │   └── fn_age_days.sql
│   ├── maintenance/                  # Ops tasks: OPTIMIZE, ANALYZE, user mgmt
│   │   ├── optimize-tables.sql
│   │   ├── check-slow-queries.sql
│   │   └── create-readonly-user.sql
│   ├── reports/                      # Ad-hoc, non-destructive reporting queries
│   │   └── active-connections.sql
│   └── _destructive/                 # Drops, truncates, purges — needs PR approval
│       ├── DROP--obsolete-tables.sql # Naming convention: action--description.sql
│       └── TRUNCATE--audit-log.sql
│
├── config/                           # Non-secret configuration files
│   ├── aws/
│   │   ├── config.template           # ~/.aws/config template — NEVER credentials
│   │   └── cli-aliases               # AWS CLI command aliases
│   ├── nginx/
│   ├── jenkins/
│   │   └── casc/                     # Jenkins Configuration as Code (JCasC) YAML
│   └── ssm-parameter-inventory.md   # Catalogue of SSM paths (no values, just paths+types)
│
├── runbooks/                         # Operational runbooks — Markdown, git-versioned
│   ├── _template.md                  # Copy this to create a new runbook
│   ├── incidents/
│   │   ├── IAM-credential-compromise.md
│   │   ├── EC2-instance-compromise.md
│   │   ├── RDS-snapshot-exfiltration.md
│   │   ├── S3-public-exposure.md
│   │   └── GuardDuty-severity7-triage.md
│   ├── maintenance/
│   │   ├── RDS-minor-version-upgrade.md
│   │   ├── EC2-AMI-rotation.md
│   │   └── Jenkins-plugin-update.md
│   ├── dr/
│   │   ├── RDS-point-in-time-restore.md
│   │   └── multi-account-failover.md
│   └── onboarding/
│       ├── new-aws-account-setup.md
│       └── dev-environment-setup.md
│
└── docs/
    ├── adr/                          # Architecture Decision Records
    │   ├── ADR-001-iac-tooling-opentofu.md
    │   ├── ADR-002-secrets-ssm-vs-sm.md
    │   └── ADR-003-monorepo-vs-polyrepo.md
    └── diagrams/                     # draw.io XML or PlantUML source — not PNGs
        ├── multi-account-network.drawio
        └── cicd-pipeline.puml
```

---

## Security Guardrails

### .gitignore — Core Exclusions

```gitignore
# Secrets & credentials — NEVER commit these
**/.env
**/.env.*
**/terraform.tfvars.local
**/*.tfstate
**/*.tfstate.backup
**/.terraform/
**/*.pem
**/*.key
**/*.p12
**/*.pfx
**/*_rsa
**/*_ed25519
**/credentials
**/.aws/credentials

# Ansible vault password files
**/.vault_pass
**/*.vault

# Python
__pycache__/
*.pyc
.venv/

# Node (if any tooling)
node_modules/

# IDE
.idea/
.vscode/settings.json      # Allow .vscode/extensions.json — block settings
*.swp

# OS
.DS_Store
Thumbs.db

# Temp / generated
/tmp/
*.log
*.bak
```

### .pre-commit-config.yaml

```yaml
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.5.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']

  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.10.0.1
    hooks:
      - id: shellcheck
        files: scripts/bash/.*\.sh$
        args: ['-e', 'SC1091']    # Suppress 'not following source' — we handle that

  - repo: https://github.com/ansible/ansible-lint
    rev: v24.2.0
    hooks:
      - id: ansible-lint
        files: ansible/.*\.(yml|yaml)$

  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.92.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
        args: ['--args=-no-color']

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-merge-conflict
      - id: check-yaml
      - id: check-json
      - id: no-commit-to-branch
        args: ['--branch', 'main']
```

---

## Naming Conventions

### Scripts (Bash)
```
<verb>-<noun>[-<qualifier>].sh
audit-iam-policies.sh
rotate-ec2-keypairs.sh
list-stale-snapshots-us-east-1.sh
```

### Scripts (PowerShell)
```
<ApprovedVerb>-<Noun>[<Qualifier>].ps1  ← PowerShell approved verbs
Get-StaleSnapshots.ps1
Invoke-MultiAccountAudit.ps1
Remove-OrphanedEBSVolumes.ps1
```

### SQL (Migrations)
```
V<seq>__<description_with_underscores>.sql  ← Flyway-compatible (even if not using Flyway)
V001__initial_schema.sql
V012__add_created_at_to_audit_log.sql
```

### SQL (Destructive)
```
<ACTION>--<description>.sql   ← Double-dash deliberately breaks syntax highlighting,
DROP--obsolete_sessions.sql      forces visual attention
TRUNCATE--temp_uploads.sql
```

### Ansible Playbooks
```
<target>-<action>.yml
ec2-hardening.yml
rds-snapshot-verify.yml
jenkins-agent-provision.yml
```

### Runbooks
```
<SERVICE>-<incident-type>.md    ← Matches IR template header
IAM-credential-compromise.md
RDS-snapshot-exfiltration.md
```

---

## Required Script Header Blocks

### Bash
```bash
#!/usr/bin/env bash
# =============================================================================
# SCRIPT:  audit-iam-policies.sh
# PURPOSE: Scan all accounts in Org for policies with wildcard actions/resources
# AUTHOR:  Nuno Serrenho
# CREATED: 2025-04-22
# VERSION: 1.0.0
#
# ⚠ PROD RISK:  READ-ONLY — no modifications made
# BLAST RADIUS: All accounts in AWS Organization (read-only, no blast)
# PREREQS:
#   - AWS CLI configured with Org read access
#   - jq installed
#   - Assumes OrgAuditRole exists in each member account
#
# USAGE:
#   ./audit-iam-policies.sh [--profile <profile>] [--region <region>]
#   ./audit-iam-policies.sh --profile org-master --region us-east-1
#
# OUTPUT: JSON to stdout, errors to stderr
# =============================================================================
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/aws.sh"
```

### PowerShell
```powershell
<#
.SYNOPSIS
    Scans all Org accounts for IAM policies with wildcard actions or resources.

.DESCRIPTION
    Loops through all active accounts via Get-ORGAccountList, assumes OrgAuditRole
    in each, and outputs findings as structured objects.

.PARAMETER ProfileName
    AWS named profile with Org read access. Required.

.PARAMETER Region
    AWS region for STS calls. Defaults to us-east-1.

.PARAMETER DryRun
    If set, shows what would be reported without making any changes.
    (This script is read-only; DryRun is for pipeline compatibility.)

.EXAMPLE
    .\Find-WildcardPolicies.ps1 -ProfileName org-master -Region us-east-1

.NOTES
    ⚠ PROD RISK:  READ-ONLY — no modifications made
    BLAST RADIUS: None (audit only)
    CREATED:      2025-04-22
    AUTHOR:       Nuno Serrenho
    PREREQS:      AWS.Tools.Organizations, AWS.Tools.IdentityManagement
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$ProfileName,
    [string]$Region = 'us-east-1',
    [switch]$DryRun
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/../lib/Common.psm1"
. "$PSScriptRoot/../lib/AWSHelpers.psm1"
```

### SQL Migration
```sql
-- =============================================================================
-- MIGRATION: V012__add_audit_columns_to_users.sql
-- PURPOSE:   Add created_at, updated_at, created_by to users table
-- AUTHOR:    Nuno Serrenho
-- DATE:      2025-04-22
-- JIRA:      OPS-142
--
-- ⚠ REVERSIBLE: Yes — see V013__rollback_audit_columns.sql
-- BLAST RADIUS: users table — low risk, DDL only (no data loss)
-- TARGET:    All environments (run nonprod first, prod after sign-off)
-- =============================================================================

SET FOREIGN_KEY_CHECKS = 0;
-- ... migration body ...
SET FOREIGN_KEY_CHECKS = 1;
```

---

## Bash Shared Library Pattern (`scripts/bash/lib/common.sh`)

```bash
#!/usr/bin/env bash
# common.sh — Source this, don't execute it
# Usage: source "$(dirname "$0")/../lib/common.sh"

# ---------- Logging ----------
readonly LOG_TIMESTAMP_FMT='%Y-%m-%dT%H:%M:%S%z'
log_info()  { echo "[$(date +"$LOG_TIMESTAMP_FMT")] [INFO]  $*" >&2; }
log_warn()  { echo "[$(date +"$LOG_TIMESTAMP_FMT")] [WARN]  $*" >&2; }
log_error() { echo "[$(date +"$LOG_TIMESTAMP_FMT")] [ERROR] $*" >&2; }

# ---------- Confirmation gate for destructive ops ----------
confirm_destructive() {
    local msg="${1:-This operation is destructive and cannot be undone.}"
    local env_hint="${2:-}"
    log_warn "$msg"
    [[ -n "$env_hint" ]] && log_warn "Target environment: $env_hint"
    read -r -p "Type YES (uppercase) to continue: " response
    [[ "$response" == "YES" ]] || { log_error "Aborted by user."; exit 1; }
}

# ---------- Dry-run support ----------
DRY_RUN=${DRY_RUN:-false}
maybe_run() {
    # Usage: maybe_run aws ec2 terminate-instances ...
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would run: $*"
    else
        "$@"
    fi
}

# ---------- Require tools ----------
require_cmd() {
    for cmd in "$@"; do
        command -v "$cmd" &>/dev/null || { log_error "Required command not found: $cmd"; exit 1; }
    done
}

# ---------- Cleanup trap ----------
_TMP_FILES=()
register_tmp() { _TMP_FILES+=("$1"); }
cleanup() { rm -f "${_TMP_FILES[@]}" 2>/dev/null || true; }
trap cleanup EXIT
```

---

## PowerShell Shared Module (`scripts/pwsh/lib/Common.psm1`)

```powershell
# Common.psm1 — dot-source this in all scripts
# . "$PSScriptRoot/../lib/Common.psm1"

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR')][string]$Level = 'INFO'
    )
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz'
    $line = "[$ts] [$Level]  $Message"
    if ($Level -eq 'ERROR') { Write-Error $line }
    else                    { Write-Host  $line }
}

function Confirm-Destructive {
    param(
        [string]$Message = 'This operation is destructive and cannot be undone.',
        [string]$TargetEnv = ''
    )
    Write-Log $Message -Level WARN
    if ($TargetEnv) { Write-Log "Target environment: $TargetEnv" -Level WARN }
    $response = Read-Host 'Type YES (uppercase) to continue'
    if ($response -ne 'YES') {
        Write-Log 'Aborted by user.' -Level ERROR
        exit 1
    }
}

function Invoke-MaybeRun {
    # Respects $script:DryRun flag
    param([scriptblock]$Action, [string]$Description)
    if ($script:DryRun) {
        Write-Log "[DRY-RUN] Would execute: $Description" -Level INFO
    } else {
        & $Action
    }
}

Export-ModuleMember -Function Write-Log, Confirm-Destructive, Invoke-MaybeRun
```

---

## Jenkins Pipeline Pattern (Groovy)

### Jenkinsfile with STS assume-role — no long-lived credentials on agents

```groovy
// pipelines/deploy/Jenkinsfile.infra-deploy
// ⚠ PROD RISK: This pipeline can deploy to production. Gate enforced below.

@Library('bluerush-ops-shared') _   // Points to jenkins/shared-library/

pipeline {
    agent { label 'aws-linux' }     // EC2 agent with instance profile — no static creds

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['nonprod', 'prod'], description: 'Target environment')
        booleanParam(name: 'DRY_RUN', defaultValue: true, description: 'Plan only, no apply')
    }

    environment {
        AWS_REGION     = 'us-east-1'
        DEPLOY_ROLE    = "arn:aws:iam::${ACCOUNT_ID}:role/CICDDeployRole"
        TF_CLI_ARGS    = '-no-color'
    }

    stages {
        stage('Prod Gate') {
            when { expression { params.ENVIRONMENT == 'prod' } }
            steps {
                input message: 'Deploying to PRODUCTION. Confirm to proceed.',
                      submitter: 'nuno-serrenho'
            }
        }

        stage('Assume Role') {
            steps {
                script {
                    // Pull creds from instance profile → assume deploy role
                    // No credentials stored in Jenkins
                    withAWSRole(roleArn: env.DEPLOY_ROLE, region: env.AWS_REGION) {
                        env.AWS_ACCESS_KEY_ID     = AWS_CREDS.accessKeyId
                        env.AWS_SECRET_ACCESS_KEY = AWS_CREDS.secretAccessKey
                        env.AWS_SESSION_TOKEN     = AWS_CREDS.sessionToken
                    }
                }
            }
        }

        stage('OpenTofu Plan') {
            steps {
                dir("iac/environments/${params.ENVIRONMENT}") {
                    sh 'tofu init -input=false'
                    sh 'tofu plan -out=tfplan -input=false'
                }
            }
        }

        stage('OpenTofu Apply') {
            when { expression { !params.DRY_RUN } }
            steps {
                dir("iac/environments/${params.ENVIRONMENT}") {
                    sh 'tofu apply -input=false tfplan'
                }
            }
        }
    }

    post {
        failure  { notifySlack(channel: '#ops-alerts',  status: 'FAILED',  env: params.ENVIRONMENT) }
        success  { notifySlack(channel: '#ops-deploys', status: 'SUCCESS', env: params.ENVIRONMENT) }
        cleanup  { sh 'rm -f iac/environments/*/tfplan' }
    }
}
```

---

## Git Workflow

### Branching Strategy — Trunk-based (simplified for solo/small team)

```
main                  ← always deployable; protected branch
  └── ops/YYYYMMDD-<slug>    ← short-lived feature branches
  └── fix/YYYYMMDD-<slug>
  └── hotfix/<ticket>-<slug>  ← for urgent prod fixes
```

**Rules:**
- `main` protected: no direct push, requires PR (even solo — for the audit trail)
- Branch naming: `ops/20250422-iam-audit-script`, `fix/20250420-snapshot-rotation-bug`
- Squash merges for script changes; merge commits for runbooks/docs (preserve history)
- Tag releases for Ansible playbooks and OpenTofu modules: `ansible/ec2-hardening/v1.2.0`

### Commit Message Convention

```
<type>(<scope>): <short imperative description>

Types:  feat | fix | ops | sec | docs | refactor | chore
Scope:  ansible | iac | scripts | jenkins | sql | runbooks

Examples:
  feat(iac): add RDS Aurora module with encryption enforced
  sec(ansible): add CIS 4.1 SSH hardening controls to common role
  ops(scripts): add dry-run flag to purge-snapshots.sh
  fix(jenkins): correct STS assume-role session name collision
  docs(runbooks): add GuardDuty severity-7 triage runbook
```

---

## SSM Parameter Store Inventory Convention

Rather than `.env` files, maintain `config/ssm-parameter-inventory.md` as a catalogue:

```markdown
# SSM Parameter Inventory
## Last Updated: 2025-04-22

| Path | Type | Description | Rotation |
|------|------|-------------|----------|
| /bluerush/prod/db/master_password | SecureString | Aurora master password | Secrets Manager (90d) |
| /bluerush/prod/jenkins/github_token | SecureString | Jenkins GitHub webhook token | Manual |
| /bluerush/nonprod/db/master_password | SecureString | Nonprod Aurora master password | Secrets Manager (90d) |
| /bluerush/common/slack_webhook | SecureString | Ops alerts Slack webhook | Manual |
| /bluerush/prod/app/config/log_level | String | Application log level | N/A |
```

Scripts reference paths, never values:
```bash
DB_PASS=$(aws ssm get-parameter \
    --name "/bluerush/${ENV}/db/master_password" \
    --with-decryption \
    --query 'Parameter.Value' \
    --output text \
    --profile "$PROFILE" --region "$REGION")
```

---

## Runbook Template (`runbooks/_template.md`)

```markdown
# [SERVICE] [INCIDENT TYPE] Runbook — v1.0 — YYYY-MM-DD
**Severity**: P1 / P2 / P3
**Affected Services**:
**Accounts in Scope**: (prod / nonprod / all)
**On-Call**: Nuno Serrenho
**Last Tested**: YYYY-MM-DD

---
## Triage (Target: <15 min)
1. [Action] → Expected: [output] | If fail: [fallback]

## Contain
1. [Action]

## Investigate
1. [Action]

## Remediate
1. [Action]

## Verify Clean
- [ ] [Verification step]

## Post-Mortem Trigger
- [ ] Timeline documented
- [ ] Root cause identified
- [ ] Ticket created: [link]
- [ ] Runbook updated if steps changed
```

---

## ADR Template (`docs/adr/ADR-NNN-<slug>.md`)

```markdown
# ADR-001: IaC Tooling — OpenTofu over Terraform

**Date**: 2025-04-22
**Status**: Accepted
**Deciders**: Nuno Serrenho

## Context
[Why a decision was needed]

## Decision
[What was decided]

## Consequences
**Positive**: [...]
**Negative / Trade-offs**: [...]

## Alternatives Considered
| Option | Reason Rejected |
|--------|----------------|
| Terraform OSS | BSL license risk post-v1.5 |
| AWS CDK | AWS-only, TypeScript overhead |
```

---

## Initial Setup Checklist

```bash
# Clone and bootstrap
git clone git@github.com:bluerush/ops.git
cd ops

# Install pre-commit
pip install pre-commit detect-secrets
pre-commit install

# Generate initial secrets baseline (scan existing files)
detect-secrets scan > .secrets.baseline
git add .secrets.baseline

# Verify hooks
pre-commit run --all-files
```

### Jenkins Shared Library Registration
In Jenkins → Manage Jenkins → Configure System → Global Pipeline Libraries:
- Name: `bluerush-ops-shared`
- Source: this repo, `jenkins/shared-library/`
- Default version: `main`
- Load implicitly: No (explicit `@Library` in Jenkinsfiles)
```
