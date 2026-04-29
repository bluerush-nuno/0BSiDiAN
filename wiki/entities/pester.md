---
title: Pester
category: entity
summary: PowerShell unit-test framework. Bluerush standardizes on Pester 5.x with full AWS API mocking for unit tests; integration tests use credential-aware skip guards.
tags: [powershell, testing, ci, pester]
sources: 1
updated: 2026-04-29
---

# Pester

**Type**: PowerShell test framework
**Project**: <https://github.com/pester/Pester>
**Version pinned**: 5.x (minimum 5.5)

---

## How Bluerush uses it

- **Unit tests** mock all external dependencies — AWS API calls, file system, network. Fast, no credentials required.
- **Integration tests** run against sandboxed AWS, gated by a credential-aware skip:
  ```powershell
  $skipIntegration = -not (Get-AWSCredential -ProfileName 'test-profile' -ErrorAction SilentlyContinue)
  It 'Should describe real VPC' -Skip:$skipIntegration { ... }
  ```
- **Module structural tests** validate manifest validity, comment-based help presence, `[CmdletBinding()]` presence, test-file existence per public function, and zero PSScriptAnalyzer errors.
- **Tags**: `Unit`, `Integration`, `Slow` — selective execution in CI.

## Configuration pattern

```powershell
$config = New-PesterConfiguration
$config.Run.Path = './tests'
$config.Run.Exit = $true
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = @('./src/Public/', './src/Private/')
$config.CodeCoverage.OutputFormat = 'JaCoCo'
$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = 'NUnitXml'
$config.Filter.Tag = @('Unit')
```

## CI integration

The CI workflow installs Pester via `Install-Module -Name Pester -MinimumVersion 5.5 -Force`, then `Invoke-Build -Task Test` runs the suite. NUnit XML and JaCoCo coverage are uploaded as artifacts.

## Working example

`Tests/Unit/AWS/AWS.Module.Tests.ps1` in the [[sources/pscodebase-scaffold]] covers `Get-ActiveOrgAccounts`: active-only filtering, exclusion list, empty result, API error propagation. All AWS calls mocked.

## Related Pages

- [[sources/pscodebase-scaffold]], [[sources/ps-module-template-plan]]
- [[entities/psscriptanalyzer]], [[entities/aws-tools-modular]]
- [[concepts/public-private-module-split]]
