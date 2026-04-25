# CLAUDE.md — PowerShell Project Standards

> Authoritative project instructions for any PowerShell module or script repository
> built under this workspace. Claude Code and all AI agents MUST follow these
> conventions unless explicitly overridden per-project.

---

## Operator Context

- Solo/small-team SecDevOps operator, 33+ years in Security, Development, and Operations
- AWS-primary (multi-account via Orgs, multi-region), cloud-agnostic where sensible
- Core stack: EC2/ASG/ELB · RDS/Aurora · VPC/TGW/Direct Connect · SSM · Secrets Manager
- Scripting: PowerShell (primary, AWS.Tools modular SDK), Bash/jq for Linux tasks
- CI/CD: GitHub Actions (OIDC federation); Jenkins for legacy pipelines
- IaC: Custom scripts migrating toward Terraform/OpenTofu + Ansible
- Testing: Pester 5.x, PSScriptAnalyzer
- Existing ecosystem: BLUR.Ops hub-and-spoke module pattern (see Architecture section)

---

## Repository Structure

Every PowerShell project repository MUST follow this layout. Directories not needed
for a given project may be omitted, but the structure must not be rearranged.

```
<ModuleName>/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                  # Build + test on push/PR
│   │   └── publish.yml             # Publish to feed on release tag
│   └── CODEOWNERS
├── src/
│   ├── Classes/                    # PowerShell class definitions (loaded first)
│   ├── Private/                    # Internal helper functions (not exported)
│   ├── Public/                     # Exported functions (one function per file)
│   ├── Formats/                    # *.ps1xml format/type definitions
│   ├── <ModuleName>.psd1           # Module manifest
│   └── <ModuleName>.psm1           # Root module loader
├── tests/
│   ├── Unit/                       # Fast, no external deps, mocked AWS calls
│   ├── Integration/                # Require live/sandboxed AWS; credential-aware skip
│   └── <ModuleName>.Tests.ps1      # Module-level structural tests
├── docs/                           # Markdown documentation, generated help stubs
├── build/
│   ├── build.ps1                   # Invoke-Build entry point
│   ├── tasks/                      # Reusable build task definitions
│   └── PSScriptAnalyzerSettings.psd1
├── tools/                          # Dev-time utilities, installers, migration scripts
├── .gitignore
├── .editorconfig
├── CLAUDE.md                       # This file (project instructions for AI agents)
├── CHANGELOG.md
├── LICENSE
└── README.md
```

### Key Structural Rules

1. **One function per file** in `Public/` and `Private/`. Filename MUST match function name exactly: `Get-BLURConfig.ps1` contains `function Get-BLURConfig`.
2. **Load order in .psm1**: `Classes/` → `Private/` → `Public/` via dot-sourcing. This ensures types are available to all functions.
3. **Dynamic exports**: Functions are exported by basename of files in `Public/`. Do NOT manually maintain `FunctionsToExport` arrays — the .psm1 loader handles this.
4. **No code in .psd1**: The manifest declares metadata only. All logic lives in .psm1.

---

## Module Manifest (.psd1) Standards

```powershell
@{
    RootModule        = '<ModuleName>.psm1'
    ModuleVersion     = '0.1.0'                    # SemVer
    GUID              = '<generate-once-keep-forever>'
    Author            = 'BlueRush'
    CompanyName       = 'BlueRush Inc'
    Description       = '<one-line description>'
    PowerShellVersion = '7.2'                       # Minimum PS version
    CompatiblePSEditions = @('Core')                # Core-only unless 5.1 required
    RequiredModules   = @()                         # Explicit dependencies
    FunctionsToExport = @()                         # Empty — .psm1 handles via Export-ModuleMember
    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()
    PrivateData = @{
        PSData = @{
            Tags       = @()
            ProjectUri = ''
            LicenseUri = ''
        }
    }
}
```

### Manifest Rules

- **GUID**: Generate once with `[guid]::NewGuid()`. Never change it across versions.
- **FunctionsToExport**: Set to empty array `@()` in manifest. The .psm1 calls `Export-ModuleMember -Function` with the dynamically discovered list.
- **RequiredModules**: Declare ALL dependencies explicitly. For BLUR.Ops sub-modules, always require `BLUR.Ops` as the hub.
- **CompatiblePSEditions**: Default to `Core`. Only add `Desktop` if 5.1 compatibility is tested and intentional.

---

## Root Module Loader (.psm1) Template

