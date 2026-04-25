<#
.SYNOPSIS
    Clones a WAFv2 Web ACL (all rules + default action) from one account/WAF to another.

.DESCRIPTION
    Fetches the source Web ACL, then applies its rules and DefaultAction directly to the
    destination Web ACL. The destination's own VisibilityConfig (metric name) is preserved.
    The destination Web ACL must already exist — this script syncs rules only.

    WARNING: Rules containing account-specific ARNs (IPSet, RegexPatternSet, RuleGroup)
    will be copied verbatim. Those ARNs will be invalid in the destination account —
    recreate those resources in the dest account first.

.PARAMETER SourceWafName    Name of the source Web ACL.
.PARAMETER SourceWafId      ID (UUID) of the source Web ACL.
.PARAMETER SourceProfile    AWS credential profile for the source account.
.PARAMETER DestWafName      Name of the destination Web ACL.
.PARAMETER DestWafId        ID (UUID) of the destination Web ACL.
.PARAMETER DestProfile      AWS credential profile for the destination account.
.PARAMETER Region           AWS region (must be the same for both WAFs).
.PARAMETER Scope            REGIONAL (default) or CLOUDFRONT.

.EXAMPLE
    # Dry run
    .\Copy-WafWebACL.ps1 -WhatIf

.EXAMPLE
    # Clone prod-waf → test-waf (defaults pre-filled)
    .\Copy-WafWebACL.ps1

.EXAMPLE
    # No confirmation prompt (CI / automated)
    .\Copy-WafWebACL.ps1 -Confirm:$false
#>

#Requires -Modules AWS.Tools.WAFV2

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [string] $SourceWafName = 'prod-waf',
    [string] $SourceWafId   = 'db92aeda-bde0-4ec7-b0cb-ffeda452db02',
    [string] $SourceProfile = 'bluerush-prod',   # acct 942957828074

    [string] $DestWafName   = 'test-waf',
    [string] $DestWafId     = '4f83fe3d-1c92-4695-a5c8-e57de992013c',
    [string] $DestProfile   = 'bluerush-dev',    # acct 182813858189

    [string] $Region        = 'ca-central-1',

    [ValidateSet('REGIONAL','CLOUDFRONT')]
    [string] $Scope         = 'REGIONAL'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$WafScope = [Amazon.WAFV2.Scope]::$Scope

Write-Host ''
Write-Host '══════════════════════════════════════════════════════════'
Write-Host '  WAF Web ACL Clone'
Write-Host '══════════════════════════════════════════════════════════'
Write-Host "  Source : $SourceWafName  [$SourceWafId]  profile: $SourceProfile"
Write-Host "  Dest   : $DestWafName  [$DestWafId]  profile: $DestProfile"
Write-Host "  Region : $Region   Scope: $Scope"
Write-Host '══════════════════════════════════════════════════════════'

# ── Fetch source ────────────────────────────────────────────────────────────────
Write-Host "`n[1/3] Fetching source WAF..."
$Src = Get-WAF2WebACL -Name $SourceWafName -Scope $WafScope -Id $SourceWafId `
                      -Region $Region -ProfileName $SourceProfile

Write-Host "      $($Src.WebACL.Rules.Count) rules:"
$Src.WebACL.Rules | Sort-Object Priority | ForEach-Object {
    $action = if ($_.Action) {
        $_.Action.PSObject.Properties | Where-Object { $null -ne $_.Value } |
            Select-Object -First 1 -ExpandProperty Name
    } elseif ($_.OverrideAction) {
        'Override:' + ($_.OverrideAction.PSObject.Properties | Where-Object { $null -ne $_.Value } |
            Select-Object -First 1 -ExpandProperty Name)
    } else { '?' }
    Write-Host ("      [{0,2}]  {1,-55}  {2}" -f $_.Priority, $_.Name, $action)
}

# Warn on any account-scoped ARN references
$arnRules = $Src.WebACL.Rules | Where-Object {
    ($_ | ConvertTo-Json -Depth 15 -Compress) -match '"ARN"\s*:\s*"arn:aws'
}
if ($arnRules) {
    Write-Warning "The following rules contain account-scoped ARNs that will be invalid in the destination account — verify before applying:"
    $arnRules | ForEach-Object { Write-Warning "  - $($_.Name)" }
}

# ── Fetch destination (lock token + visibility config) ──────────────────────────
Write-Host "`n[2/3] Fetching destination WAF..."
$Dst = Get-WAF2WebACL -Name $DestWafName -Scope $WafScope -Id $DestWafId `
                      -Region $Region -ProfileName $DestProfile

Write-Host "      Lock token : $($Dst.LockToken)"
Write-Host "      $($Dst.WebACL.Rules.Count) existing rules that will be REPLACED:"
$Dst.WebACL.Rules | Sort-Object Priority | ForEach-Object {
    Write-Host ("      [{0,2}]  {1}" -f $_.Priority, $_.Name)
}

# ── Apply ───────────────────────────────────────────────────────────────────────
Write-Host ''
if (-not $PSCmdlet.ShouldProcess(
        "$DestWafName (profile: $DestProfile)",
        "Replace $($Dst.WebACL.Rules.Count) existing rules with $($Src.WebACL.Rules.Count) rules from $SourceWafName")) {
    Write-Host "[3/3] [WhatIf] No changes applied."
    Write-Host "      Would replace $($Dst.WebACL.Rules.Count) dest rules with $($Src.WebACL.Rules.Count) source rules."
    exit 0
}

Write-Host "[3/3] Applying $($Src.WebACL.Rules.Count) rules to $DestWafName..."
try {
    $Result = Update-WAF2WebACL `
        -Name             $DestWafName `
        -Scope            $WafScope `
        -Id               $DestWafId `
        -LockToken        $Dst.LockToken `
        -DefaultAction    $Src.WebACL.DefaultAction `
        -Rule             $Src.WebACL.Rules `
        -VisibilityConfig $Dst.WebACL.VisibilityConfig `
        -Region           $Region `
        -ProfileName      $DestProfile

    Write-Host "      Applied. New lock token: $($Result.NextLockToken)"
} catch {
    Write-Error "Update-WAF2WebACL failed: $($_.Exception.Message)"
    exit 1
}

# ── Verify ──────────────────────────────────────────────────────────────────────
Write-Host "`n[verify] Re-fetching $DestWafName to confirm..."
$Verify = Get-WAF2WebACL -Name $DestWafName -Scope $WafScope -Id $DestWafId `
                          -Region $Region -ProfileName $DestProfile

Write-Host "         $($Verify.WebACL.Rules.Count) rules now active:"
$Verify.WebACL.Rules | Sort-Object Priority | ForEach-Object {
    $action = if ($_.Action) {
        $_.Action.PSObject.Properties | Where-Object { $null -ne $_.Value } |
            Select-Object -First 1 -ExpandProperty Name
    } elseif ($_.OverrideAction) {
        'Override:' + ($_.OverrideAction.PSObject.Properties | Where-Object { $null -ne $_.Value } |
            Select-Object -First 1 -ExpandProperty Name)
    } else { '?' }
    Write-Host ("         [{0,2}]  {1,-55}  {2}" -f $_.Priority, $_.Name, $action)
}

Write-Host "`nDone."
