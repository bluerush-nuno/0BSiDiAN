---
title: PSScriptAnalyzer
category: entity
summary: Static analyzer for PowerShell. First gate in Bluerush CI — runs before Pester so lint failures fail fast.
tags: [powershell, static-analysis, ci, lint]
sources: 2
updated: 2026-04-29
---

# PSScriptAnalyzer

**Type**: PowerShell static analyzer
**Project**: <https://github.com/PowerShell/PSScriptAnalyzer>
**Settings file**: `build/PSScriptAnalyzerSettings.psd1` (per project)

---

## Role in CI

PSScriptAnalyzer is the **first** gate in `Invoke-Build` — `Analyze` runs before `Test`. If lint errors are found, the build fails before Pester even starts. Cheap fast-fail.

## Standard settings

```powershell
@{
    Severity     = @('Error', 'Warning', 'Information')
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'    # Allowed in build scripts; banned in modules by convention
    )
    Rules = @{
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('7.2', '7.4')
        }
        PSPlaceOpenBrace        = @{ Enable = $true; OnSameLine = $true; NewLineAfter = $true }
        PSUseConsistentIndentation = @{ Enable = $true; Kind = 'space'; IndentationSize = 4 }
        PSAlignAssignmentStatement = @{ Enable = $true; CheckHashtable = $true }
    }
}
```

## Build task

```powershell
task Analyze {
    $results = Invoke-ScriptAnalyzer -Path ./src -Recurse `
        -Settings ./build/PSScriptAnalyzerSettings.psd1
    if ($results | Where-Object Severity -eq 'Error') {
        $results | Format-Table -AutoSize
        throw "PSScriptAnalyzer found errors"
    }
    $results | Format-Table -AutoSize
}
```

Errors fail the build. Warnings and Information are reported but do not block.

## Conventions enforced

- 4-space indent, LF line endings (also enforced by `.editorconfig`)
- Open brace on same line, newline after
- Approved verbs only for public functions
- No `Write-Host` in module functions (excluded only for build scripts)

## Related Pages

- [[sources/pscodebase-scaffold]], [[sources/ps-module-template-plan]]
- [[entities/pester]]
- [[concepts/pre-commit-gating]]