```powershell
#Requires -Version 7.2

$ErrorActionPreference = 'Stop'

# Load order: Classes → Private → Public
$folders = @('Classes', 'Private', 'Public')
foreach ($folder in $folders) {
    $folderPath = Join-Path -Path $PSScriptRoot -ChildPath $folder
    if (Test-Path -Path $folderPath) {
        $files = Get-ChildItem -Path $folderPath -Filter '*.ps1' -Recurse
        foreach ($file in $files) {
            try {
                . $file.FullName
            }
            catch {
                Write-Error "Failed to import $($file.FullName): $_"
                throw
            }
        }
    }
}

# Export only Public functions
$publicFunctions = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') `
    -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty BaseName

if ($publicFunctions) {
    Export-ModuleMember -Function $publicFunctions
}

# Load format/type data
$formatsPath = Join-Path $PSScriptRoot 'Formats'
if (Test-Path $formatsPath) {
    Get-ChildItem -Path $formatsPath -Filter '*.ps1xml' | ForEach-Object {
        Update-FormatData -AppendPath $_.FullName
    }
}
```

---

## Naming Conventions

### Based on PoshCode/PowerShellPracticeAndStyle + BLUR.Ops patterns

| Element | Convention | Example |
|---------|-----------|---------|
| Module name | PascalCase, prefixed with org namespace | `BLUR.Ops.AWS` |
| Public function | Approved Verb-Noun, PascalCase | `Get-BLURSecurityGroup` |
| Private function | Same as public, but may use unapproved verbs for internal clarity | `Resolve-AccountCredential` |
| Parameter | PascalCase, descriptive | `-AccountId`, `-ProfileName` |
| Variable (local) | camelCase | `$securityGroups` |
| Variable (script/module scope) | PascalCase with `Script:` or `Module:` prefix | `$Script:DefaultRegion` |
| Class | PascalCase | `[BLURResult]`, `[BLURConfig]` |
| Enum | PascalCase | `[BLURSeverity]` |
| Constant | UPPER_SNAKE_CASE via `Set-Variable -Option Constant` | `$MAX_RETRY_COUNT` |
| Test file | `<FunctionName>.Tests.ps1` | `Get-BLURSecurityGroup.Tests.ps1` |
| Build task | PascalCase verb | `Clean`, `Analyze`, `Test`, `Build` |

### Verb Usage

- Use **approved verbs only** for public functions: `Get-Verb | Select-Object -ExpandProperty Verb`
- Common mappings: `Get` (read), `Set` (write/update), `New` (create), `Remove` (delete), `Invoke` (execute), `Test` (validate), `Export`/`Import` (serialize), `Start`/`Stop` (lifecycle)
- For BLUR.Ops modules: always prefix the noun with `BLUR` — `Get-BLURVpcFlowLog`, not `Get-VpcFlowLog`

---

## Coding Standards

### Error Handling

```powershell
# REQUIRED pattern for all public functions
function Get-BLURResource {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceId,

        [Parameter()]
        [string]$Region = 'us-east-1',

        [Parameter()]
        [string]$ProfileName
    )

    begin {
        # Parameter validation, setup
    }

    process {
        try {
            if ($PSCmdlet.ShouldProcess($ResourceId, 'Describe resource')) {
                # Actual work here
            }
        }
        catch [Amazon.Runtime.AmazonServiceException] {
            Write-Error "AWS API error for $ResourceId in $Region : $($_.Exception.Message)"
            throw
        }
        catch {
            Write-Error "Unexpected error: $($_.Exception.Message)"
            throw
        }
    }

    end {
        # Cleanup
    }
}
```

### Non-Negotiable Patterns

1. **`SupportsShouldProcess`** on ANY function that creates, modifies, or deletes resources. No exceptions.
2. **Explicit `-Region` and `-ProfileName`** parameters on every AWS-interacting function. Never rely on implicit defaults.
3. **`[CmdletBinding()]`** on every function. Always.
4. **`[Parameter(Mandatory)]`** with `[ValidateNotNullOrEmpty()]` on required params.
5. **Comment-based help** on every public function:
   ```powershell
   <#
   .SYNOPSIS
       Brief one-line description.
   .DESCRIPTION
       Detailed description including AWS API calls made and IAM permissions required.
   .PARAMETER ResourceId
       The AWS resource identifier.
   .EXAMPLE
       Get-BLURResource -ResourceId 'vpc-123abc' -Region 'us-east-1'
   .NOTES
       Required IAM permissions: ec2:DescribeVpcs
   #>
   ```
6. **No `Write-Host`** in module functions. Use `Write-Verbose`, `Write-Warning`, `Write-Debug`, or `Write-Information`.
7. **Return structured objects**, not strings. Use `[PSCustomObject]@{}` or typed classes.
8. **No aliases in scripts/modules**: `Select-Object` not `select`, `Where-Object` not `?`, `ForEach-Object` not `%`.

### AWS-Specific Patterns

```powershell
# Use modular AWS.Tools, never monolithic AWSPowerShell
Import-Module AWS.Tools.EC2

