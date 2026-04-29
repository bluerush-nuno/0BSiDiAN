---
title: PSCodebase Scaffold — Session Notes
category: source
summary: Production-grade PowerShell repository scaffold for AWS multi-account SecDevOps — Modules/Public/Private split, AWS.Tools modular, SSM-only secrets, Pester 5 with full mocking, GitHub Actions CI.
tags: [powershell, scaffold, aws, pester, psscriptanalyzer, modules, secdevops]
sources: 1
updated: 2026-04-29
source_path: Projects/Powershell/artifacts/PWSH-Codepsace.md
source_date: 2026-04
authors: [Nuno Serrenho]
ingested: 2026-04-29
---

# PSCodebase Scaffold

**Original**: `Projects/Powershell/artifacts/PWSH-Codepsace.md`
**Date**: 2026-04-24
**Topic**: Standard PowerShell codebase folder structure for AWS SecDevOps operations

---

## TL;DR

A reference PowerShell repository scaffold delivered as `PSCodebase.zip` — Modules/Public/Private split with explicit exports, AWS.Tools modular SDK only (never the monolithic `AWSPowerShell`), all secrets via SSM paths (never values), Pester 5 unit tests with full AWS API mocking, and GitHub Actions CI running PSScriptAnalyzer then Pester. Working examples included for org account enumeration, structured logging, and multi-account MFA audit.

---

## Folder Structure

```
PSCodebase/
├── .github/workflows/ci.yml         # PSScriptAnalyzer + Pester CI
├── Build/                           # Packaging / PSGallery publish (stub)
├── Config/
│   ├── Environments/prod.psd1       # Env config — SSM paths, not secrets
│   └── Schemas/                     # JSON Schema for validation (stub)
├── Docs/{Architecture,Decisions,Runbooks}/
├── Modules/
│   ├── AWS/
│   │   ├── Private/                 # Internal helpers (dot-sourced, not exported)
│   │   ├── Public/Get-ActiveOrgAccounts.ps1
│   │   ├── AWS.psd1                 # Manifest
│   │   └── AWS.psm1                 # Loader
│   ├── Logging/Logging.psm1         # Structured logger (color + file)
│   ├── Networking/, Security/, Utility/   # Stubs
├── Scripts/
│   ├── AWS/IAM/Get-UsersWithoutMfa.ps1
│   └── AWS/{EC2,Org,RDS,S3,VPC}/, Ops/, Reporting/, Security/   # Stubs
├── Tests/
│   ├── Integration/                 # Stubs
│   └── Unit/AWS/AWS.Module.Tests.ps1
├── Tools/Install-Dependencies.ps1   # AWS.Tools.* + Pester + PSSA bootstrap
├── PSScriptAnalyzerSettings.psd1
└── README.md
```

---

## Key Design Decisions

### Module structure: Public / Private split
Each module has `Public/` and `Private/` subdirectories. The `.psm1` dot-sources `Private/` first, then `Public/`. `Export-ModuleMember` is **always explicit** — no `-Function *` wildcards. Surface stays intentional and auditable. See [[concepts/public-private-module-split]], [[concepts/explicit-module-exports]].

### One function per file
Public functions live in individual `.ps1` files named after the function (`Get-ActiveOrgAccounts.ps1`). Navigation, code review, and `git blame` stay clean.

### Manifest + module file (.psd1 + .psm1)
Both required. The `.psd1` declares `RequiredModules`, explicit `FunctionsToExport`, and a GUID — enables proper dependency resolution and future PSGallery publishing.

### AWS.Tools modular — never `AWSPowerShell`
`AWS.Tools.*` installed via `Install-AWSToolsModule` from `AWS.Tools.Installer`. Only the service modules actually needed are installed. The monolithic `AWSPowerShell` is **explicitly avoided**. See [[entities/aws-tools-modular]].

### No implicit AWS defaults
All functions and scripts require **explicit** `-ProfileName` and `-Region` parameters. No reliance on environment defaults or implicit credential chains that behave differently across machines.

### Config: `.psd1` over JSON
Environment configs use `.psd1` files — natively importable with `Import-PowerShellDataFile`, typed, and no JSON parsing overhead.

### Secrets: SSM paths only
Config files reference SSM paths (e.g., `/prod/notifications/slack-webhook`), **not values**. Secrets pulled at runtime via `Get-SSMParameterValue` or `Get-SECSecretValue`. Reinforces [[concepts/zero-secrets-in-repo]].

