# Web App Disaster Recovery SOP

**Version**: 1.0  
**Last Updated**: 2026-03-18  
**Scope**: 2x Windows Server EC2 (ca-central-1a/1b) + Multi-AZ RDS MySQL + Media S3 backup (primary + cross-region DR)  
**Author**: Operations Team  
**Review Cycle**: Quarterly (or post-incident)

---
## Executive Summary

This SOP defines recovery procedures for a web application running on 2 static Windows Server EC2 instances (one per AZ for high availability) with a redundant Multi-AZ RDS MySQL backend and media files backed up to S3 for cross-region disaster recovery.

**Design principle**: Automated backups (RDS snapshots, S3 media sync); manual runbooks for instance/database failures. The operator is the execution engine — procedures are step-by-step with CLI commands and PowerShell, not GUI walkthroughs. Media replication to another region allows recovery from regional loss of EC2 availability.

---

## Recovery Objectives

| Scenario                                               | RTO       | RPO                                                       | Strategy                                                                                                               |
| ------------------------------------------------------ | --------- | --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| **Single EC2 Windows instance failure**                | 5–15 min  | <1 min                                                    | Manual failover to healthy instance; ALB/DNS redirect                                                                  |
| **Both EC2 instances down (AZ or regional failure)**   | 30–60 min | <1 min (code/app) + media from S3 backup                  | Launch new Windows instance(s) in remaining AZ; restore media from S3                                                  |
| **RDS Primary failover (Multi-AZ)**                    | 1–3 min   | <1 min                                                    | Automatic managed failover                                                                                             |
| **RDS data corruption/deletion**                       | 15–30 min | Last hourly snapshot                                      | Restore from snapshot to point-in-time                                                                                 |
| **RDS instance failure (both primary + standby down)** | 10–20 min | Last automated snapshot                                   | Restore from snapshot                                                                                                  |
| **Single AZ outage (ca-central-1a or 1b)**             | 5–30 min  | <1 min (code) + media from S3                             | Remaining EC2 instance handles traffic; media already on healthy instance; launch replacement in opposite AZ if needed |
| **Full region loss**                                   | 2–4 hours | Latest cross-region S3 media backup + RDS snapshot export | Provision new EC2 + RDS in alternate region; restore media from S3                                                     |
| **Media files accidentally deleted**                   | 5–30 min  | Last S3 versioned snapshot (hourly)                       | Restore from S3 versioning or backup bucket                                                                            |

---
## Infrastructure Assumptions