# Multi-account via STS role assumption
$creds = (Use-STSRole -RoleArn "arn:aws:iam::${AccountId}:role/OrgAuditRole" `
    -RoleSessionName "audit-$(Get-Date -Format yyyyMMddHHmm)" `
    -Region $Region).Credentials

# Config without secrets — SSM Parameter Store
$configValue = Get-SSMParameterValue -Name "/blur/config/$Environment/db-endpoint" `
    -WithDecryption $true -Region $Region
```

### Safety Guardrails (from SecDevOps skill)

- **Prod vs non-prod flag**: If a script could touch prod, call it out at the top of the file and in `-WhatIf` messaging.
- **Blast radius**: State worst-case impact in function description before any destructive operation.
- **Least-privilege default**: IAM policies generated by scripts start from minimum required. Never `*`.
- **Reversibility warning**: Flag destructive or hard-to-reverse operations with `Write-Warning` before execution.
- **Dry-run first**: All destructive operations support `-WhatIf` and `-Confirm`.

---

## Testing Standards (Pester 5.x)

### Test File Structure

```powershell
BeforeAll {
    $modulePath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Import-Module (Join-Path $modulePath 'src' '<ModuleName>.psd1') -Force
}

Describe 'Get-BLURResource' {
    BeforeAll {
        # Common mocks for the describe block
        Mock -ModuleName '<ModuleName>' -CommandName 'Get-EC2Instance' -MockWith {
            return @{ InstanceId = 'i-1234567890abcdef0'; State = @{ Name = 'running' } }
        }
    }

    Context 'When resource exists' {
        It 'Should return the resource object' {
            $result = Get-BLURResource -ResourceId 'i-1234567890abcdef0' -Region 'us-east-1'
            $result | Should -Not -BeNullOrEmpty
            $result.InstanceId | Should -Be 'i-1234567890abcdef0'
        }

        It 'Should call Get-EC2Instance exactly once' {
            Should -Invoke -ModuleName '<ModuleName>' -CommandName 'Get-EC2Instance' -Exactly -Times 1
        }
    }

    Context 'When resource does not exist' {
        BeforeAll {
            Mock -ModuleName '<ModuleName>' -CommandName 'Get-EC2Instance' -MockWith {
                throw [Amazon.EC2.AmazonEC2Exception]::new('not found')
            }
        }

        It 'Should throw a meaningful error' {
            { Get-BLURResource -ResourceId 'i-nonexistent' -Region 'us-east-1' } |
                Should -Throw -ErrorId '*not found*'
        }
    }
}
```

### Testing Rules

1. **Unit tests**: Mock all external dependencies (AWS API calls, file system, network). Fast, no credentials needed.
2. **Integration tests**: Use credential-aware skip pattern:
   ```powershell
   BeforeAll {
       $skipIntegration = -not (Get-AWSCredential -ProfileName 'test-profile' -ErrorAction SilentlyContinue)
   }
   It 'Should describe real VPC' -Skip:$skipIntegration { ... }
   ```
3. **Module structural tests**: Every module gets a meta-test file that validates:
   - Manifest is valid (`Test-ModuleManifest`)
   - All public functions have comment-based help
   - All public functions have `[CmdletBinding()]`
   - All exported functions have matching test files
   - PSScriptAnalyzer returns zero errors
4. **Naming**: Test files mirror source: `Public/Get-BLURResource.ps1` → `tests/Unit/Get-BLURResource.Tests.ps1`
5. **Tags**: Use `-Tag 'Unit'`, `-Tag 'Integration'`, `-Tag 'Slow'` for selective execution in CI.

### Pester Configuration