### Tests mirror module structure
`Tests/Unit/AWS/` maps to `Modules/AWS/`. Finding the test for any given module or function is unambiguous.

### Pester 5.x with full mocking
Unit tests mock all AWS API calls (`Mock Get-ORGAccountList`). No live credentials required to run the unit suite. Integration tests (stubs) are the place for credential-aware live-account tests. See [[entities/pester]].

### CI: PSScriptAnalyzer then Pester
GitHub Actions runs `Invoke-ScriptAnalyzer` first (fast fail on lint errors), then Pester. NUnit XML test results uploaded as artifact. `runs-on: windows-latest` by default; switch to `ubuntu-latest` if scripts are PS7 Linux-clean. See [[entities/psscriptanalyzer]].

---

## Conventions Established

| Concern | Convention |
|---|---|
| Error handling | `try/catch` with `$_.Exception.Message`; re-throw or log+continue per context |
| Strictness | `Set-StrictMode -Version Latest` + `$ErrorActionPreference = 'Stop'` |
| Multi-account | `Use-STSRole` → `Set-AWSCredential` → work → `Clear-AWSCredential` in `finally` |
| Output | Structured objects (`[PSCustomObject]`, typed arrays). No string parsing. |
| Logging | `Write-Log` from the `Logging` module. Never bare `Write-Host`. |
| Dependencies | Declared with `#Requires` at the top of every script and module |
| Exports | Always explicit in `Export-ModuleMember` and `FunctionsToExport` in `.psd1` |

The `Use-STSRole` → `Set-AWSCredential` → `Clear-AWSCredential` in `finally` pattern is the operational form of [[concepts/sts-assume-role-pattern]].

---

## Working Examples

| File | Purpose |
|---|---|
| `Modules/AWS/Public/Get-ActiveOrgAccounts.ps1` | Enumerates `ACTIVE` accounts via `Get-ORGAccountList`. Supports exclusion list. Returns typed `Amazon.Organizations.Model.Account[]`. |
| `Modules/Logging/Logging.psm1` | Structured logger — `DEBUG`/`INFO`/`WARN`/`ERROR`, color console, optional file output. `Initialize-Logger` once at script start, then `Write-Log`. |
| `Scripts/AWS/IAM/Get-UsersWithoutMfa.ps1` | Multi-account IAM audit. Console-access users without MFA. Read-only. Maps to **CIS AWS v1.5 control 1.5**. |
| `Tests/Unit/AWS/AWS.Module.Tests.ps1` | Pester 5 unit tests for `Get-ActiveOrgAccounts` — active filtering, exclusion list, empty result, API error propagation. Full mocking. |

---

## Stubs to Fill (operator backlog)

- `Modules/Security/` — IAM policy auditing, SG review helpers, findings formatter
- `Modules/Networking/` — VPC/TGW/SG utilities
- `Modules/Utility/` — Retry logic, tag validation, ARN parsing
- `Scripts/AWS/EC2/` — Instance inventory, SSM agent compliance, AMI age audit
- `Scripts/AWS/RDS/` — Snapshot age, encryption-at-rest, public accessibility
- `Scripts/Reporting/` — Aggregate findings → CSV/HTML
- `Build/` — Module versioning, `.nupkg`, PSGallery / internal NuGet feed publish
- `Tests/Integration/` — Credential-aware tests with `Skip` guards
- `Docs/Runbooks/` — IAM credential compromise, EC2 compromise, S3 misconfiguration IR runbooks

---

## Prerequisites

- PowerShell 7.x
- Run `./Tools/Install-Dependencies.ps1` to install module dependencies
- AWS credential profiles for management + member accounts
- IAM role (`OrgAuditRole` or equivalent) deployed to all member accounts via StackSets

---

## Related Pages

- [[sources/secdevops-repo-framework]], [[sources/ps-module-template-plan]]
- [[entities/bluerush]], [[entities/aws-organizations]], [[entities/pester]], [[entities/psscriptanalyzer]], [[entities/aws-tools-modular]]
- [[concepts/public-private-module-split]], [[concepts/explicit-module-exports]]
- [[concepts/zero-secrets-in-repo]], [[concepts/sts-assume-role-pattern]], [[concepts/everything-as-code]]
- [[synthesis/secdevops-posture]]
