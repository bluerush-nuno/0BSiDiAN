# PLAN.md — PowerShell Project Scaffold Generator

> Prompt and plan for Claude Code to generate a template git repository
> that serves as the canonical starting point for all PowerShell projects.

---

## Part 1: Template Repository Strategy

### Recommended Approach: GitHub Template Repository + `git init` Script

After evaluating branches, worktrees, forks, and features — **a GitHub Template Repository
with a local bootstrapper script** is the right answer for this use case. Here's why each
alternative falls short, and how the recommended approach works.

### Alternatives Considered

| Strategy | Pros | Cons | Verdict |
|----------|------|------|---------|
| **Branches** | Simple, everything in one repo | Templates pollute history; merging template updates into projects is painful; branch soup | **Reject** |
| **Git Worktrees** | Multiple checkouts of same repo | Tied to one repo; no independent history per project; worktrees are for parallel work on branches, not project spawning | **Reject** |
| **Forks** | Independent repos with upstream link | GitHub forks are public by default; fork network is visible; merging upstream template changes requires careful cherry-picking; fork model designed for contribution, not templating | **Partial** — usable but not ideal |
| **Feature branches** | Familiar workflow | Same problems as branches; template isn't a "feature" | **Reject** |
| **GitHub Template Repo** | One-click "Use this template" creates a fresh repo with no history link; clean git log; independent lifecycle | Requires GitHub; no automatic upstream sync | **Recommended** |
| **Template Repo + Bootstrapper** | All template repo benefits + automated customization (module name, namespace, GUID, author) | Slightly more setup | **Best** |

### How It Works

1. **Create `PSModuleTemplate`** — a GitHub repository marked as a Template Repository
   (Settings → Template repository checkbox).

2. **Include a `bootstrap.ps1`** script that:
   - Prompts for module name, author, description, namespace prefix
   - Generates a fresh GUID for the manifest
   - Renames all placeholder files and content
   - Runs `git init` if not already in a git repo
   - Makes the initial commit
   - Optionally creates the GitHub remote and pushes

3. **New project workflow**:
   ```
   Option A (GitHub UI):
   → "Use this template" → creates new repo → clone → run bootstrap.ps1

   Option B (Local):
   → Clone template repo → delete .git → run bootstrap.ps1 → push to new remote

   Option C (Claude Code):
   → Claude reads this plan.md → scaffolds directly from the spec below
   ```

4. **Updating the template**: When you improve the template (new CI patterns, better
   defaults), projects already created don't need to track upstream. They diverge
   intentionally. For cross-cutting improvements, use Claude Code to apply changes
   across repos.

### Handling BLUR.Ops Sub-Modules

For the BLUR.Ops ecosystem specifically, the template needs one additional layer:

- **Standalone modules**: Use the template as-is. Independent lifecycle.
- **BLUR.Ops spokes**: Use the template but bootstrap.ps1 automatically adds
  `RequiredModules = @('BLUR.Ops')` to the manifest and scaffolds the hub
  import pattern in the .psm1.

The bootstrapper handles this with a `-IsBlurOpsSpoke` switch.

---

## Part 2: Claude Code Scaffold Prompt

The following is the prompt to give Claude Code to generate the template repository.
Copy everything between the `---BEGIN PROMPT---` and `---END PROMPT---` markers.

