# PSCodebase — Session Notes
**Date**: 2026-04-24  
**Topic**: Standard PowerShell codebase folder structure for AWS SecDevOps operations

---

## What Was Built

A production-grade PowerShell repository scaffold for AWS multi-account / SecDevOps operations, delivered as `PSCodebase.zip`.

---

## Folder Structure

```
PSCodebase/
├── .github/
│   └── workflows/
│       └── ci.yml                          # PSScriptAnalyzer + Pester CI pipeline
├── Build/                                  # Module packaging / PSGallery publish scripts (stub)
├── Config/
│   ├── Environments/
│   │   └── prod.psd1                       # Example env config — SSM paths, not secrets
│   └── Schemas/                            # JSON Schema for config validation (stub)
├── Docs/
│   ├── Architecture/                       # Architecture context docs (stub)
│   ├── Decisions/                          # ADRs (stub)
│   └── Runbooks/                           # Operational runbooks in Markdown (stub)
├── Modules/
│   ├── AWS/
│   │   ├── Private/                        # Internal helpers (dot-sourced, not exported)
│   │   ├── Public/
│   │   │   └── Get-ActiveOrgAccounts.ps1   # Example: Org account enumeration
│   │   ├── AWS.psd1                        # Module manifest
│   │   └── AWS.psm1                        # Module loader (dot-sources Public + Private)
│   ├── Logging/
│   │   └── Logging.psm1                    # Structured logger (color + file output)
│   ├── Networking/                         # Stub
│   ├── Security/                           # Stub
│   └── Utility/                            # Stub
├── Scripts/
│   ├── AWS/
│   │   ├── EC2/                            # Stub
│   │   ├── IAM/
│   │   │   └── Get-UsersWithoutMfa.ps1     # Example: Multi-account MFA audit (read-only)
│   │   ├── Org/                            # Stub
│   │   ├── RDS/                            # Stub
│   │   ├── S3/                             # Stub
│   │   └── VPC/                            # Stub
│   ├── Ops/                                # Stub
│   ├── Reporting/                          # Stub
│   └── Security/                           # Stub
├── Tests/
│   ├── Integration/
│   │   ├── AWS/                            # Stub
│   │   └── Security/                       # Stub
│   └── Unit/
│       ├── AWS/
│       │   └── AWS.Module.Tests.ps1        # Pester 5 tests for Get-ActiveOrgAccounts
│       ├── Logging/                        # Stub
│       ├── Networking/                     # Stub
│       ├── Security/                       # Stub
│       └── Utility/                        # Stub
├── Tools/
│   └── Install-Dependencies.ps1            # Bootstrap: installs AWS.Tools.* + Pester + PSSA
├── .gitignore
├── PSScriptAnalyzerSettings.psd1           # Linter config
└── README.md
```

---

## Key Design Decisions

### Module structure: Public / Private split
Each module uses a `Public/` and `Private/` subdirectory. The `.psm1` dot-sources `Private/` first, then `Public/`. `Export-ModuleMember` is always explicit — no `-Function *` wildcards. This keeps the module surface intentional and auditable.

### One function per file
Public functions live in individual `.ps1` files named after the function (`Get-ActiveOrgAccounts.ps1`). This makes navigation, code review, and git blame straightforward.

### Manifest + module file (.psd1 + .psm1)
Every module has both. The `.psd1` declares `RequiredModules`, explicit `FunctionsToExport`, and a GUID. This enables proper dependency resolution when importing and future PSGallery publishing.

### AWS.Tools modular — never the monolithic AWSPowerShell
`AWS.Tools.*` installs via `Install-AWSToolsModule` from `AWS.Tools.Installer`. Only the service modules actually needed are installed. The monolithic `AWSPowerShell` is explicitly avoided.

### No implicit AWS defaults
All functions and scripts require explicit `-ProfileName` and `-Region` parameters. No reliance on environment defaults or implicit credential chains that behave differently across machines.

### Config: .psd1 over JSON
Environment configs use `.psd1` files — natively importable with `Import-PowerShellDataFile`, typed, and no JSON parsing overhead. Secrets are never stored in config files; only SSM Parameter Store paths are referenced.