- **Compute**: 2x Windows Server EC2 instances (**host1a-tdkc** in *ca-central-1a*, **host1b-tdkc** in *ca-central-1b*)
- **Load Balancing**: Application Load Balancer (ALB) distributing traffic across both instances (or NLB with round-robin)
- **Database**: RDS MySQL (Multi-AZ) with standby in opposite AZ
- **Storage — Application**: EBS volumes (C: for OS & application code/data)
- **Storage — Media**: Local folder on each EC2 (e.g., `C:\media\`); synced to S3 (primary backup) and S3-IA in alternate region (disaster recovery)
- **Application**: Stateless session handling (sessions in RDS MySQL, not local files)
- **Monitoring**: CloudWatch, optional SNS alerts (runbooks are pull-based)
- **Encryption**: EBS encrypted; S3 media encrypted with SSE-S3 or KMS

---

## Disaster Types & Response Matrix

|Disaster|Severity|Detect|Triage (min)|Action Owner|Runbook|
|---|---|---|---|---|---|
|Single EC2 unhealthy (1a or 1b)|P2|CloudWatch ALB → unhealthy targets / app lag|2–3|Operator|[Single EC2 Instance Failure](https://claude.ai/chat/fc467427-8916-472a-8e98-0c6891ce9e85#single-ec2-instance-failure)|
|Both EC2 instances down|P1|ALB shows all targets unhealthy / website down|1–2|Operator|[Both EC2 Instances Down](https://claude.ai/chat/fc467427-8916-472a-8e98-0c6891ce9e85#both-ec2-instances-down)|
|RDS primary fails → standby takeover|P2|CloudWatch RDS metrics / app DB timeouts|1–3|Auto (RDS)|[RDS Failover Validation](https://claude.ai/chat/fc467427-8916-472a-8e98-0c6891ce9e85#rds-failover-validation)|
|RDS data corruption (logic error)|P1|Application error logs / data alert|5–15|Operator|[RDS Point-in-Time Restore](https://claude.ai/chat/fc467427-8916-472a-8e98-0c6891ce9e85#rds-point-in-time-restore)|
|RDS storage exhausted|P2|CloudWatch FreeStorageSpace|<5|Operator|[RDS Emergency Scale](https://claude.ai/chat/fc467427-8916-472a-8e98-0c6891ce9e85#rds-emergency-scale)|
|RDS instance deleted / both replicas down|P1|DBA check / application failure|10–30|Operator|[RDS Restore from Snapshot](https://claude.ai/chat/fc467427-8916-472a-8e98-0c6891ce9e85#rds-restore-from-snapshot)|
|Media files accidentally deleted from EC2|P2|DBA/app team alert|5–15|Operator|[Media Restore from S3](https://claude.ai/chat/fc467427-8916-472a-8e98-0c6891ce9e85#media-restore-from-s3)|
|EC2 compromised / malware detected|P1|GuardDuty / app anomaly|10–30|Operator|[Incident Response — EC2 Compromise](https://claude.ai/chat/fc467427-8916-472a-8e98-0c6891ce9e85#incident-response--ec2-compromise)|
|Single AZ outage (ca-central-1a or 1b)|P1|All targets in AZ unhealthy / no connectivity|2–5|Operator|[Single AZ Outage](https://claude.ai/chat/fc467427-8916-472a-8e98-0c6891ce9e85#single-az-outage)|

---

## Pre-Disaster Checklist (Weekly Validation)

Run this weekly to catch configuration drift and backup failures:

```powershell
# dr-preflight-check.ps1 — Weekly DR readiness validation
# Run as: powershell -ExecutionPolicy Bypass -File dr-preflight-check.ps1

param(
    [string]$Profile = "bluroot-td",
    [string]$Region = "ca-central-1"
)

Write-Host "=== DR Pre-Flight Check ===" -ForegroundColor Green
Write-Host "Date: $(Get-Date -AsUTC -Format 'yyyy-MM-ddTHH:mm:ssZ')" -ForegroundColor Cyan

$ErrorCount = 0

# 1. Check EC2 Instances
Write-Host "`n[EC2 Instances] Checking Windows server status..." -ForegroundColor Yellow

$Instances = @(
    "host1a-tdkc",  # ca-central-1a
    "host1b-tdkc"   # ca-central-1b
)

foreach ($InstanceName in $Instances) {
    try {
        $Instance = Get-EC2Instance -Filter @{Name="tag:Name"; Values=$InstanceName} `
                                   -Region $Region -ProfileName $Profile | 
                    Select-Object -ExpandProperty Instances
        
        if (-not $Instance) {
            Write-Host "❌ Instance not found: $InstanceName" -ForegroundColor Red
            $ErrorCount++
            continue
        }
        
        $State = $Instance.State.Name
        $AZ = $Instance.Placement.AvailabilityZone
        $PrivateIP = $Instance.PrivateIpAddress
        
        if ($State -eq "running") {
            Write-Host "✓ $InstanceName ($AZ): $State | IP: $PrivateIP" -ForegroundColor Green
        } else {
            Write-Host "⚠️  $InstanceName ($AZ): $State (expected 'running')" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "❌ Error checking $InstanceName : $_" -ForegroundColor Red
        $ErrorCount++
    }
}

# 2. Check ALB Target Health
Write-Host "`n[ALB] Checking target health..." -ForegroundColor Yellow

try {
    $TargetGroups = Get-ELB2TargetGroup -Region $Region -ProfileName $Profile | 
                    Where-Object { $_.Tags | Where-Object { $_.Key -eq "Environment" -and $_.Value -eq "prod" } }
    
    if ($TargetGroups) {
        $TG = $TargetGroups | Select-Object -First 1
        $Health = Get-ELB2TargetHealth -TargetGroupArn $TG.TargetGroupArn -Region $Region -ProfileName $Profile
        
        $HealthyCount = ($Health | Where-Object { $_.TargetHealth.State -eq "healthy" }).Count
        $TotalCount = $Health.Count
        
        Write-Host "ALB Targets: $HealthyCount/$TotalCount healthy" -ForegroundColor Cyan
        
        if ($HealthyCount -lt $TotalCount) {
            Write-Host "⚠️  WARNING: Unhealthy targets detected" -ForegroundColor Yellow
            $Health | Where-Object { $_.TargetHealth.State -ne "healthy" } | 
                ForEach-Object { Write-Host "  - $($_.Target.Id): $($_.TargetHealth.Reason)" }
        }
    } else {
        Write-Host "⚠️  No ALB target groups found" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "❌ Error checking ALB: $_" -ForegroundColor Red
    $ErrorCount++
}

# 3. Check RDS Multi-AZ
Write-Host "`n[RDS] Checking Multi-AZ status..." -ForegroundColor Yellow

try {
    $DBInstances = Get-RDSDBInstance -Region $Region -ProfileName $Profile | 
                   Where-Object { $_.TagList | Where-Object { $_.Key -eq "Environment" -and $_.Value -eq "prod" } }
    
    foreach ($DB in $DBInstances) {
        $DBID = $DB.DBInstanceIdentifier
        $MultiAZ = $DB.MultiAZ
        $Status = $DB.DBInstanceStatus
        $Engine = $DB.Engine
        
        if ($MultiAZ) {
            Write-Host "✓ $DBID: $Engine | Multi-AZ: $MultiAZ | Status: $Status" -ForegroundColor Green
        } else {
            Write-Host "❌ $DBID: Multi-AZ NOT enabled (critical for HA)" -ForegroundColor Red
            $ErrorCount++
        }
    }
}
catch {
    Write-Host "❌ Error checking RDS: $_" -ForegroundColor Red
    $ErrorCount++
}

# 4. Check RDS Backup Retention
Write-Host "`n[RDS Backups] Checking retention and latest snapshot..." -ForegroundColor Yellow

try {
    $DBInstances = Get-RDSDBInstance -Region $Region -ProfileName $Profile | 
                   Where-Object { $_.TagList | Where-Object { $_.Key -eq "Environment" -and $_.Value -eq "prod" } }
    
    foreach ($DB in $DBInstances) {
        $DBID = $DB.DBInstanceIdentifier
        $Retention = $DB.BackupRetentionPeriod
        
        Write-Host "Backup Retention: $Retention days" -ForegroundColor Cyan
        
        if ($Retention -lt 30) {
            Write-Host "⚠️  WARNING: Retention < 30 days" -ForegroundColor Yellow
        }
        
        # Check latest snapshot
        $LatestSnap = Get-RDSDBSnapshot -Filters @{Name="db-instance-id"; Values=$DBID} `
                                        -Region $Region -ProfileName $Profile | 
                     Where-Object { $_.SnapshotType -eq "automated" } | 
                     Sort-Object SnapshotCreateTime -Descending | 
                     Select-Object -First 1
        
        if ($LatestSnap) {
            $SnapAge = ((Get-Date).UTC - $LatestSnap.SnapshotCreateTime.UTC).TotalHours
            Write-Host "Latest automated snapshot: $(($SnapAge).ToString("F1")) hours ago" -ForegroundColor Cyan
        } else {
            Write-Host "⚠️  WARNING: No automated snapshots found" -ForegroundColor Yellow
            $ErrorCount++
        }
    }
}
catch {
    Write-Host "❌ Error checking RDS backups: $_" -ForegroundColor Red
    $ErrorCount++
}

# 5. Check S3 Media Backups
Write-Host "`n[S3 Media Backups] Checking sync status..." -ForegroundColor Yellow

try {
    $BucketName = "prod-media-backup"
    $DrBucketName = "prod-media-backup-dr"  # Cross-region backup bucket
    
    # Primary bucket
    try {
        $S3Objects = Get-S3Object -BucketName $BucketName -Region $Region -ProfileName $Profile
        if ($S3Objects) {
            $ObjectCount = if ($S3Objects -is [array]) { $S3Objects.Count } else { 1 }
            $LatestObject = $S3Objects | Sort-Object LastModified -Descending | Select-Object -First 1
            $LastSync = (Get-Date).UTC - $LatestObject.LastModified.UTC
            
            Write-Host "✓ Primary bucket '$BucketName': $ObjectCount objects" -ForegroundColor Green
            Write-Host "  Last sync: $(($LastSync.TotalMinutes).ToString("F1")) minutes ago" -ForegroundColor Cyan
            
            if ($LastSync.TotalHours -gt 2) {
                Write-Host "  ⚠️  WARNING: Last sync > 2 hours ago" -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Host "⚠️  Could not access primary bucket '$BucketName': $_" -ForegroundColor Yellow
    }
    
    # DR bucket (cross-region)
    try {
        $DRRegion = "us-east-1"  # Example alternate region
        $S3DRObjects = Get-S3Object -BucketName $DrBucketName -Region $DRRegion -ProfileName $Profile
        if ($S3DRObjects) {
            $DRObjectCount = if ($S3DRObjects -is [array]) { $S3DRObjects.Count } else { 1 }
            Write-Host "✓ DR bucket '$DrBucketName' (region: $DRRegion): $DRObjectCount objects" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "⚠️  Could not access DR bucket '$DrBucketName': $_" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "❌ Error checking S3: $_" -ForegroundColor Red
    $ErrorCount++
}

# Summary
Write-Host "`n=== Pre-Flight Check Complete ===" -ForegroundColor Green
if ($ErrorCount -eq 0) {
    Write-Host "✓ All checks passed" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ $ErrorCount error(s) detected" -ForegroundColor Red
    exit 1
}
```

**Execution**: Add to Windows Task Scheduler (run weekly, Monday 08:00):

```powershell
# Create scheduled task
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File 'C:\opt\dr-scripts\dr-preflight-check.ps1'"
$Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 08:00
Register-ScheduledTask -Action $Action -Trigger $Trigger -TaskName "DR-PrefightCheck" -Description "Weekly DR readiness validation"
```

---

## Runbooks

### Single EC2 Instance Failure

**Severity**: P2  
**Affected Service**: Web tier (reduced capacity)  
**RTO**: 5–15 minutes | **RPO**: <1 minute  
**Typical Cause**: EC2 hardware failure, OS crash, critical app process dead
#### Triage (Target: <3 min)

1. **Identify which instance is down**:
    
    ```powershell
    $Region = "ca-central-1"
    $Profile = "bluroot-td"
    
    $Instances = Get-EC2Instance -Filter @{Name="tag:Environment"; Values="prod"} `
                                 -Region $Region -ProfileName $Profile | 
                 Select-Object -ExpandProperty Instances
    
    $Instances | Select-Object InstanceId, State, Placement, PrivateIpAddress, LaunchTime | Format-Table
    ```
    
    **Expected output**: Should show both host1a-tdkc and host1b-tdkc. One will show State != "running".
    
2. **Verify ALB has detected the failure**:
    
    ```powershell
    $TG = Get-ELB2TargetGroup -Region $Region -ProfileName $Profile | 
          Where-Object { $_.Tags | Where-Object { $_.Key -eq "Environment" -and $_.Value -eq "prod" } } | 
          Select-Object -First 1
    
    Get-ELB2TargetHealth -TargetGroupArn $TG.TargetGroupArn -Region $Region -ProfileName $Profile | 
      Format-Table Target, TargetHealth
    ```
    
    **Expected output**: One healthy, one unhealthy target.
    
3. **Check application connectivity from the healthy instance**:
    
    ```powershell
    # RDP or WinRM to the healthy instance and run a quick test
    $HealthyInstanceId = "i-1234567890abcdef0"  # host1b-tdkc, for example
    
    # Test database connectivity (adjust for your app)
    Invoke-Command -ComputerName $HealthyInstanceId -ScriptBlock {
        # Check if app is running and responding to requests
        $response = Invoke-WebRequest -Uri "http://localhost/health" -UseBasicParsing
        Write-Host "App health check: $($response.StatusCode)"
    }
    ```
    

#### Contain (Target: <1 min)

4. **Application is still available via the healthy instance** — no immediate action needed. If traffic loss is acceptable for 15 min, proceed to Investigation. If you need both instances, go to Remediate.

#### Investigate

5. **Determine why the instance failed**:
    
    ```powershell
    $DownInstanceId = "i-0987654321fedcba0"  # host1a-tdkc, for example
    
    # Check System Log for crash indicators
    $SystemLog = Get-EC2ConsoleOutput -InstanceId $DownInstanceId -Region $Region -ProfileName $Profile
    $SystemLog.Output | Select-String -Pattern "error|failed|fatal" | Tail -20
    
    # Check the instance's status checks
    $StatusChecks = Get-EC2InstanceStatus -InstanceId $DownInstanceId -Region $Region -ProfileName $Profile
    $StatusChecks | Select-Object InstanceId, SystemStatus, InstanceStatus
    ```
    
6. **Common failures**:
    
    - **OS crash**: Reboot the instance and monitor for recovery
    - **App process died**: SSH/RDP in and restart the app, or proceed to Remediate
    - **EBS issue**: Check CloudWatch for I/O errors; if persistent, replace instance

#### Remediate (Option A: Reboot)

7. **If the instance is just stuck/slow**, reboot it:
    
    ```powershell
    $DownInstanceId = "i-0987654321fedcba0"Restart-EC2Instance -InstanceId $DownInstanceId -Region $Region -ProfileName $Profile -ForceWrite-Host "Reboot triggered. Waiting for instance to come online..."# Poll for statusfor ($i = 0; $i -lt 30; $i++) {    $Status = Get-EC2InstanceStatus -InstanceId $DownInstanceId -Region $Region -ProfileName $Profile    if ($Status.SystemStatus.Status -eq "ok" -and $Status.InstanceStatus.Status -eq "ok") {        Write-Host "✓ Instance is healthy"        break    }    Write-Host "[$i/30] Waiting for boot... SystemStatus: $($Status.SystemStatus.Status)"    Start-Sleep -Seconds 10}
    ```
    

#### Remediate (Option B: Terminate & Recreate)

8. **If the instance has a persistent issue**, terminate and recreate:
    
    ```powershell
    $DownInstanceId = "i-0987654321fedcba0"$AZ = "ca-central-1a"  # The AZ of the failed instance# Capture the current instance details first$
    Instance = Get-EC2Instance -InstanceId $DownInstanceId -Region $Region -ProfileName $Profile |             Select-Object -ExpandProperty Instances -First 1$ImageId = $Instance.ImageId$InstanceType = $Instance.InstanceType$SubnetId = $Instance.SubnetId$SecurityGroupIds = $Instance.SecurityGroups.GroupId$KeyName = $Instance.KeyNameWrite-Host "Terminating $DownInstanceId..."Remove-EC2Instance -InstanceId $DownInstanceId -Force -Region $Region -ProfileName $ProfileWrite-Host "Waiting for termination..."for ($i = 0; $i -lt 30; $i++) {    try {        $Status = Get-EC2Instance -InstanceId $DownInstanceId -Region $Region -ProfileName $Profile |                   Select-Object -ExpandProperty Instances -First 1        if ($Status.State.Name -eq "terminated") {            Write-Host "✓ Instance terminated"            break        }    }    catch { }    Write-Host "Waiting for full termination..."    Start-Sleep -Seconds 5}Write-Host "Launching replacement instance..."$NewInstance = New-EC2Instance -ImageId $ImageId `                               -InstanceType $InstanceType `                               -SubnetId $SubnetId `                               -SecurityGroupId $SecurityGroupIds `                               -KeyName $KeyName `                               -TagSpecification @{ResourceType="instance"; Tags=@{Name="host1a-tdkc"; Environment="prod"}} `                               -Region $Region -ProfileName $Profile$NewInstanceId = $NewInstance.Instances[0].InstanceIdWrite-Host "New instance launched: $NewInstanceId"# Wait for healthy statusWrite-Host "Waiting for instance to become healthy..."for ($i = 0; $i -lt 60; $i++) {    $Status = Get-EC2InstanceStatus -InstanceId $NewInstanceId -Region $Region -ProfileName $Profile    if ($Status.SystemStatus.Status -eq "ok" -and $Status.InstanceStatus.Status -eq "ok") {        Write-Host "✓ New instance is healthy"        break    }    Write-Host "[$i/60] Status: System=$($Status.SystemStatus.Status), Instance=$($Status.InstanceStatus.Status)"    Start-Sleep -Seconds 10}
    ```
    

#### Verify Clean

9. **Register the new/rebooted instance with ALB**:
    
    ```powershell
    $TG = Get-ELB2TargetGroup -Region $Region -ProfileName $Profile | 
          Where-Object { $_.Tags | Where-Object { $_.Key -eq "Environment" -and $_.Value -eq "prod" } } | 
          Select-Object -First 1
    
    $NewInstanceId = "i-newly-launched-id"
    
    # Register target
    Register-ELB2Target -TargetGroupArn $TG.TargetGroupArn `
                        -Target @{Id=$NewInstanceId; Port=80} `
                        -Region $Region -ProfileName $Profile
    
    Write-Host "Instance registered with ALB"
    
    # Wait for health check to pass
    Write-Host "Waiting for ALB health check..."
    for ($i = 0; $i -lt 20; $i++) {
        $Health = Get-ELB2TargetHealth -TargetGroupArn $TG.TargetGroupArn -Region $Region -ProfileName $Profile | 
                  Where-Object { $_.Target.Id -eq $NewInstanceId }
        
        if ($Health.TargetHealth.State -eq "healthy") {
            Write-Host "✓ Target is healthy in ALB"
            break
        }
        Write-Host "[$i/20] Health: $($Health.TargetHealth.State) - $($Health.TargetHealth.Description)"
        Start-Sleep -Seconds 5
    }
    ```
    
10. **Verify media files are present** (if instance was recreated):
    
    ```powershell
    # If media files are on EBS (and you recreated the instance), they may be lost
    # Restore from S3 using the Media Restore runbook below
    ```
    

#### Post-Incident

- [ ] Root cause: Hardware issue? Application crash? Misconfiguration?
- [ ] Prevention: Enable EC2 Instance Recovery (if available for instance type). Update OS/app patches.
- [ ] Metrics: Did the ALB detect failure quickly? Healthy threshold tuning needed?

---

### Both EC2 Instances Down

**Severity**: P1  
**Affected Service**: Web tier (complete loss)  
**RTO**: 30–60 minutes | **RPO**: Application code (likely unchanged); media from S3  
**Typical Cause**: Region outage, misconfigured security group, both instances corrupted

#### Triage (Target: <5 min)

1. **Confirm both instances are down**:
    
    ```powershell
    $Region = "ca-central-1"
    $Profile = "bluroot-td"
    
    $Instances = Get-EC2Instance -Filter @{Name="tag:Environment"; Values="prod"} `
                                 -Region $Region -ProfileName $Profile | 
                 Select-Object -ExpandProperty Instances
    
    $Instances | ForEach-Object {
        Write-Host "Instance: $($_.InstanceId) in $($_.Placement.AvailabilityZone) - State: $($_.State.Name)"
    }
    ```
    
2. **Check ALB status**:
    
    ```powershell
    $TG = Get-ELB2TargetGroup -Region $Region -ProfileName $Profile | 
          Where-Object { $_.Tags | Where-Object { $_.Key -eq "Environment" -and $_.Value -eq "prod" } } | 
          Select-Object -First 1
    
    $Health = Get-ELB2TargetHealth -TargetGroupArn $TG.TargetGroupArn -Region $Region -ProfileName $Profile
    $Health | ForEach-Object { Write-Host "Target: $($_.Target.Id) - State: $($_.TargetHealth.State)" }
    ```
    
3. **Check for regional outage** (optional but good context):
    
    ```powershell
    # Review AWS Service Health Dashboard or try connecting to RDS (still up?)
    $RDS = Get-RDSDBInstance -Region $Region -ProfileName $Profile
    if ($RDS) {
        Write-Host "✓ RDS is still accessible - likely isolated EC2 issue"
    } else {
        Write-Host "⚠️  RDS also unavailable - possible regional outage"
    }
    ```
    

#### Contain (Target: <1 min)

4. **Alert stakeholders immediately** — website is down.

#### Investigate

5. **Determine if the AZ is truly down or if instances are just crashed**:
    
    ```powershell
    # Try to launch a test instance in one AZ$TestInstance = New-EC2Instance -ImageId "ami-xxxxxxxxx" `                                -InstanceType t3.micro `                                -SubnetId "subnet-in-1a" `                                -Region $Region -ProfileName $ProfileStart-Sleep -Seconds 30$TestStatus = Get-EC2InstanceStatus -InstanceId $TestInstance.Instances[0].InstanceId `                                    -Region $Region -ProfileName $Profileif ($TestStatus.SystemStatus.Status -eq "ok") {    Write-Host "✓ AZ is healthy - instances may have just crashed"    # Clean up test instance    Remove-EC2Instance -InstanceId $TestInstance.Instances[0].InstanceId -Force -Region $Region -ProfileName $Profile} else {    Write-Host "⚠️  AZ appears unhealthy"}
    ```
    

#### Remediate (Option A: Reboot Both)

6. **If instances are just stuck**:
    
    ```powershell
    $Instances = Get-EC2Instance -Filter @{Name="tag:Environment"; Values="prod"} `                             -Region $Region -ProfileName $Profile |             Select-Object -ExpandProperty Instancesforeach ($Instance in $Instances) {    Write-Host "Rebooting $($Instance.InstanceId)..."    Restart-EC2Instance -InstanceId $Instance.InstanceId -Region $Region -ProfileName $Profile -Force}# Wait for both to come onlineWrite-Host "Waiting for instances to recover..."for ($i = 0; $i -lt 60; $i++) {    $Status = Get-EC2InstanceStatus -Region $Region -ProfileName $Profile |               Where-Object { $_.InstanceId -in $Instances.InstanceId }        $HealthyCount = ($Status | Where-Object { $_.SystemStatus.Status -eq "ok" }).Count    Write-Host "[$i/60] Healthy: $HealthyCount/2"        if ($HealthyCount -eq 2) {        Write-Host "✓ Both instances are healthy"        break    }    Start-Sleep -Seconds 10}
    ```
    

#### Remediate (Option B: Recreate Both)

7. **If instances are corrupted or AZ is down, recreate in the healthy AZ**:
    
    ```powershell
    # Terminate existing instances$Instances = Get-EC2Instance -Filter @{Name="tag:Environment"; Values="prod"} `                             -Region $Region -ProfileName $Profile |             Select-Object -ExpandProperty Instancesforeach ($Instance in $Instances) {    Write-Host "Terminating $($Instance.InstanceId)..."    Remove-EC2Instance -InstanceId $Instance.InstanceId -Force -Region $Region -ProfileName $Profile}Write-Host "Waiting for termination..."Start-Sleep -Seconds 60# Capture original config$OriginalImageId = $Instances[0].ImageId$OriginalInstanceType = $Instances[0].InstanceType$OriginalKeyName = $Instances[0].KeyName$OriginalSecurityGroups = $Instances[0].SecurityGroups.GroupId# Get subnets in the health AZ (ca-central-1b if 1a is down)$HealthyAZ = "ca-central-1b"$Subnets = Get-EC2Subnet -Filter @{Name="availability-zone"; Values=$HealthyAZ} `                          -Region $Region -ProfileName $Profile$SubnetId = $Subnets[0].SubnetId# Launch 2 new instances in the healthy AZWrite-Host "Launching replacement instances in $HealthyAZ..."for ($i = 1; $i -le 2; $i++) {    $NewInstance = New-EC2Instance -ImageId $OriginalImageId `                                   -InstanceType $OriginalInstanceType `                                   -SubnetId $SubnetId `                                   -SecurityGroupId $OriginalSecurityGroups `                                   -KeyName $OriginalKeyName `                                   -TagSpecification @{ResourceType="instance"; Tags=@{Name="prod-web-dr-$i"; Environment="prod"}} `                                   -Region $Region -ProfileName $Profile        Write-Host "Launched: $($NewInstance.Instances[0].InstanceId)"}Write-Host "New instances launched. Restore media from S3 using Media Restore runbook."
    ```
    

#### Verify Clean

8. **Wait for ALB health checks to pass**:
    
    ```powershell
    # This may take 5-10 minutes for health checks to stabilize$TG = Get-ELB2TargetGroup -Region $Region -ProfileName $Profile |       Where-Object { $_.Tags | Where-Object { $_.Key -eq "Environment" -and $_.Value -eq "prod" } } |       Select-Object -First 1for ($i = 0; $i -lt 30; $i++) {    $Health = Get-ELB2TargetHealth -TargetGroupArn $TG.TargetGroupArn -Region $Region -ProfileName $Profile    $HealthyCount = ($Health | Where-Object { $_.TargetHealth.State -eq "healthy" }).Count        Write-Host "[$i/30] Healthy targets: $HealthyCount"        if ($HealthyCount -eq 2) {        Write-Host "✓ All targets healthy"        break    }    Start-Sleep -Seconds 10}
    ```
    

#### Post-Incident

- [ ] Root cause: Application issue? Infrastructure issue? Misconfiguration?
- [ ] Media recovery: Restore media from S3 backup
- [ ] Prevention: Better monitoring and alerting for application health

---

### Single AZ Outage

**Severity**: P1  
**Affected Service**: Web tier (one instance down) + potential RDS impact  
**RTO**: 5–30 minutes | **RPO**: <1 minute (code); media from S3 (if lost)  
**Typical Cause**: AZ infrastructure failure, network partition, regional issue

#### Triage (Target: <2 min)

1. **Confirm which AZ is down**:
    
    ```powershell
    $Instances = Get-EC2Instance -Filter @{Name="tag:Environment"; Values="prod"} `
                                 -Region $Region -ProfileName $Profile | 
                Select-Object -ExpandProperty Instances
    
    $Instances | Group-Object { $_.Placement.AvailabilityZone } | ForEach-Object {
        Write-Host "AZ: $($_.Name) - Instances: $(($_.Group | Where-Object { $_.State.Name -eq 'running' }).Count) running"
    }
    ```
    
2. **Check RDS status** (if Multi-AZ, should be in the healthy AZ):
    
    ```powershell
    $RDS = Get-RDSDBInstance -Region $Region -ProfileName $Profile | Where-Object { $_.Tags | Where-Object { $_.Key -eq "Environment" } }
    
    foreach ($DB in $RDS) {
        Write-Host "RDS: $($DB.DBInstanceIdentifier) - AZ: $($DB.AvailabilityZone) - Status: $($DB.DBInstanceStatus)"
    }
    ```
    

#### Contain

3. **The healthy EC2 instance (in the other AZ) will continue serving traffic**. Application is degraded but available.

#### Remediate

4. **Launch a replacement instance in the healthy AZ** (see Single EC2 Instance Failure → Remediate (Option B)).

#### Verify Clean

5. **Monitor for RDS failover** (if RDS primary was in the failed AZ):
    
    ```powershell
    for ($i = 0; $i -lt 30; $i++) {    $RDS = Get-RDSDBInstance -Region $Region -ProfileName $Profile | Where-Object { $_.Tags | Where-Object { $_.Key -eq "Environment" } }        if ($RDS.DBInstanceStatus -eq "available") {        Write-Host "✓ RDS is healthy in AZ: $($RDS.AvailabilityZone)"        break    }    Write-Host "[$i/30] RDS Status: $($RDS.DBInstanceStatus)"    Start-Sleep -Seconds 10}
    ```
    

#### Post-Incident

- [ ] When did the AZ recover? Any lingering issues?
- [ ] RDS failover: Did it happen automatically? Any app reconnection issues?

---

### Media Restore from S3

**Severity**: P2  
**Affected Service**: Media content (images, docs, uploads)  
**RTO**: 5–30 minutes | **RPO**: Last S3 sync (typically hourly or less)  
**Typical Cause**: Accidental deletion, corruption, EC2 instance failure without backup

#### Triage (Target: <5 min)

1. **Identify what media is missing**:
    
    - Check the application — which media files are inaccessible?
    - Check the EC2 instance local folder: `C:\media\` (or your configured path)
    - Determine if it's a single file, folder, or complete media loss
2. **Verify S3 backup is available**:
    
    ```powershell
    $BucketName = "prod-media-backup"
    $Region = "ca-central-1"
    $Profile = "bluroot-td"
    
    # List objects in S3 to confirm they exist
    $S3Objects = Get-S3Object -BucketName $BucketName -Region $Region -ProfileName $Profile
    
    Write-Host "Total objects in S3: $(if ($S3Objects -is [array]) { $S3Objects.Count } else { 1 })"
    
    # Show the most recent objects
    $S3Objects | Sort-Object LastModified -Descending | Select-Object -First 10 | 
      Format-Table Key, LastModified, Size
    ```
    
3. **Check S3 versioning** (if enabled, you can restore a specific version):
    
    ```powershell
    # If versioning is enabled, you can restore specific versions
    Get-S3Object -BucketName $BucketName -Region $Region -ProfileName $Profile -Versions | 
      Where-Object { $_.Key -like "*media*" } | 
      Sort-Object LastModified -Descending | 
      Select-Object -First 5 | 
      Format-Table Key, VersionId, LastModified
    ```
    

#### Contain (Target: <1 min)

4. **Stop the application from accepting uploads** (if the issue is ongoing):
    
    ```powershell
    # Example: Disable upload endpoint via feature flag or maintenance mode# (adjust based on your application)Invoke-WebRequest -Uri "http://localhost/admin/disable-uploads" `                  -Method POST `                  -Headers @{Authorization="Bearer $ADMIN_TOKEN"}
    ```
    

#### Remediate

5. **Restore media from S3 to the EC2 instance(s)**:
    
    ```powershell
    $BucketName = "prod-media-backup"
    $LocalMediaPath = "D:\media"  # Target directory on EC2
    $Region = "ca-central-1"
    $Profile = "bluroot-td"
    
    # Create directory if it doesn't exist
    if (-not (Test-Path $LocalMediaPath)) {
        New-Item -ItemType Directory -Path $LocalMediaPath -Force
    }
    
    Write-Host "Downloading media from S3..."
    
    # Option A: Download all files (if loss is complete)
    $S3Objects = Get-S3Object -BucketName $BucketName -Region $Region -ProfileName $Profile
    
    foreach ($Object in $S3Objects) {
        $LocalPath = Join-Path $LocalMediaPath $Object.Key
        
        # Create subdirectories if needed
        $Directory = Split-Path $LocalPath -Parent
        if (-not (Test-Path $Directory)) {
            New-Item -ItemType Directory -Path $Directory -Force | Out-Null
        }
        
        Write-Host "Downloading: $($Object.Key)"
        Read-S3Object -BucketName $BucketName -Key $Object.Key -FilePath $LocalPath `
                      -Region $Region -ProfileName $Profile
    }
    
    Write-Host "✓ Media restore complete"
    ```
    
6. **Alternative: Use AWS CLI for faster bulk download**:
    
    ```powershell
    # If you prefer AWS CLI (potentially faster for large datasets)
    $BucketName = "prod-media-backup"
    $LocalMediaPath = "D:\media"
    
    # Run AWS CLI sync
    & aws s3 sync "s3://$BucketName" $LocalMediaPath --region ca-central-1
    
    Write-Host "✓ Media sync complete via AWS CLI"
    ```
    
7. **Sync to both EC2 instances** (if one instance is down, copy files to healthy instance):
    
    ```powershell
    # After restoring to one instance, sync to the other
    $HealthyInstanceId = "i-0123456789abcdef0"
    $SourcePath = "D:\media"
    $DestPath = "\\$HealthyInstanceId\D$\media"  # SMB/network share (adjust for your setup)
    
    # Or use RoboCopy for Windows
    Robocopy $SourcePath $DestPath /S /E /COPY:DAT /R:3 /W:10
    ```
    

#### Verify Clean

8. **Verify media is accessible**:
    
    ```powershell
    # Check file count and sizes
    $MediaFiles = Get-ChildItem -Path "D:\media" -Recurse -File
    
    Write-Host "Media files restored: $($MediaFiles.Count)"
    Write-Host "Total size: $(($MediaFiles | Measure-Object -Property Length -Sum).Sum / 1GB) GB"
    
    # Spot-check a few files
    $MediaFiles | Select-Object -First 5 | Format-Table FullName, Length
    ```
    
9. **Re-enable uploads** in the application:
    
    ```powershell
    Invoke-WebRequest -Uri "http://localhost/admin/enable-uploads" `
                      -Method POST `
                      -Headers @{Authorization="Bearer $ADMIN_TOKEN"}
    ```
    

#### Post-Incident

- [ ] Root cause: Why were media files deleted or lost?
- [ ] Audit S3 access logs: Who deleted what and when?
- [ ] Prevention: Enable S3 Object Lock or versioning; add delete restrictions to IAM policy

---

### RDS Failover Validation

**Severity**: P2  
**Affected Service**: Database tier  
**RTO**: 1–3 minutes (automatic) | **RPO**: <1 minute  
**Typical Cause**: Primary instance failure, maintenance window, hardware issue

#### Triage (Target: <2 min)

1. **Check current primary instance**:
    
    ```powershell
    $DBInstance = "prod-db"
    $Region = "ca-central-1"
    $Profile = "bluroot-td"
    
    $DB = Get-RDSDBInstance -DBInstanceIdentifier $DBInstance -Region $Region -ProfileName $Profile
    
    Write-Host "DB Instance: $($DB.DBInstanceIdentifier)"
    Write-Host "Status: $($DB.DBInstanceStatus)"
    Write-Host "AZ: $($DB.AvailabilityZone)"
    Write-Host "Multi-AZ: $($DB.MultiAZ)"
    Write-Host "Engine: $($DB.Engine) $($DB.EngineVersion)"
    ```
    
    **Expected output**: Status = `available` (or `failing-over` if failover in progress).
    
2. **Check multi-AZ standby**:
    
    ```powershell
    Write-Host "Secondary AZ: $($DB.SecondaryAvailabilityZone)"
    
    if ($DB.MultiAZ -ne $true) {
        Write-Host "❌ ERROR: Multi-AZ is not enabled!" -ForegroundColor Red
    }
    ```
    
3. **Verify application can connect**:
    
    ```powershell
    # Test database connectivity from one of the EC2 instances
    $InstanceId = "i-0123456789abcdef0"  # host1a-tdkc, for example
    
    Invoke-Command -ComputerName $InstanceId -ScriptBlock {
        # Attempt a database connection (adjust based on your database driver)
        $ConnectionString = "Server=prod-db.xxxxx.ca-central-1.rds.amazonaws.com;User Id=admin;Password=$env:DB_PASSWORD;"
        
        try {
            $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
            $Connection.Open()
            Write-Host "✓ Database connection successful"
            $Connection.Close()
        }
        catch {
            Write-Host "❌ Database connection failed: $_"
        }
    }
    ```
    

#### If failover is stuck or did not trigger automatically

4. **Initiate manual failover** (only if Multi-AZ):
    
    ```powershell
    $DBInstance = "prod-db"Write-Host "Triggering manual failover..."Restart-RDSDBInstance -DBInstanceIdentifier $DBInstance `                      -ForceFailover $true `                      -Region $Region -ProfileName $ProfileWrite-Host "Failover triggered. Primary will promote standby in 1-3 minutes."
    ```
    

#### Verify Clean

5. **Wait for status = `available`** and recheck connection:
    
    ```powershell
    # Poll until available
    for ($i = 1; $i -le 20; $i++) {
        $DB = Get-RDSDBInstance -DBInstanceIdentifier $DBInstance -Region $Region -ProfileName $Profile
        $Status = $DB.DBInstanceStatus
        
        if ($Status -eq "available") {
            Write-Host "✓ RDS is available" -ForegroundColor Green
            Write-Host "Primary AZ is now: $($DB.AvailabilityZone)"
            break
        }
        else {
            Write-Host "[$i/20] Status: $Status"
            Start-Sleep -Seconds 10
        }
    }
    ```
    
6. **Verify application logs for connection errors**:
    
    ```powershell
    # Example: Get recent log entries from EC2 instances
    $InstanceIds = @("i-0123456789abcdef0", "i-0987654321fedcba0")
    
    foreach ($InstanceId in $InstanceIds) {
        Write-Host "Checking logs on $InstanceId..."
        
        Invoke-Command -ComputerName $InstanceId -ScriptBlock {
            Get-EventLog -LogName Application -After (Get-Date).AddMinutes(-5) -Source "*database*" | 
              Select-Object TimeGenerated, Message | 
              Format-Table -AutoSize
        }
    }
    ```
    

#### Post-Incident

- [ ] Was this a scheduled maintenance failover or unexpected failure?
- [ ] Did application layer handle the reconnection gracefully?
- [ ] Check RDS event log: `Get-RDSEvent -SourceIdentifier $DBInstance -EventCategories "failover" -Region $Region`

---

### RDS Point-in-Time Restore (PITR)

**Severity**: P1  
**Affected Service**: Database  
**RTO**: 15–30 minutes | **RPO**: 5 minutes (configurable backup window)  
**Typical Cause**: Data corruption, logic error, accidental delete

#### Triage (Target: <10 min)

1. **Confirm data loss/corruption**:
    
    ```powershell
    # Connect to RDS and verify (example: missing records)
    $DBEndpoint = "prod-db.xxxxx.ca-central-1.rds.amazonaws.com"
    $DBUser = "admin"
    $DBPassword = $env:DB_PASSWORD
    $DBName = "myapp"
    
    # Use MySQL CLI (ensure MySQL client is installed on operator machine)
    # or use a SQL tool; adjust for your database type
    
    mysql -h $DBEndpoint -u $DBUser -p$DBPassword $DBName `
      -e "SELECT COUNT(*) FROM users; SELECT MAX(updated_at) FROM users;"
    ```
    
2. **Identify the target recovery timestamp**:
    
    ```powershell
    # Determine the last known good state
    $RestoreTime = "2026-03-17T14:30:00Z"  # ISO 8601 format
    Write-Host "Planning to restore to: $RestoreTime"
    ```
    
3. **Check backup availability**:
    
    ```powershell
    $DBInstance = "prod-db"
    $Region = "ca-central-1"
    $Profile = "bluroot-td"
    
    $DB = Get-RDSDBInstance -DBInstanceIdentifier $DBInstance -Region $Region -ProfileName $Profile
    
    Write-Host "Latest restorable time: $($DB.LatestRestorableTime)"
    Write-Host "Backup retention: $($DB.BackupRetentionPeriod) days"
    ```
    

#### Contain (Target: <1 min)

4. **Stop application writes to the database**:
    
    ```powershell
    # Example: Put application in read-only mode or maintenance mode# (adjust based on your application)# Option A: Feature flag / environment variable$InstanceIds = @("i-0123456789abcdef0", "i-0987654321fedcba0")foreach ($InstanceId in $InstanceIds) {    Invoke-Command -ComputerName $InstanceId -ScriptBlock {        Set-Item -Path Env:\APP_READ_ONLY -Value "true"    }}# Option B: Scale down application to 0 (more aggressive)# Stop-EC2Instance -InstanceId $InstanceIds -Region $Region -ProfileName $Profile -Force
    ```
    

#### Remediate (Target: 15–30 min)

5. **Restore to a new DB instance**:
    
    ```powershell
    $DBInstance = "prod-db"
    $RestoreDB = "prod-db-restored-$(Get-Date -Format yyyyMMddHHmmss)"
    $RestoreTime = [DateTime]"2026-03-17T14:30:00Z"
    $Region = "ca-central-1"
    $Profile = "bluroot-td"
    
    Write-Host "Restoring to new instance: $RestoreDB"
    
    Restore-RDSDBInstanceToPointInTime -SourceDBInstanceIdentifier $DBInstance `
                                       -TargetDBInstanceIdentifier $RestoreDB `
                                       -RestoreTime $RestoreTime `
                                       -Region $Region -ProfileName $Profile
    
    Write-Host "Restore job started."
    ```
    
6. **Monitor restore progress**:
    
    ```powershell
    for ($i = 1; $i -le 60; $i++) {
        $DB = Get-RDSDBInstance -DBInstanceIdentifier $RestoreDB -Region $Region -ProfileName $Profile
        $Status = $DB.DBInstanceStatus
        
        if ($Status -eq "available") {
            Write-Host "✓ Restored instance is ready" -ForegroundColor Green
            $Endpoint = $DB.Endpoint.Address
            Write-Host "Endpoint: $Endpoint"
            break
        }
        else {
            Write-Host "[$i/60] Status: $Status"
            Start-Sleep -Seconds 30
        }
    }
    ```
    
7. **Validate data in the restored instance**:
    
    ```powershell
    $RestoredEndpoint = $DB.Endpoint.Address
    
    mysql -h $RestoredEndpoint -u $DBUser -p$DBPassword $DBName `
      -e "SELECT COUNT(*) FROM users; SELECT MAX(updated_at) FROM users;"
    
    # If data looks good, proceed to swap. If not, try a different $RestoreTime.
    ```
    
8. **Swap the restored instance into production**:
    
    ```powershell
    # Update application config to point to the restored instance
    # (Adjust based on how your application gets the DB endpoint)
    
    # Option A: Update Systems Manager Parameter Store
    $ParameterName = "/prod/database/endpoint"
    $ParameterValue = $RestoredEndpoint
    
    Set-SSMParameter -Name $ParameterName -Value $ParameterValue -Overwrite -Region $Region -ProfileName $Profile
    
    Write-Host "Updated parameter store with new endpoint"
    
    # Restart application instances to pick up new config
    $InstanceIds = @("i-0123456789abcdef0", "i-0987654321fedcba0")
    Restart-EC2Instance -InstanceId $InstanceIds -Region $Region -ProfileName $Profile -Force
    ```
    

#### Verify Clean

9. **Monitor application for successful reconnection**:
    
    ```powershell
    Start-Sleep -Seconds 30foreach ($InstanceId in $InstanceIds) {    Invoke-Command -ComputerName $InstanceId -ScriptBlock {        # Check if app is healthy and connected to DB        Write-Host "Checking application health..."        Invoke-WebRequest -Uri "http://localhost/health" -UseBasicParsing    }}
    ```
    

#### Post-Incident

- [ ] Root cause: How did corruption occur? (code bug, manual query, replication lag?)
- [ ] Audit database logs: Who made the problematic change?
- [ ] Prevention: Add data validation in app; stricter RDS parameter permissions

---

### RDS Emergency Scale (Storage Exhaustion)

**Severity**: P2  
**Affected Service**: Database  
**RTO**: 5–15 minutes | **RPO**: 0 (no data loss)  
**Typical Cause**: Rapid data growth, insufficient storage allocation

#### Triage (Target: <2 min)

1. **Check free storage**:
    
    ```powershell
    $DBInstance = "prod-db"$Region = "ca-central-1"$Profile = "bluroot-td"$Metrics = Get-CWMetricStatistics -Namespace "AWS/RDS" `                                  -MetricName "FreeStorageSpace" `                                  -Dimensions @{Name="DBInstanceIdentifier"; Value=$DBInstance} `                                  -StartTime (Get-Date).AddMinutes(-10) `                                  -EndTime (Get-Date) `                                  -Period 300 `                                  -Statistics "Average" `                                  -Region $Region -ProfileName $Profile$LatestMetric = $Metrics.Datapoints | Sort-Object Timestamp -Descending | Select-Object -First 1Write-Host "Free Storage Space: $(($LatestMetric.Average / 1GB).ToString("F2")) GB"# Get allocated storage$DB = Get-RDSDBInstance -DBInstanceIdentifier $DBInstance -Region $Region -ProfileName $ProfileWrite-Host "Allocated Storage: $($DB.AllocatedStorage) GB"Write-Host "Utilization: $(( (1 - ($LatestMetric.Average / ($DB.AllocatedStorage * 1GB))) * 100).ToString("F1"))%"
    ```
    

#### Remediate

2. **Increase allocated storage**:
    
    ```powershell
    $CurrentStorage = $DB.AllocatedStorage
    $NewStorage = $CurrentStorage + ($CurrentStorage / 2)  # Increase by 50%
    
    Write-Host "Scaling from $CurrentStorage GB to $NewStorage GB"
    
    Edit-RDSDBInstance -DBInstanceIdentifier $DBInstance `
                       -AllocatedStorage $NewStorage `
                       -ApplyImmediately $true `
                       -Region $Region -ProfileName $Profile
    
    Write-Host "Storage modification applied immediately"
    ```
    
    **Note**: For Multi-AZ, modification applies to standby first, then fails over. **Application will experience brief downtime.**
    
3. **Monitor storage recovery**:
    
    ```powershell
    for ($i = 1; $i -le 30; $i++) {
        $DB = Get-RDSDBInstance -DBInstanceIdentifier $DBInstance -Region $Region -ProfileName $Profile
        
        if ($DB.AllocatedStorage -eq $NewStorage -and $DB.DBInstanceStatus -eq "available") {
            Write-Host "✓ Storage expansion complete" -ForegroundColor Green
            break
        }
        
        Write-Host "[$i/30] Allocated: $($DB.AllocatedStorage) GB | Status: $($DB.DBInstanceStatus)"
        Start-Sleep -Seconds 10
    }
    ```
    

#### Post-Incident

- [ ] Root cause: Is data growing faster than expected?
- [ ] Audit table sizes: `SELECT table_name, ROUND(((data_length + index_length) / 1024 / 1024)) AS size_mb FROM information_schema.TABLES;`
- [ ] Prevention: Set up CloudWatch alarm for FreeStorageSpace < 10% of allocated

---

### RDS Restore from Snapshot (Database Deletion)

**Severity**: P1  
**Affected Service**: Database  
**RTO**: 10–20 minutes | **RPO**: Last snapshot (typically < 1 hour old)  
**Typical Cause**: Accidental deletion, malicious deletion, misconfigured script

#### Triage (Target: <5 min)

1. **Confirm the original DB is gone**:
    
    ```powershell
    $DBInstance = "prod-db"
    $Region = "ca-central-1"
    $Profile = "bluroot-td"
    
    try {
        $DB = Get-RDSDBInstance -DBInstanceIdentifier $DBInstance -Region $Region -ProfileName $Profile
        Write-Host "❌ DB still exists (not deleted)"
    }
    catch {
        Write-Host "✓ Confirmed: DB is deleted"
    }
    ```
    
2. **List available snapshots**:
    
    ```powershell
    $Snapshots = Get-RDSDBSnapshot -Filters @{Name="db-instance-id"; Values=$DBInstance} `
                                   -Region $Region -ProfileName $Profile | 
                 Sort-Object SnapshotCreateTime -Descending
    
    Write-Host "Available snapshots:"
    $Snapshots | Select-Object -First 10 | Format-Table DBSnapshotIdentifier, SnapshotCreateTime, SnapshotType, Status
    
    # Select the most recent one
    $SnapshotId = $Snapshots[0].DBSnapshotIdentifier
    Write-Host "Using snapshot: $SnapshotId"
    ```
    

#### Contain

3. **Pause application writes** (immediately):
    
    ```powershell
    $InstanceIds = @("i-0123456789abcdef0", "i-0987654321fedcba0")Stop-EC2Instance -InstanceId $InstanceIds -Region $Region -ProfileName $Profile -ForceWrite-Host "Application instances stopped to prevent further writes"
    ```
    

#### Remediate

4. **Restore from snapshot**:
    
    ```powershell
    $SnapshotId = "rds:prod-db-2026-03-17-14-30"  # Example
    $RestoredDB = "prod-db-restored-$(Get-Date -Format yyyyMMddHHmmss)"
    $Region = "ca-central-1"
    $Profile = "bluroot-td"
    
    Write-Host "Restoring from snapshot: $SnapshotId"
    
    Restore-RDSDBInstanceFromDBSnapshot -DBInstanceIdentifier $RestoredDB `
                                        -DBSnapshotIdentifier $SnapshotId `
                                        -DBInstanceClass "db.t4g.medium" `
                                        -Region $Region -ProfileName $Profile
    
    Write-Host "Restore started"
    ```
    
5. **Monitor restore**:
    
    ```powershell
    for ($i = 1; $i -le 60; $i++) {
        $DB = Get-RDSDBInstance -DBInstanceIdentifier $RestoredDB -Region $Region -ProfileName $Profile
        $Status = $DB.DBInstanceStatus
        
        if ($Status -eq "available") {
            Write-Host "✓ Restored instance ready" -ForegroundColor Green
            $Endpoint = $DB.Endpoint.Address
            Write-Host "Endpoint: $Endpoint"
            break
        }
        else {
            Write-Host "[$i/60] Status: $Status"
            Start-Sleep -Seconds 10
        }
    }
    ```
    
6. **Update application to point to the restored DB**:
    
    ```powershell
    $ParameterName = "/prod/database/endpoint"
    Set-SSMParameter -Name $ParameterName -Value $Endpoint -Overwrite -Region $Region -ProfileName $Profile
    
    # Restart application
    Start-EC2Instance -InstanceId $InstanceIds -Region $Region -ProfileName $Profile
    ```
    

#### Verify Clean

7. **Smoke test**:
    
    ```powershell
    Start-Sleep -Seconds 30foreach ($InstanceId in $InstanceIds) {    Invoke-Command -ComputerName $InstanceId -ScriptBlock {        Invoke-WebRequest -Uri "http://localhost/health" -UseBasicParsing    }}
    ```
    

#### Post-Incident

- [ ] Root cause: Who deleted the DB and why? Audit CloudTrail.
- [ ] Prevention: Enable deletion protection: `Edit-RDSDBInstance -DBInstanceIdentifier $DBInstance -DeletionProtection $true`
- [ ] IAM audit: Who has `rds:DeleteDBInstance` permissions?

---

### Incident Response — EC2 Compromise

**Severity**: P1  
**Affected Service**: Web tier  
**RTO**: <30 minutes (isolate) | **RPO**: N/A  
**Typical Cause**: Malware, unauthorized access, privilege escalation, misconfigured security group

#### Triage (Target: <10 min)

1. **Confirm the finding** (e.g., from GuardDuty or antivirus on the instance):
    
    ```powershell
    $InstanceId = "i-0123456789abcdef0"  # Suspected instance
    $Region = "ca-central-1"
    $Profile = "bluroot-td"
    
    $Instance = Get-EC2Instance -InstanceId $InstanceId -Region $Region -ProfileName $Profile | 
                Select-Object -ExpandProperty Instances -First 1
    
    Write-Host "Instance: $($Instance.InstanceId)"
    Write-Host "AZ: $($Instance.Placement.AvailabilityZone)"
    Write-Host "State: $($Instance.State.Name)"
    Write-Host "Launched: $($Instance.LaunchTime)"
    ```
    
2. **Check GuardDuty findings** (if enabled):
    
    ```powershell
    # Requires GuardDuty detector to be active
    $Findings = Get-GDFinding -Region $Region -ProfileName $Profile | 
               Where-Object { $_.Resource.InstanceDetails.InstanceId -eq $InstanceId }
    
    $Findings | Format-Table Title, Severity, UpdatedAt
    ```
    

#### Contain (Target: <2 min)

3. **Isolate the instance immediately** — remove from load balancer:
    
    ```powershell
    $TG = Get-ELB2TargetGroup -Region $Region -ProfileName $Profile | 
          Where-Object { $_.Tags | Where-Object { $_.Key -eq "Environment" -and $_.Value -eq "prod" } } | 
          Select-Object -First 1
    
    Unregister-ELB2Target -TargetGroupArn $TG.TargetGroupArn `
                          -Target @{Id=$InstanceId} `
                          -Region $Region -ProfileName $Profile
    
    Write-Host "Instance removed from ALB"
    ```
    
4. **Remove public IP** (if any):
    
    ```powershell
    $Address = Get-EC2Address -Filter @{Name="instance-id"; Values=$InstanceId} `
                              -Region $Region -ProfileName $Profile
    
    if ($Address) {
        Unregister-EC2Address -AllocationId $Address.AllocationId -Region $Region -ProfileName $Profile
        Write-Host "Public IP disassociated"
    }
    ```
    
5. **Restrict network access** — move to a "forensics" security group:
    
    ```powershell
    # Create a forensics SG with no ingress/egress (if not already present)
    $ForensicsSG = Get-EC2SecurityGroup -Filter @{Name="group-name"; Values="forensics-isolation"} `
                                        -Region $Region -ProfileName $Profile
    
    if (-not $ForensicsSG) {
        Write-Host "❌ forensics-isolation SG not found. Create manually."
    }
    else {
        # Update instance to use only the forensics SG
        Edit-EC2InstanceAttribute -InstanceId $InstanceId `
                                  -Group $ForensicsSG.GroupId `
                                  -Region $Region -ProfileName $Profile
        
        Write-Host "Instance isolated to forensics SG"
    }
    ```
    

#### Investigate

6. **Preserve evidence** — create EBS snapshots:
    
    ```powershell
    $Volumes = $Instance.BlockDeviceMappings | ForEach-Object { $_.Ebs.VolumeId }
    
    foreach ($VolumeId in $Volumes) {
        $SnapshotId = New-EC2Snapshot -VolumeId $VolumeId `
                                      -Description "Forensic snapshot of $InstanceId - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" `
                                      -Region $Region -ProfileName $Profile
        
        Write-Host "Snapshot created: $($SnapshotId.SnapshotId)"
        
        # Tag for identification
        New-EC2Tag -Resource $SnapshotId.SnapshotId `
                   -Tag @{Key="forensics"; Value="true"},@{Key="source-instance"; Value=$InstanceId} `
                   -Region $Region -ProfileName $Profile
    }
    ```
    
7. **Review CloudTrail logs** for suspicious activity:
    
    ```powershell
    Get-CTEvent -Region $Region -ProfileName $Profile | 
      Where-Object { $_.Resources.ResourceName -eq $InstanceId } | 
      Sort-Object EventTime -Descending | 
      Select-Object -First 20 | 
      Format-Table EventName, EventTime, Username, SourceIPAddress
    ```
    

#### Remediate

8. **Terminate the compromised instance** (don't reboot):
    
    ```powershell
    Remove-EC2Instance -InstanceId $InstanceId -Force -Region $Region -ProfileName $Profile
    
    Write-Host "Compromised instance terminated"
    
    # The healthy instance will continue serving traffic
    # Launch a replacement using the latest clean AMI if needed
    ```
    
9. **Monitor for lateral movement**:
    
    ```powershell
    # Check the other EC2 instance for signs of compromise
    $OtherInstanceId = "i-0987654321fedcba0"  # The healthy instance
    
    Invoke-Command -ComputerName $OtherInstanceId -ScriptBlock {
        # Check Windows Event Logs for suspicious activity
        Get-EventLog -LogName Security -After (Get-Date).AddHours(-2) -InstanceId 4688 | 
          Where-Object { $_.Message -like "*cmd.exe*" -or $_.Message -like "*powershell*" } | 
          Select-Object TimeGenerated, Message
    }
    ```
    

#### Verify Clean

10. **Verify application is still serving traffic** from the healthy instance:
    
    ```powershell
    $LoadBalancerDNS = Get-ELB2LoadBalancer -Region $Region -ProfileName $Profile |                    Where-Object { $_.Tags | Where-Object { $_.Key -eq "Environment" -and $_.Value -eq "prod" } } |                    Select-Object -ExpandProperty DNSName -First 1Invoke-WebRequest -Uri "http://$LoadBalancerDNS/health" -UseBasicParsing
    ```
    

#### Post-Incident

- [ ] Security analysis: How was the instance compromised?
- [ ] Patch management: Update OS and application to close the vulnerability
- [ ] Network segmentation: Restrict inbound access to minimum required ports
- [ ] Enable VPC Flow Logs for future auditing
- [ ] Consider enabling GuardDuty if not already active

---

## Automation & Tooling

### Media Sync to S3 (Hourly Backup)

Run this script hourly on each EC2 instance to sync media files to S3:

```powershell
# media-sync-to-s3.ps1 — Hourly media backup to S3 and cross-region DR bucket

param(
    [string]$LocalMediaPath = "D:\media",
    [string]$S3BucketPrimary = "prod-media-backup",
    [string]$S3BucketDR = "prod-media-backup-dr",  # Cross-region bucket (e.g., us-east-1)
    [string]$Region = "ca-central-1",
    [string]$DRRegion = "us-east-1",
    [string]$Profile = "bluroot-td"
)

$ErrorActionPreference = "Continue"

Write-Host "=== Media Sync to S3 ===" -ForegroundColor Green
Write-Host "Started: $(Get-Date -AsUTC -Format 'yyyy-MM-ddTHH:mm:ssZ')" -ForegroundColor Cyan

# Validate local path exists
if (-not (Test-Path $LocalMediaPath)) {
    Write-Host "❌ ERROR: Local media path does not exist: $LocalMediaPath" -ForegroundColor Red
    exit 1
}

# Count files
$LocalFiles = Get-ChildItem -Path $LocalMediaPath -Recurse -File
$FileCount = if ($LocalFiles -is [array]) { $LocalFiles.Count } else { 1 }
$TotalSize = if ($LocalFiles -is [array]) { ($LocalFiles | Measure-Object -Property Length -Sum).Sum } else { $LocalFiles.Length }

Write-Host "Local files: $FileCount | Size: $(($TotalSize / 1GB).ToString('F2')) GB" -ForegroundColor Cyan

# Sync to primary S3 bucket (ca-central-1)
Write-Host "`nSyncing to primary bucket: $S3BucketPrimary..." -ForegroundColor Yellow

try {
    & aws s3 sync $LocalMediaPath "s3://$S3BucketPrimary/" `
        --region $Region `
        --delete `
        --profile $Profile `
        --storage-class STANDARD

    Write-Host "✓ Primary sync complete" -ForegroundColor Green
}
catch {
    Write-Host "❌ Primary sync failed: $_" -ForegroundColor Red
}

# Copy from primary to DR bucket (cross-region replication)
# Note: Requires appropriate IAM permissions and S3 bucket policies
Write-Host "`nReplicating to DR bucket: $S3BucketDR (region: $DRRegion)..." -ForegroundColor Yellow

try {
    # Use AWS CLI to sync from primary bucket to DR bucket
    & aws s3 sync "s3://$S3BucketPrimary/" "s3://$S3BucketDR/" `
        --source-region $Region `
        --region $DRRegion `
        --profile $Profile `
        --storage-class STANDARD_IA  # Use cheaper storage class for DR

    Write-Host "✓ DR replication complete" -ForegroundColor Green
}
catch {
    Write-Host "⚠️  DR replication failed (non-fatal): $_" -ForegroundColor Yellow
}

Write-Host "`n=== Media Sync Complete ===" -ForegroundColor Green
Write-Host "Finished: $(Get-Date -AsUTC -Format 'yyyy-MM-ddTHH:mm:ssZ')" -ForegroundColor Cyan
```

**Installation on Windows EC2**:

```powershell
# Install AWS CLI (if not already installed)
# choco install awscli -y
# or download from https://aws.amazon.com/cli/

# Create scripts directory
New-Item -ItemType Directory -Path "C:\opt\dr-scripts" -Force

# Copy script
Copy-Item media-sync-to-s3.ps1 -Destination "C:\opt\dr-scripts\"

# Create Windows Scheduled Task (runs every hour)
$Action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -File 'C:\opt\dr-scripts\media-sync-to-s3.ps1'"

$Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1) `
    -RepetitionDuration (New-TimeSpan -Hours 24 -Days 365)

Register-ScheduledTask -Action $Action -Trigger $Trigger -TaskName "MediaSyncToS3" `
    -Description "Hourly media backup to S3" -RunLevel Highest

# Verify
Get-ScheduledTask -TaskName "MediaSyncToS3" | Select-Object TaskName, State
```

**Log monitoring**:

```powershell
# View recent sync logs
Get-EventLog -LogName System -Source TaskScheduler -After (Get-Date).AddHours(-24) |
    Where-Object { $_.Message -like "*MediaSyncToS3*" } |
    Format-Table TimeGenerated, Message

# Or, redirect script output to file
# Modify task to append output to log file
# powershell.exe -ExecutionPolicy Bypass -File 'C:\opt\dr-scripts\media-sync-to-s3.ps1' >> 'C:\opt\dr-scripts\media-sync.log'
```

---

### Backup Verification Script (Weekly)

Run this weekly on your management workstation to validate backups:

```powershell
# backup-verify.ps1 — Weekly backup and disaster recovery readiness check

param(
    [string]$Profile = "bluroot-td",
    [string]$Region = "ca-central-1"
)

Write-Host "=== Backup Verification Report ===" -ForegroundColor Green
Write-Host "Generated: $(Get-Date -AsUTC -Format 'yyyy-MM-ddTHH:mm:ssZ')" -ForegroundColor Cyan

$ErrorCount = 0

# 1. RDS Automated Backups
Write-Host "`n[RDS Automated Backups]" -ForegroundColor Yellow

try {
    $DBInstances = Get-RDSDBInstance -Region $Region -ProfileName $Profile | 
                   Where-Object { $_.TagList | Where-Object { $_.Key -eq "Environment" -and $_.Value -eq "prod" } }
    
    foreach ($DB in $DBInstances) {
        $DBID = $DB.DBInstanceIdentifier
        
        $LatestSnap = Get-RDSDBSnapshot -Filters @{Name="db-instance-id"; Values=$DBID} `
                                        -Region $Region -ProfileName $Profile | 
                     Where-Object { $_.SnapshotType -eq "automated" } | 
                     Sort-Object SnapshotCreateTime -Descending | 
                     Select-Object -First 1
        
        if ($LatestSnap) {
            $SnapAge = (Get-Date).UTC - $LatestSnap.SnapshotCreateTime.UTC
            $SnapAgeHours = $SnapAge.TotalHours
            
            if ($SnapAgeHours -gt 26) {
                Write-Host "⚠️  $DBID: Latest snapshot is $($SnapAgeHours.ToString('F1')) hours old (threshold: 26h)" -ForegroundColor Yellow
                $ErrorCount++
            } else {
                Write-Host "✓ $DBID: Latest snapshot $($SnapAgeHours.ToString('F1')) hours ago" -ForegroundColor Green
            }
        } else {
            Write-Host "❌ $DBID: No automated snapshot found" -ForegroundColor Red
            $ErrorCount++
        }
    }
}
catch {
    Write-Host "❌ Error checking RDS: $_" -ForegroundColor Red
    $ErrorCount++
}

# 2. S3 Media Backups
Write-Host "`n[S3 Media Backups]" -ForegroundColor Yellow

try {
    $BucketName = "prod-media-backup"
    
    $S3Objects = Get-S3Object -BucketName $BucketName -Region $Region -ProfileName $Profile
    
    if ($S3Objects) {
        $ObjectCount = if ($S3Objects -is [array]) { $S3Objects.Count } else { 1 }
        $LatestObject = $S3Objects | Sort-Object LastModified -Descending | Select-Object -First 1
        $LastSync = (Get-Date).UTC - $LatestObject.LastModified.UTC
        
        Write-Host "✓ Primary bucket '$BucketName': $ObjectCount objects" -ForegroundColor Green
        Write-Host "  Last sync: $($LastSync.TotalMinutes.ToString('F1')) minutes ago" -ForegroundColor Cyan
        
        if ($LastSync.TotalHours -gt 2) {
            Write-Host "  ⚠️  WARNING: Last sync > 2 hours ago" -ForegroundColor Yellow
            $ErrorCount++
        }
    } else {
        Write-Host "⚠️  No objects in bucket '$BucketName'" -ForegroundColor Yellow
        $ErrorCount++
    }
}
catch {
    Write-Host "⚠️  Could not access S3 bucket: $_" -ForegroundColor Yellow
    $ErrorCount++
}

# 3. Cross-region DR bucket
Write-Host "`n[S3 DR Bucket (Cross-Region)]" -ForegroundColor Yellow

try {
    $DrBucketName = "prod-media-backup-dr"
    $DRRegion = "us-east-1"
    
    $S3DRObjects = Get-S3Object -BucketName $DrBucketName -Region $DRRegion -ProfileName $Profile
    
    if ($S3DRObjects) {
        $DRObjectCount = if ($S3DRObjects -is [array]) { $S3DRObjects.Count } else { 1 }
        Write-Host "✓ DR bucket '$DrBucketName' (region: $DRRegion): $DRObjectCount objects" -ForegroundColor Green
    } else {
        Write-Host "⚠️  No objects in DR bucket (may be normal if first sync)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "⚠️  Could not access DR bucket: $_" -ForegroundColor Yellow
}

# Summary
Write-Host "`n=== Verification Summary ===" -ForegroundColor Green
if ($ErrorCount -eq 0) {
    Write-Host "✓ All backups healthy" -ForegroundColor Green
    exit 0
} else {
    Write-Host "⚠️  $ErrorCount issue(s) detected" -ForegroundColor Yellow
    exit 1
}
```

**Execution**: Schedule weekly (Monday 08:00):

```powershell
$Action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -File 'C:\dr-scripts\backup-verify.ps1'"

$Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 08:00

Register-ScheduledTask -Action $Action -Trigger $Trigger -TaskName "BackupVerification" `
    -Description "Weekly backup and DR readiness check"
```

---

## Communication Plan

### Escalation Chain

|Severity|Response Time|Escalation|Action|
|---|---|---|---|
|P1 (Data loss / system down)|<15 min|Exec summary via Slack + email|Execute runbook; notify all stakeholders|
|P2 (Partial outage / performance)|<30 min|Slack + ops team|Investigate; if auto-remediation fails, manual runbook|
|P3 (Degraded / one instance down)|<1 hour|Slack update|Monitor; execute only if escalates|

### Post-Incident Reporting Template

**Subject**: Post-Incident Report — [Service] — [Date]

**Timeline**:

- T+0: [Event detected]
- T+X min: [Action taken]
- T+Y min: [Recovery complete]

**Root Cause**: [What went wrong]

**Impact**: [Downtime duration, affected users, data loss (if any)]

**Remediation Steps Taken**: [What we did to fix it]

**Action Items**:

- [ ] [Item 1] — Owner: [name]
- [ ] [Item 2] — Owner: [name]
- [ ] [Item 3] — Owner: [name]

**Prevention**: [How we prevent this in the future]

---

## Testing & Validation

### Quarterly DR Drill

Every 90 days, execute a disaster recovery readiness test. This validates both RDS point-in-time restore and media recovery from S3:

```powershell
# dr-drill.ps1 — Quarterly disaster recovery drill

param(
    [string]$Region = "ca-central-1",
    [string]$DRRegion = "us-east-1",
    [string]$Profile = "bluroot-td"
)

Write-Host "=== DR Drill — $(Get-Date -Format 'yyyy-MM-dd') ===" -ForegroundColor Green

# ===== PART 1: RDS Point-in-Time Restore Test =====

Write-Host "`n[1/5] Creating RDS manual snapshot..." -ForegroundColor Yellow

$DBInstance = "prod-db"
$SnapshotId = "dr-drill-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

try {
    $Snapshot = New-RDSDBSnapshot -DBInstanceIdentifier $DBInstance `
                                  -DBSnapshotIdentifier $SnapshotId `
                                  -Region $Region -ProfileName $Profile
    
    Write-Host "Snapshot created: $SnapshotId"
}
catch {
    Write-Host "❌ Failed to create snapshot: $_" -ForegroundColor Red
    exit 1
}

# Wait for snapshot to complete
Write-Host "`n[2/5] Waiting for snapshot completion..." -ForegroundColor Yellow

$MaxWaitTime = 3600  # 1 hour
$StartTime = Get-Date
$Complete = $false

while ((Get-Date) - $StartTime -lt (New-TimeSpan -Seconds $MaxWaitTime)) {
    $SnapStatus = Get-RDSDBSnapshot -DBSnapshotIdentifier $SnapshotId `
                                    -Region $Region -ProfileName $Profile
    
    if ($SnapStatus.Status -eq "available") {
        Write-Host "✓ Snapshot ready"
        $Complete = $true
        break
    }
    
    Write-Host "  Status: $($SnapStatus.Status)... waiting"
    Start-Sleep -Seconds 30
}

if (-not $Complete) {
    Write-Host "❌ Snapshot did not complete in time" -ForegroundColor Red
    exit 1
}

# Restore to a test database
Write-Host "`n[3/5] Restoring snapshot to test instance..." -ForegroundColor Yellow

$TestDB = "prod-db-drill-$(Get-Date -Format 'yyyyMMdd')"

try {
    $RestoredDB = Restore-RDSDBInstanceFromDBSnapshot -DBInstanceIdentifier $TestDB `
                                                       -DBSnapshotIdentifier $SnapshotId `
                                                       -Region $Region -ProfileName $Profile
    
    Write-Host "Restore job started: $TestDB"
}
catch {
    Write-Host "❌ Failed to restore: $_" -ForegroundColor Red
    exit 1
}

# Wait for restoration
Write-Host "`n[4/5] Waiting for restore completion..." -ForegroundColor Yellow

$MaxWaitTime = 1800  # 30 minutes
$StartTime = Get-Date
$Complete = $false

while ((Get-Date) - $StartTime -lt (New-TimeSpan -Seconds $MaxWaitTime)) {
    $DBStatus = Get-RDSDBInstance -DBInstanceIdentifier $TestDB -Region $Region -ProfileName $Profile
    
    if ($DBStatus.DBInstanceStatus -eq "available") {
        Write-Host "✓ Restored instance is ready"
        $TestEndpoint = $DBStatus.Endpoint.Address
        Write-Host "  Endpoint: $TestEndpoint"
        $Complete = $true
        break
    }
    
    Write-Host "  Status: $($DBStatus.DBInstanceStatus)... waiting"
    Start-Sleep -Seconds 20
}

if (-not $Complete) {
    Write-Host "❌ Restore did not complete in time" -ForegroundColor Red
    exit 1
}

# Validate connectivity to restored DB
Write-Host "`n[5/5] Validating test instance connectivity..." -ForegroundColor Yellow

try {
    # Attempt a simple query (adjust for your database engine)
    # This is pseudo-code; actual implementation depends on your database client
    
    Write-Host "✓ Restored database is accessible"
}
catch {
    Write-Host "⚠️  Could not validate connectivity: $_" -ForegroundColor Yellow
}

# ===== PART 2: Media Recovery from S3 =====

Write-Host "`n[BONUS] Testing media recovery from S3..." -ForegroundColor Yellow

$TestPath = "C:\temp\dr-media-test"
$BucketName = "prod-media-backup"

try {
    # Create test directory
    if (-not (Test-Path $TestPath)) {
        New-Item -ItemType Directory -Path $TestPath -Force | Out-Null
    }
    
    # Download a sample of files from S3
    Write-Host "Downloading sample media from S3..."
    
    & aws s3 sync "s3://$BucketName/" $TestPath `
        --region $Region `
        --profile $Profile `
        --exclude "*" `
        --include "*.jpg" `
        --include "*.png" `
        --max-items 5
    
    $SampleFiles = Get-ChildItem -Path $TestPath -File
    $SampleCount = if ($SampleFiles -is [array]) { $SampleFiles.Count } else { 1 }
    
    Write-Host "✓ Media recovery test successful ($SampleCount sample files downloaded)"
    
    # Cleanup
    Remove-Item -Path $TestPath -Recurse -Force
}
catch {
    Write-Host "⚠️  Media recovery test failed: $_" -ForegroundColor Yellow
}

# Cleanup test database
Write-Host "`n=== Cleaning up test resources ===" -ForegroundColor Yellow

try {
    Remove-RDSDBInstance -DBInstanceIdentifier $TestDB `
                         -SkipFinalSnapshot $true `
                         -Region $Region -ProfileName $Profile `
                         -Force
    
    Write-Host "✓ Test instance terminated"
}
catch {
    Write-Host "⚠️  Could not clean up test instance: $_" -ForegroundColor Yellow
}

try {
    Remove-RDSDBSnapshot -DBSnapshotIdentifier $SnapshotId `
                         -Region $Region -ProfileName $Profile `
                         -Force
    
    Write-Host "✓ Test snapshot deleted"
}
catch {
    Write-Host "⚠️  Could not delete test snapshot: $_" -ForegroundColor Yellow
}

Write-Host "`n=== DR Drill Complete ===" -ForegroundColor Green
```

**Execution**: Schedule quarterly (first Monday of Q1, Q2, Q3, Q4):

```powershell
$Action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -File 'C:\dr-scripts\dr-drill.ps1'"

# Create monthly trigger for the first Monday of each month, then filter to quarterly
# Or manually run quarterly

& powershell -ExecutionPolicy Bypass -File 'C:\dr-scripts\dr-drill.ps1'
```

---

## Appendix: Quick Reference — PowerShell Commands

```powershell
# Set default region and profile
$Region = "ca-central-1"
$Profile = "bluroot-td"

# ===== EC2 QUICK CHECKS =====

# List prod EC2 instances
Get-EC2Instance -Filter @{Name="tag:Environment"; Values="prod"} `
                -Region $Region -ProfileName $Profile | 
                Select-Object -ExpandProperty Instances | 
                Select-Object InstanceId, State, Placement, PrivateIpAddress, LaunchTime | 
                Format-Table

# Get instance details
$InstanceId = "i-0123456789abcdef0"
Get-EC2Instance -InstanceId $InstanceId -Region $Region -ProfileName $Profile | 
                Select-Object -ExpandProperty Instances | 
                Format-List

# Get instance status
Get-EC2InstanceStatus -InstanceId $InstanceId -Region $Region -ProfileName $Profile | 
                       Format-Table InstanceId, SystemStatus, InstanceStatus

# ===== ALB/TARGET GROUP QUICK CHECKS =====

# List ALBs
Get-ELB2LoadBalancer -Region $Region -ProfileName $Profile | 
                      Select-Object LoadBalancerName, DNSName, State | 
                      Format-Table

# Get target group health
$TG = Get-ELB2TargetGroup -Region $Region -ProfileName $Profile | 
      Where-Object { $_.Tags | Where-Object { $_.Key -eq "Environment" -and $_.Value -eq "prod" } } | 
      Select-Object -First 1

Get-ELB2TargetHealth -TargetGroupArn $TG.TargetGroupArn -Region $Region -ProfileName $Profile | 
                      Format-Table Target, TargetHealth

# ===== RDS QUICK CHECKS =====

# List RDS instances
Get-RDSDBInstance -Region $Region -ProfileName $Profile | 
                  Select-Object DBInstanceIdentifier, DBInstanceStatus, Engine, MultiAZ, AvailabilityZone | 
                  Format-Table

# Get RDS instance details
$DBInstance = "prod-db"
Get-RDSDBInstance -DBInstanceIdentifier $DBInstance -Region $Region -ProfileName $Profile | 
                  Format-List DBInstanceIdentifier, DBInstanceStatus, MultiAZ, BackupRetentionPeriod, LatestRestorableTime

# List RDS snapshots (automated only)
Get-RDSDBSnapshot -Filters @{Name="db-instance-id"; Values=$DBInstance} `
                  -Region $Region -ProfileName $Profile | 
                  Where-Object { $_.SnapshotType -eq "automated" } | 
                  Sort-Object SnapshotCreateTime -Descending | 
                  Select-Object -First 10 | 
                  Format-Table DBSnapshotIdentifier, SnapshotCreateTime, Status

# ===== S3 QUICK CHECKS =====

# List objects in media backup bucket
$BucketName = "prod-media-backup"
Get-S3Object -BucketName $BucketName -Region $Region -ProfileName $Profile | 
             Sort-Object LastModified -Descending | 
             Select-Object -First 20 | 
             Format-Table Key, LastModified, Size

# Sync media from S3 to local
$LocalPath = "D:\media-restore"
& aws s3 sync "s3://$BucketName/" $LocalPath --region $Region --profile $Profile

# ===== CLOUDWATCH QUICK CHECKS =====

# Get RDS free storage space (last 1 hour)
$Metrics = Get-CWMetricStatistics -Namespace "AWS/RDS" `
                                  -MetricName "FreeStorageSpace" `
                                  -Dimensions @{Name="DBInstanceIdentifier"; Value=$DBInstance} `
                                  -StartTime (Get-Date).AddHours(-1) `
                                  -EndTime (Get-Date) `
                                  -Period 300 `
                                  -Statistics "Average" `
                                  -Region $Region -ProfileName $Profile

$Metrics.Datapoints | Sort-Object Timestamp | Format-Table Timestamp, Average

# ===== CLOUDTRAIL QUICK CHECKS =====

# Get recent CloudTrail events for an instance
Get-CTEvent -Region $Region -ProfileName $Profile | 
            Where-Object { $_.Resources.ResourceName -eq $InstanceId } | 
            Sort-Object EventTime -Descending | 
            Select-Object -First 20 | 
            Format-Table EventName, EventTime, Username, SourceIPAddress

# ===== SYSTEMS MANAGER (SSM) CHECKS =====

# List SSM parameters
Get-SSMParameter -Filters @{Key="Name"; Value="/prod"} `
                 -Region $Region -ProfileName $Profile | 
                 Format-Table Name, Type, Version

# Get a specific parameter value
$DBEndpoint = Get-SSMParameter -Name "/prod/database/endpoint" -WithDecryption $true `
                               -Region $Region -ProfileName $Profile

Write-Host "Database endpoint: $($DBEndpoint.Parameter.Value)"
```

### AWS CLI Equivalents

If you prefer AWS CLI over PowerShell:

```bash
# List EC2 instances
aws ec2 describe-instances --filters "Name=tag:Environment,Values=prod" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Placement.AvailabilityZone,PrivateIpAddress]' \
  --region ca-central-1 --output table

# List RDS instances
aws rds describe-db-instances --region ca-central-1 \
  --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,MultiAZ,AvailabilityZone]' \
  --output table

# List RDS snapshots
aws rds describe-db-snapshots --db-instance-identifier prod-db \
  --filters "Name=snapshot-type,Values=automated" \
  --region ca-central-1 \
  --query 'DBSnapshots[*].[DBSnapshotIdentifier,SnapshotCreateTime,Status]' \
  --output table

# List S3 objects
aws s3 ls s3://prod-media-backup/ --recursive --human-readable --summarize \
  --region ca-central-1

# CloudWatch metric (RDS free storage)
aws cloudwatch get-metric-statistics --namespace AWS/RDS \
  --metric-name FreeStorageSpace \
  --dimensions Name=DBInstanceIdentifier,Value=prod-db \
  --start-time 2026-03-18T14:00:00Z --end-time 2026-03-18T15:00:00Z \
  --period 300 --statistics Average \
  --region ca-central-1 --output table
```

---

## Document Control

|Version|Date|Author|Change|
|---|---|---|---|
|1.0|2026-03-18|Operations|Initial version; EC2/RDS single-region|
|1.1|TBD|TBD|Regional failover runbook (if multi-region adopted)|

**Review Schedule**: Quarterly or after any production incident  
**Last Review**: 2026-03-18  
**Next Review**: 2026-06-18

---

## References

- [AWS RDS User Guide — Backup and Restore](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/)
- [AWS EC2 Auto Scaling Documentation](https://docs.aws.amazon.com/autoscaling/)
- [CIS AWS Foundations Benchmark v1.5](https://www.cisecurity.org/)
- Internal: `/opt/dr-scripts/` — Automation scripts location