---
title: Explicit Module Exports
category: concept
summary: PowerShell modules never use Export-ModuleMember -Function * or wildcarded FunctionsToExport. Public surface is enumerated, either statically in the manifest or dynamically from Public/ filenames.
tags: [powershell, modules, security, conventions]
sources: 2
updated: 2026-04-29
---

# Explicit Module Exports

**Rule**: `Export-ModuleMember -Function *` and `FunctionsToExport = '*'` are forbidden.

Either:
1. Enumerate `FunctionsToExport` in the `.psd1` manifest, **or**
2. Have the `.psm1` discover exports from `Public/` filenames and pass that list to `Export-ModuleMember`.

The [[sources/pscodebase-scaffold]] takes approach (1); the [[sources/ps-module-template-plan]] takes approach (2). Both are valid — what matters is that the export list is **knowable** without running the module.

---

## Why

- **Auditability**: PSGallery reviewers, security reviewers, and `Get-Command -Module` consumers can see the contract from the manifest alone.
- **Performance**: Wildcards force PowerShell to enumerate all functions in the session at import — slow for large modules.
- **Mistake prevention**: Helper functions in `Private/` can't accidentally leak into the consumer surface.
- **Refactor safety**: Renaming an internal helper can't accidentally break a downstream caller because internal helpers were never exported in the first place.

---

## Dynamic-exports pattern (template repo)

```powershell
# In .psm1 — discover Public/ filenames at module load
$publicFunctions = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -Recurse |
    Select-Object -ExpandProperty BaseName

if ($publicFunctions) {
    Export-ModuleMember -Function $publicFunctions
}
```

Manifest stays as `FunctionsToExport = @()` — empty array, not wildcard. The `.psm1` is the source of truth at runtime; the manifest declares "this module exports a (possibly empty) set of named functions" without committing to which ones.

## Static-exports pattern (PSCodebase)

```powershell
# In .psd1
FunctionsToExport = @('Get-ActiveOrgAccounts', 'Get-UsersWithoutMfa')
```

Slightly more maintenance (you update the manifest when you add a public function), but the export list is visible at the top of the manifest without reading any code.

## See also

- [[concepts/public-private-module-split]] — paired rule: only `Public/` files become exports
- [[sources/pscodebase-scaffold]], [[sources/ps-module-template-plan]]