```powershell
# build/pester.config.ps1
$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Path = './tests'
$pesterConfig.Run.Exit = $true
$pesterConfig.CodeCoverage.Enabled = $true
$pesterConfig.CodeCoverage.Path = @('./src/Public/', './src/Private/')
$pesterConfig.CodeCoverage.OutputFormat = 'JaCoCo'
$pesterConfig.CodeCoverage.OutputPath = './build/coverage.xml'
$pesterConfig.TestResult.Enabled = $true
$pesterConfig.TestResult.OutputFormat = 'NUnitXml'
$pesterConfig.TestResult.OutputPath = './build/testResults.xml'
$pesterConfig.Output.Verbosity = 'Detailed'
$pesterConfig.Filter.Tag = @('Unit')        # CI default; override for integration
```

---

## PSScriptAnalyzer Configuration

```powershell
# build/PSScriptAnalyzerSettings.psd1
@{
    Severity     = @('Error', 'Warning', 'Information')
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'         # Allowed in build scripts, not modules
    )
    Rules = @{
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('7.2', '7.4')
        }
        PSPlaceOpenBrace = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }
        PSPlaceCloseBrace = @{
            Enable             = $true
            NewLineAfter       = $false
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }
        PSUseConsistentIndentation = @{
            Enable              = $true
            Kind                = 'space'
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            IndentationSize     = 4
        }
        PSUseConsistentWhitespace = @{
            Enable                                  = $true
            CheckInnerBrace                         = $true
            CheckOpenBrace                          = $true
            CheckOpenParen                          = $true
            CheckOperator                           = $true
            CheckPipe                               = $true
            CheckPipeForRedundantWhitespace         = $false
            CheckSeparator                          = $true
            IgnoreAssignmentOperatorInsideHashTable  = $true
        }
        PSAlignAssignmentStatement = @{
            Enable         = $true
            CheckHashtable = $true
        }
    }
}
```

---

## Build Automation (Invoke-Build)

### build/build.ps1

```powershell
#Requires -Modules @{ ModuleName = 'InvokeBuild'; ModuleVersion = '5.10' }

param(
    [string]$ModuleName = (Get-Item $PSScriptRoot/..).BaseName,
    [string]$Version    = '0.1.0'
)

task Clean {
    Remove-Item ./build/output -Recurse -Force -ErrorAction SilentlyContinue
}

task Analyze {
    $results = Invoke-ScriptAnalyzer -Path ./src -Recurse `
        -Settings ./build/PSScriptAnalyzerSettings.psd1
    if ($results | Where-Object Severity -eq 'Error') {
        $results | Format-Table -AutoSize
        throw "PSScriptAnalyzer found errors"
    }
    $results | Format-Table -AutoSize
}

task Test {
    $config = . ./build/pester.config.ps1
    Invoke-Pester -Configuration $config
}

