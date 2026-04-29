---
title: PSModuleTemplate
category: entity
summary: Planned GitHub Template Repository for spawning new PowerShell module repos. Ships placeholders + bootstrap.ps1 that replaces them, generates a fresh GUID, and runs git init.
tags: [powershell, scaffold, github-template, planning]
sources: 1
updated: 2026-04-29
---

# PSModuleTemplate

**Type**: GitHub Template Repository (planned, not yet created)
**Plan source**: [[sources/ps-module-template-plan]]
**Reference scaffold**: [[sources/pscodebase-scaffold]]

---

## What It Is

A GitHub Template Repository that any operator (or Claude Code) can use to spawn a fresh PowerShell module repo. The template contains the [[sources/pscodebase-scaffold]] structure with placeholders (`{{ModuleName}}`, `{{ModuleGuid}}`, etc.) plus a single-use `tools/bootstrap.ps1` that materializes a real project.

## Bootstrap Surface

```powershell
./tools/bootstrap.ps1 -ModuleName 'BLUR.Ops.Network' `
    -Description 'VPC and networking operations' `
    -IsBlurOpsSpoke
```

Parameters: `ModuleName` (required, validated PascalCase with optional dots), `Description` (required), `Author` (default `BlueRush`), `CompanyName`, `NounPrefix` (default `BLUR`), `MinPSVersion` (default `7.2`), `IsBlurOpsSpoke` (switch — auto-wires `BLUR.Ops` as `RequiredModules`), `InitGit` (default `$true`), `GitHubRepo` (optional `owner/repo` — runs `gh repo create --private --source=. --push`).

## What Bootstrap Does

1. Generates fresh GUID via `[guid]::NewGuid()`
2. Recursively replaces all placeholder tokens
3. Renames files containing `{{ModuleName}}`
4. Adds BLUR.Ops hub wiring if `-IsBlurOpsSpoke`
5. Self-deletes (it's single-use)
6. Removes `.gitkeep`s from populated directories
7. Optionally `git init` + initial commit
8. Optionally creates GitHub remote and pushes

## Hub-and-Spoke

PSModuleTemplate understands the BLUR.Ops ecosystem (hub + AWS/IAM/Network/Security/Compute spokes). The `-IsBlurOpsSpoke` switch is the only thing the operator needs to flip; hub wiring is automatic.

## Status

Not yet built. The plan ([[sources/ps-module-template-plan]]) embeds a Claude-Code prompt that generates the entire template repo from the spec. Phase 1 of implementation is to run that prompt.

## Versioning

Tag the template with SemVer when meaningful changes land. `bootstrap.ps1` writes `# Scaffolded from PSModuleTemplate vX.Y.Z` into the generated `CLAUDE.md` so spawned projects know their origin.

## Related Pages

- [[sources/ps-module-template-plan]], [[sources/pscodebase-scaffold]]
- [[entities/bluerush]]
- [[concepts/scaffold-templating]]
- [[concepts/public-private-module-split]], [[concepts/explicit-module-exports]]
