---
title: Public / Private Module Split
category: concept
summary: PowerShell modules use Public/ and Private/ subdirectories — the .psm1 dot-sources Private first, then Public, and Export-ModuleMember is always explicit (never wildcarded).
tags: [powershell, modules, scaffold, conventions]
sources: 1
updated: 2026-04-29
---

# Public / Private Module Split

The structural convention every Bluerush PowerShell module follows. Used in the [[sources/pscodebase-scaffold]] and reinforced by the [[sources/ps-module-template-plan]].

---

## Layout

```
ModuleName/
├── Private/                  # Internal helpers — dot-sourced, NEVER exported
│   ├── Resolve-Foo.ps1
│   └── ConvertTo-Bar.ps1
├── Public/                   # Exported functions — one per file
│   ├── Get-Thing.ps1
│   └── Set-Thing.ps1
├── ModuleName.psd1           # Manifest with explicit FunctionsToExport
└── ModuleName.psm1           # Loader: Classes → Private → Public
```

## .psm1 load order

```powershell
# Classes first (so types are available everywhere), then Private, then Public.
foreach ($folder in @('Classes', 'Private', 'Public')) {
    Get-ChildItem -Path (Join-Path $PSScriptRoot $folder) -Filter *.ps1 -Recurse |
        ForEach-Object { . $_.FullName }
}
```

## Why split

- **Surface area is intentional.** Only `Public/` is part of the contract — refactor `Private/` freely.
- **Code review is clean.** Reviewers know which functions are user-facing.
- **`git blame` stays linear.** One function per file means renames/moves don't cause merge churn.

## One function per file

Filename **must match** the function name exactly: `Get-BLURSecurityGroup.ps1` contains `function Get-BLURSecurityGroup`. The `.psm1` discovers exports by filename, so this is also a load-order requirement, not just a style preference.

## See also

- [[concepts/explicit-module-exports]] — paired rule: `Export-ModuleMember` is always explicit
- [[sources/pscodebase-scaffold]], [[sources/ps-module-template-plan]]
- [[concepts/everything-as-code]]