task Build Clean, Analyze, Test, {
    $outputDir = "./build/output/$ModuleName/$Version"
    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null

    # Copy source
    Copy-Item -Path ./src/* -Destination $outputDir -Recurse

    # Update manifest version
    Update-ModuleManifest -Path "$outputDir/$ModuleName.psd1" -ModuleVersion $Version
}

task Publish Build, {
    $outputDir = "./build/output/$ModuleName/$Version"
    Publish-Module -Path $outputDir -NuGetApiKey $env:NUGET_API_KEY -Repository PSGallery
}

task . Build
```

---

## GitHub Actions CI/CD

### .github/workflows/ci.yml

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  id-token: write    # OIDC federation
  contents: read

jobs:
  build-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        shell: pwsh
        run: |
          Set-PSRepository PSGallery -InstallationPolicy Trusted
          Install-Module -Name Pester -MinimumVersion 5.5 -Force
          Install-Module -Name PSScriptAnalyzer -Force
          Install-Module -Name InvokeBuild -Force

      - name: Run build (analyze + test)
        shell: pwsh
        run: Invoke-Build -File ./build/build.ps1 -Task Build

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: |
            build/testResults.xml
            build/coverage.xml
```

### .github/workflows/publish.yml

```yaml
name: Publish
on:
  push:
    tags: ['v*']

jobs:
  publish:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        shell: pwsh
        run: |
          Set-PSRepository PSGallery -InstallationPolicy Trusted
          Install-Module -Name Pester -MinimumVersion 5.5 -Force
          Install-Module -Name PSScriptAnalyzer -Force
          Install-Module -Name InvokeBuild -Force

      - name: Publish
        shell: pwsh
        env:
          NUGET_API_KEY: ${{ secrets.NUGET_API_KEY }}
        run: |
          $version = '${{ github.ref_name }}'.TrimStart('v')
          Invoke-Build -File ./build/build.ps1 -Task Publish -Version $version
```

---

## Git Conventions

### Branching Strategy

Trunk-based development with short-lived feature branches:

- **`main`**: Always releasable. Protected branch — requires PR + passing CI.
- **`feature/<ticket-or-slug>`**: Short-lived (days, not weeks). Rebased onto main before merge.
- **`fix/<description>`**: Bug fixes, same lifecycle as features.
- **`release/vX.Y.Z`**: Cut from main when preparing a release. Tag triggers publish.

### Commit Messages

```
<type>(<scope>): <description>

[optional body]
[optional footer(s)]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `build`, `ci`, `chore`
Scope: module name or area (e.g., `BLUR.Ops.AWS`, `build`, `ci`)

### .gitignore Essentials

```gitignore
# Build artifacts
build/output/
build/testResults.xml
build/coverage.xml

# IDE
.vscode/settings.json
*.code-workspace

# PowerShell
*.dll
*.pdb

# Secrets (should never exist, but belt-and-suspenders)
*.env
*credentials*
*secret*

# OS
Thumbs.db
.DS_Store

# Temporary
*.tmp
*.bak
*.log
```

---

## EditorConfig

```ini
# .editorconfig
root = true

[*]
indent_style = space
indent_size = 4
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.ps1]
indent_size = 4

[*.psd1]
indent_size = 4

[*.psm1]
indent_size = 4

[*.yml]
indent_size = 2

[*.json]
indent_size = 2

[*.md]
trim_trailing_whitespace = false
```

---

## Documentation Standards

### Every Public Function Must Have

1. Comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.NOTES`)
2. `.NOTES` section listing required IAM permissions for AWS functions
3. At least one `.EXAMPLE` showing typical usage

### Module-Level Documentation

- `README.md`: Installation, quick start, prerequisites, examples
- `CHANGELOG.md`: Keep a changelog ([keepachangelog.com](https://keepachangelog.com)) format
- `docs/`: Extended documentation, architecture decisions, migration guides

---

## BLUR.Ops Ecosystem Architecture

The BLUR.Ops ecosystem follows a **hub-and-spoke** pattern modeled after `AWS.Tools`:

```
BLUR.Ops (hub)
├── Shared utilities: logging, config, STS role assumption
├── BLURResult return type (Classes/)
├── Config management (SSM Parameter Store + local JSON fallback)
│
├── BLUR.Ops.AWS        (spoke — general AWS operations)
├── BLUR.Ops.IAM        (spoke — identity and access management)
├── BLUR.Ops.Network    (spoke — VPC, TGW, Direct Connect)
├── BLUR.Ops.Security   (spoke — GuardDuty, Security Hub, compliance)
└── BLUR.Ops.Compute    (spoke — EC2, ASG, ELB)
```

Each spoke declares `RequiredModules = @('BLUR.Ops')` and inherits shared infrastructure.

---

## MCP / Claude Code Integration

### PowerShell.MCP

For AI-assisted development, install the [PowerShell.MCP](https://github.com/yotsuda/PowerShell.MCP) server:

```powershell
Install-PSResource PowerShell.MCP
Register-PwshToClaudeCode
```

This gives Claude Code full access to PowerShell execution with transparent, auditable commands.

### Claude Code Working Patterns

When Claude Code works on this project:

1. Read this `CLAUDE.md` first — it is the source of truth for conventions.
2. Run `Invoke-ScriptAnalyzer` after any code generation to validate compliance.
3. Run `Invoke-Pester` after any functional change to verify tests pass.
4. Never commit directly to `main` — always create a feature branch.
5. Use `-WhatIf` when demonstrating destructive operations.

---

## References

- [PoshCode/PowerShellPracticeAndStyle](https://github.com/PoshCode/PowerShellPracticeAndStyle) — Community style guide (~2.4k stars)
- [Catesta](https://github.com/techthoughts2/Catesta) — Module scaffolding with CI/CD templates
- [Stucco](https://github.com/devblackops/Stucco) — Opinionated Plaster template
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) — Static analysis
- [Pester](https://github.com/pester/Pester) — Testing framework
- [Invoke-Build](https://github.com/nightroman/Invoke-Build) — Build automation
- [PowerShell.MCP](https://github.com/yotsuda/PowerShell.MCP) — Claude Code integration
- [ModuleBuilder](https://github.com/PoshCode/ModuleBuilder) — Advanced module builds