```
---BEGIN PROMPT---

# Task: Generate PowerShell Module Template Repository

Read CLAUDE.md in this directory first — it defines all conventions you must follow.

Generate a complete, production-ready PowerShell module template repository with the
following requirements. Use placeholder values that bootstrap.ps1 will replace.

## Placeholder Conventions

Use these exact placeholders throughout all generated files:

- `{{ModuleName}}` — the module name (e.g., `BLUR.Ops.Network`)
- `{{ModuleDescription}}` — one-line description
- `{{Author}}` — author name
- `{{CompanyName}}` — company name
- `{{ModuleGuid}}` — will be replaced with a real GUID by bootstrap
- `{{Year}}` — current year for LICENSE
- `{{NounPrefix}}` — function noun prefix (e.g., `BLUR`)
- `{{MinPSVersion}}` — minimum PowerShell version (default: 7.2)

## Files to Generate

### Root
- `.gitignore` — per CLAUDE.md spec
- `.editorconfig` — per CLAUDE.md spec
- `README.md` — installation, prerequisites, usage examples, contributing section (all with placeholders)
- `CHANGELOG.md` — keepachangelog format, initial Unreleased section
- `LICENSE` — MIT license with {{Author}} and {{Year}}
- `CLAUDE.md` — copy from workspace (or symlink reference note)

### src/
- `{{ModuleName}}.psd1` — manifest per CLAUDE.md standards, all placeholders
- `{{ModuleName}}.psm1` — root loader per CLAUDE.md template
- `Classes/.gitkeep`
- `Private/.gitkeep`
- `Public/Get-{{NounPrefix}}Status.ps1` — example public function with full comment-based help, CmdletBinding, SupportsShouldProcess, error handling, and verbose output. This is the reference implementation all future functions should follow.
- `Formats/.gitkeep`

### tests/
- `{{ModuleName}}.Tests.ps1` — module structural tests:
  - Manifest valid
  - All public functions have help
  - All public functions have CmdletBinding
  - All public functions have test files
  - PSScriptAnalyzer clean
- `Unit/Get-{{NounPrefix}}Status.Tests.ps1` — example unit test matching the example function
- `Integration/.gitkeep`

### build/
- `build.ps1` — Invoke-Build script per CLAUDE.md
- `PSScriptAnalyzerSettings.psd1` — per CLAUDE.md
- `pester.config.ps1` — per CLAUDE.md

### .github/
- `workflows/ci.yml` — per CLAUDE.md
- `workflows/publish.yml` — per CLAUDE.md
- `CODEOWNERS` — placeholder

### tools/
- `bootstrap.ps1` — the project initializer (see spec below)

## bootstrap.ps1 Specification

```powershell
<#
.SYNOPSIS
    Initialize a new PowerShell module project from this template.
.DESCRIPTION
    Replaces all template placeholders with project-specific values,
    generates a fresh module GUID, renames files, and optionally
    initializes git and creates a GitHub remote.
.PARAMETER ModuleName
    The name of the new module (e.g., 'BLUR.Ops.Network').
.PARAMETER Description
    One-line module description.
.PARAMETER Author
    Author name. Defaults to 'BlueRush'.
.PARAMETER CompanyName
    Company name. Defaults to 'BlueRush Inc'.
.PARAMETER NounPrefix
    Prefix for function nouns. Defaults to 'BLUR'.
.PARAMETER MinPSVersion
    Minimum PowerShell version. Defaults to '7.2'.
.PARAMETER IsBlurOpsSpoke
    If set, adds BLUR.Ops as a RequiredModule and configures hub imports.
.PARAMETER InitGit
    Initialize a git repo and make initial commit. Default: $true.
.PARAMETER GitHubRepo
    Optional. Creates GitHub remote and pushes. Format: 'owner/repo-name'.
.EXAMPLE
    ./tools/bootstrap.ps1 -ModuleName 'BLUR.Ops.Network' -Description 'VPC and networking operations' -IsBlurOpsSpoke
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Z][a-zA-Z0-9.]+$')]
    [string]$ModuleName,

    [Parameter(Mandatory)]
    [string]$Description,

    [string]$Author = 'BlueRush',
    [string]$CompanyName = 'BlueRush Inc',
    [string]$NounPrefix = 'BLUR',
    [string]$MinPSVersion = '7.2',
    [switch]$IsBlurOpsSpoke,
    [bool]$InitGit = $true,
    [string]$GitHubRepo
)
```

The bootstrap script must:

1. Generate a new GUID via `[guid]::NewGuid()`
2. Recursively find all files in the repo and replace placeholders:
   - `{{ModuleName}}` → $ModuleName
   - `{{ModuleDescription}}` → $Description
   - `{{Author}}` → $Author
   - `{{CompanyName}}` → $CompanyName
   - `{{ModuleGuid}}` → generated GUID
   - `{{Year}}` → current year
   - `{{NounPrefix}}` → $NounPrefix
   - `{{MinPSVersion}}` → $MinPSVersion
3. Rename files containing `{{ModuleName}}` in their name
4. If `-IsBlurOpsSpoke`:
   - Add `RequiredModules = @('BLUR.Ops')` to manifest
   - Add `Import-Module BLUR.Ops -ErrorAction Stop` to top of .psm1
5. Remove `tools/bootstrap.ps1` itself (it's single-use)
6. Remove `.gitkeep` files from directories that now have content
7. If `-InitGit`:
   - `git init`
   - `git add -A`
   - `git commit -m "feat: initial scaffold from PSModuleTemplate"`
8. If `-GitHubRepo`:
   - `gh repo create $GitHubRepo --private --source=. --push`
9. Print summary of what was created

## Quality Checks After Generation

After generating all files, verify:
1. `Test-ModuleManifest` passes on the .psd1 (with placeholders replaced by test values)
2. `Invoke-ScriptAnalyzer` returns zero errors on all .ps1 files
3. `Invoke-Pester` passes the structural tests
4. The .psm1 loads without error when imported
5. `bootstrap.ps1` runs successfully with test parameters

---END PROMPT---
```