### Secrets: SSM paths only
Config files reference SSM paths (e.g., `/prod/notifications/slack-webhook`), not values. Secrets are pulled at runtime via `Get-SSMParameterValue` or `Get-SECSecretValue`. Nothing sensitive touches the filesystem.

### Tests mirror module structure
`Tests/Unit/AWS/` maps to `Modules/AWS/`. Finding the test for any given module or function is unambiguous.

### Pester 5.x with full mocking
Unit tests mock all AWS API calls (`Mock Get-ORGAccountList`). No live credentials required to run the unit suite. Integration tests (stubs, in `Tests/Integration/`) are the appropriate place for credential-aware, live-account tests.

### CI: PSScriptAnalyzer then Pester
GitHub Actions workflow runs `Invoke-ScriptAnalyzer` first (fast fail on lint errors), then Pester. Test results written as NUnit XML for artifact upload. `runs-on: windows-latest` by default; change to `ubuntu-latest` if scripts are PS7 Linux-clean.

---

## Conventions Established

| Concern | Convention |
|---|---|
| Error handling | `try/catch` with `$_.Exception.Message`; re-throw or log+continue per context |
| Strictness | `Set-StrictMode -Version Latest` + `$ErrorActionPreference = 'Stop'` in all scripts and modules |
| Multi-account | `Use-STSRole` → `Set-AWSCredential` → work → `Clear-AWSCredential` in `finally` |
| Output | Structured objects (`[PSCustomObject]`, typed arrays). No string parsing of AWS output. |
| Logging | `Write-Log` from the `Logging` module. Never bare `Write-Host` in operational scripts. |
| Dependencies | Declared with `#Requires` at the top of every script and module |
| Exports | Always explicit in `Export-ModuleMember` and `FunctionsToExport` in `.psd1` |

---

## Working Examples Included

### `Modules/AWS/Public/Get-ActiveOrgAccounts.ps1`
Enumerates all `ACTIVE` accounts in the AWS Organization via `Get-ORGAccountList`. Supports exclusion list. Returns typed `Amazon.Organizations.Model.Account[]` objects.

### `Modules/Logging/Logging.psm1`
Structured logger with severity levels (`DEBUG`, `INFO`, `WARN`, `ERROR`), color-coded console output, and optional file output. Call `Initialize-Logger` once at script start, then `Write-Log` throughout.

### `Scripts/AWS/IAM/Get-UsersWithoutMfa.ps1`
Multi-account IAM audit. Finds all IAM users with console access but no MFA device enrolled. Read-only — no mutations. Maps to CIS AWS v1.5 control 1.5. Outputs structured objects; pipe to `Export-Csv` or `ConvertTo-Json`.

### `Tests/Unit/AWS/AWS.Module.Tests.ps1`
Pester 5 unit tests for `Get-ActiveOrgAccounts`. Covers: active-only filtering, exclusion list, empty result set, and API error propagation. Full AWS API mocking — no credentials needed.

---

## Next Steps / Stubs to Fill

- **`Modules/Security/`** — IAM policy auditing, SG review helpers, findings formatter
- **`Modules/Networking/`** — VPC/TGW/SG utilities
- **`Modules/Utility/`** — Retry logic, tag validation, ARN parsing
- **`Scripts/AWS/EC2/`** — Instance inventory, SSM agent compliance, AMI age audit
- **`Scripts/AWS/RDS/`** — Snapshot age, encryption-at-rest check, public accessibility audit
- **`Scripts/Reporting/`** — Aggregate findings across accounts → CSV/HTML report
- **`Build/`** — Module versioning, `.nupkg` packaging, PSGallery or internal NuGet feed publish
- **`Tests/Integration/`** — Credential-aware integration tests with `Skip` guards for non-CI runs
- **`Docs/Runbooks/`** — IAM credential compromise, EC2 compromise, S3 misconfiguration IR runbooks

---

## Prerequisites

- PowerShell 7.x
- Run `./Tools/Install-Dependencies.ps1` to install all module dependencies
- AWS credential profiles configured for management account and member accounts
- IAM role (`OrgAuditRole` or equivalent) deployed to all member accounts via StackSets