---

## Part 3: Implementation Sequence

### Phase 1 — Template Repository (Do First)

1. Create a new local directory `PSModuleTemplate/`
2. Run the Claude Code prompt above to generate all files
3. Validate with the quality checks
4. Push to GitHub as a Template Repository
5. Test the workflow: "Use this template" → clone → bootstrap

### Phase 2 — BLUR.Ops Migration (Do Second)

1. Compare existing BLUR.Ops scaffold against the new template
2. Identify gaps (the template may be more current than the initial scaffold)
3. Either re-scaffold BLUR.Ops from the template or selectively adopt improvements
4. Run the full test suite to confirm nothing regressed

### Phase 3 — Future Projects

For every new PowerShell project going forward:

```powershell
# Option A: GitHub template
# 1. Click "Use this template" on GitHub
# 2. Clone locally
# 3. Run bootstrap:
./tools/bootstrap.ps1 -ModuleName 'NewProject' -Description 'Does a thing'

# Option B: Local clone (no GitHub UI)
git clone https://github.com/yourorg/PSModuleTemplate NewProject
cd NewProject
Remove-Item .git -Recurse -Force
./tools/bootstrap.ps1 -ModuleName 'NewProject' -Description 'Does a thing' -InitGit $true

# Option C: BLUR.Ops spoke module
./tools/bootstrap.ps1 -ModuleName 'BLUR.Ops.Monitoring' `
    -Description 'CloudWatch and observability operations' `
    -IsBlurOpsSpoke
```

---

## Part 4: Key Design Decisions

### Why Not Plaster/Catesta?

Plaster and Catesta are excellent tools, but they add dependencies and abstraction that a
solo operator doesn't need. The bootstrap.ps1 approach is:

- Zero dependencies (pure PowerShell)
- Fully transparent (you can read the entire templating logic in one file)
- Customizable without learning Plaster's XML manifest format
- Version-controlled alongside the template itself
- Runnable by Claude Code without installing anything

If the team grows or you start publishing templates for external consumption, migrating
to Catesta makes sense — it handles edge cases (encoding, conditional includes, user
prompts) that bootstrap.ps1 skips. The migration path is: export your template structure
into a Catesta plasterManifest.xml.

### Why Invoke-Build Over psake?

- Invoke-Build runs each task in script scope (cleaner isolation)
- More powerful task dependency graph
- Actively maintained with better PowerShell 7.x support
- psake is legacy-viable but not the forward bet

### Why GitHub Actions Over Jenkins for New Projects?

- OIDC federation eliminates long-lived AWS credentials
- Native PowerShell support (`shell: pwsh`)
- Template-able workflows (you define once in the template repo)
- Jenkins remains supported for existing pipelines — this isn't a rip-and-replace

---

## Part 5: Maintenance

### Updating the Template

When you improve patterns (new PSScriptAnalyzer rules, better CI steps, new CLAUDE.md
sections), update the template repo directly. Already-spawned projects are independent
and don't receive updates automatically.

For cross-cutting changes that need to reach existing projects, use Claude Code:

```
Read plan.md and CLAUDE.md. Then apply the following change to all PowerShell module
repos in this workspace: [describe the change]. Create a feature branch in each,
make the change, run tests, and report results.
```

### Template Versioning

Tag the template repo with semver when you make meaningful changes:

- `v1.0.0` — initial template
- `v1.1.0` — added new CI step or build task
- `v2.0.0` — breaking structure change (e.g., renamed directories)

This lets you track which template version a project was spawned from (bootstrap.ps1
can write `# Scaffolded from PSModuleTemplate v1.2.0` into the generated CLAUDE.md).
