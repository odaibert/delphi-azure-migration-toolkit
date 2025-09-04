# Production Deployment

Final production deployment procedures, go-live checklist, and post-deployment validation for enterprise-grade Delphi ISAPI migration to Azure App Service.

**⏱️ Deployment Time**: 2-4 hours  
**👥 Team Involvement**: DevOps Engineers, Database Administrators, Business Stakeholders  
**📋 Prerequisites**: All testing completed, production environment provisioned, deployment approval obtained

## Production Deployment Overview

This module implements [Azure App Service deployment best practices](https://learn.microsoft.com/azure/app-service/deploy-best-practices) for zero-downtime production deployments with comprehensive rollback procedures.

### Deployment Strategy Options

- **Blue-Green Deployment** with [deployment slots](https://learn.microsoft.com/azure/app-service/deploy-staging-slots)
- **Rolling Deployment** with health checks and automatic rollback
- **Canary Deployment** for gradual traffic migration
- **Maintenance Window Deployment** for high-availability requirements

## 🚀 Pre-Deployment Validation

### Production Readiness Checklist

```powershell
# pre-deployment-validation.ps1 - Final production readiness validation
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$AppServiceName,
    
    [Parameter(Mandatory=$false)]
    [string]$ValidationReportPath = ".\production-readiness-report.html"
)

Write-Host "=== Production Readiness Validation ===" -ForegroundColor Green

# Connect to Azure
try {
    $Context = Get-AzContext
    if (-not $Context -or $Context.Subscription.Id -ne $SubscriptionId) {
        Connect-AzAccount -SubscriptionId $SubscriptionId
    }
    Write-Host "✅ Azure connection verified" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to connect to Azure: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$ValidationResults = @()

function Add-ValidationResult {
    param(
        [string]$Category,
        [string]$Check,
        [string]$Status,
        [string]$Details,
        [string]$Recommendation = ""
    )
    
    $script:ValidationResults += [PSCustomObject]@{
        Category = $Category
        Check = $Check
        Status = $Status
        Details = $Details
        Recommendation = $Recommendation
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    $StatusColor = switch ($Status) {
        "PASSED" { "Green" }
        "WARNING" { "Yellow" }
        "FAILED" { "Red" }
        default { "White" }
    }
    
    Write-Host "  $Check`: $Status" -ForegroundColor $StatusColor
    if ($Details) {
        Write-Host "    $Details" -ForegroundColor Gray
    }
}

Write-Host "Validating production environment..." -ForegroundColor Cyan

# Infrastructure Validation
Write-Host "`n📋 Infrastructure Validation" -ForegroundColor Yellow

try {
    $AppService = Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $AppServiceName -ErrorAction Stop
    Add-ValidationResult -Category "Infrastructure" -Check "App Service Exists" -Status "PASSED" -Details "App Service '$AppServiceName' found in resource group '$ResourceGroupName'"
    
    # Validate App Service Plan
    $AppServicePlan = Get-AzAppServicePlan -ResourceGroupName $ResourceGroupName -Name $AppService.ServerFarmId.Split('/')[-1]
    if ($AppServicePlan.Sku.Tier -in @("Basic", "Free", "Shared")) {
        Add-ValidationResult -Category "Infrastructure" -Check "App Service Plan Tier" -Status "WARNING" -Details "Using $($AppServicePlan.Sku.Tier) tier" -Recommendation "Consider Standard or Premium tier for production"
    } else {
        Add-ValidationResult -Category "Infrastructure" -Check "App Service Plan Tier" -Status "PASSED" -Details "Using production-grade tier: $($AppServicePlan.Sku.Tier)"
    }
    
    # Validate deployment slots
    $DeploymentSlots = Get-AzWebAppSlot -ResourceGroupName $ResourceGroupName -Name $AppServiceName
    if ($DeploymentSlots.Count -eq 0) {
        Add-ValidationResult -Category "Infrastructure" -Check "Deployment Slots" -Status "WARNING" -Details "No deployment slots configured" -Recommendation "Configure staging slot for zero-downtime deployments"
    } else {
        Add-ValidationResult -Category "Infrastructure" -Check "Deployment Slots" -Status "PASSED" -Details "Deployment slots configured: $($DeploymentSlots.Count)"
    }
    
} catch {
    Add-ValidationResult -Category "Infrastructure" -Check "App Service Validation" -Status "FAILED" -Details "Failed to validate App Service: $($_.Exception.Message)"
}

# Configuration Validation
Write-Host "`n⚙️ Configuration Validation" -ForegroundColor Yellow

try {
    $AppSettings = Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $AppServiceName | Select-Object -ExpandProperty SiteConfig | Select-Object -ExpandProperty AppSettings
    
    # Check required configuration
    $RequiredSettings = @("WEBSITE_NODE_DEFAULT_VERSION", "SCM_DO_BUILD_DURING_DEPLOYMENT")
    foreach ($Setting in $RequiredSettings) {
        $Found = $AppSettings | Where-Object { $_.Name -eq $Setting }
        if ($Found) {
            Add-ValidationResult -Category "Configuration" -Check "App Setting: $Setting" -Status "PASSED" -Details "Value: $($Found.Value)"
        } else {
            Add-ValidationResult -Category "Configuration" -Check "App Setting: $Setting" -Status "WARNING" -Details "Setting not found" -Recommendation "Verify if this setting is required for your application"
        }
    }
    
    # Check connection strings
    $ConnectionStrings = Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $AppServiceName | Select-Object -ExpandProperty SiteConfig | Select-Object -ExpandProperty ConnectionStrings
    if ($ConnectionStrings.Count -gt 0) {
        Add-ValidationResult -Category "Configuration" -Check "Database Connection Strings" -Status "PASSED" -Details "$($ConnectionStrings.Count) connection string(s) configured"
    } else {
        Add-ValidationResult -Category "Configuration" -Check "Database Connection Strings" -Status "WARNING" -Details "No connection strings configured" -Recommendation "Verify if database connectivity is required"
    }
    
} catch {
    Add-ValidationResult -Category "Configuration" -Check "Configuration Validation" -Status "FAILED" -Details "Failed to validate configuration: $($_.Exception.Message)"
}

# Security Validation
Write-Host "`n🔒 Security Validation" -ForegroundColor Yellow

try {
    $WebApp = Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $AppServiceName
    
    # HTTPS enforcement
    if ($WebApp.HttpsOnly) {
        Add-ValidationResult -Category "Security" -Check "HTTPS Only" -Status "PASSED" -Details "HTTPS enforcement enabled"
    } else {
        Add-ValidationResult -Category "Security" -Check "HTTPS Only" -Status "FAILED" -Details "HTTPS enforcement disabled" -Recommendation "Enable HTTPS-only access"
    }
    
    # Managed Identity
    if ($WebApp.Identity.Type -ne "None") {
        Add-ValidationResult -Category "Security" -Check "Managed Identity" -Status "PASSED" -Details "Managed Identity enabled: $($WebApp.Identity.Type)"
    } else {
        Add-ValidationResult -Category "Security" -Check "Managed Identity" -Status "WARNING" -Details "Managed Identity not configured" -Recommendation "Enable Managed Identity for secure Azure resource access"
    }
    
    # Client certificates
    if ($WebApp.ClientCertEnabled) {
        Add-ValidationResult -Category "Security" -Check "Client Certificates" -Status "PASSED" -Details "Client certificate authentication enabled"
    } else {
        Add-ValidationResult -Category "Security" -Check "Client Certificates" -Status "WARNING" -Details "Client certificates not required" -Recommendation "Consider enabling for enhanced security"
    }
    
} catch {
    Add-ValidationResult -Category "Security" -Check "Security Validation" -Status "FAILED" -Details "Failed to validate security: $($_.Exception.Message)"
}

# Monitoring Validation
Write-Host "`n📊 Monitoring Validation" -ForegroundColor Yellow

try {
    # Application Insights
    $AppInsights = Get-AzApplicationInsights -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($AppInsights) {
        Add-ValidationResult -Category "Monitoring" -Check "Application Insights" -Status "PASSED" -Details "Application Insights configured: $($AppInsights.Name)"
    } else {
        Add-ValidationResult -Category "Monitoring" -Check "Application Insights" -Status "WARNING" -Details "Application Insights not found" -Recommendation "Configure Application Insights for monitoring"
    }
    
    # Diagnostic settings
    $DiagnosticSettings = Get-AzDiagnosticSetting -ResourceId $WebApp.Id -ErrorAction SilentlyContinue
    if ($DiagnosticSettings) {
        Add-ValidationResult -Category "Monitoring" -Check "Diagnostic Logging" -Status "PASSED" -Details "Diagnostic settings configured"
    } else {
        Add-ValidationResult -Category "Monitoring" -Check "Diagnostic Logging" -Status "WARNING" -Details "Diagnostic settings not configured" -Recommendation "Configure diagnostic logging"
    }
    
} catch {
    Add-ValidationResult -Category "Monitoring" -Check "Monitoring Validation" -Status "FAILED" -Details "Failed to validate monitoring: $($_.Exception.Message)"
}

# Backup Validation
Write-Host "`n💾 Backup Validation" -ForegroundColor Yellow

try {
    $BackupConfiguration = Get-AzWebAppBackupConfiguration -ResourceGroupName $ResourceGroupName -Name $AppServiceName -ErrorAction SilentlyContinue
    if ($BackupConfiguration) {
        Add-ValidationResult -Category "Backup" -Check "Backup Configuration" -Status "PASSED" -Details "Automated backups configured"
    } else {
        Add-ValidationResult -Category "Backup" -Check "Backup Configuration" -Status "WARNING" -Details "Automated backups not configured" -Recommendation "Configure automated backups for data protection"
    }
} catch {
    Add-ValidationResult -Category "Backup" -Check "Backup Validation" -Status "WARNING" -Details "Unable to validate backup configuration"
}

# Generate validation summary
$TotalChecks = $ValidationResults.Count
$PassedChecks = ($ValidationResults | Where-Object { $_.Status -eq "PASSED" }).Count
$WarningChecks = ($ValidationResults | Where-Object { $_.Status -eq "WARNING" }).Count
$FailedChecks = ($ValidationResults | Where-Object { $_.Status -eq "FAILED" }).Count

Write-Host "`n=== Validation Summary ===" -ForegroundColor Yellow
Write-Host "Total Checks: $TotalChecks" -ForegroundColor White
Write-Host "Passed: $PassedChecks" -ForegroundColor Green
Write-Host "Warnings: $WarningChecks" -ForegroundColor Yellow
Write-Host "Failed: $FailedChecks" -ForegroundColor Red

# Production readiness decision
if ($FailedChecks -eq 0) {
    Write-Host "`n🎉 Production readiness: APPROVED" -ForegroundColor Green
    Write-Host "Environment is ready for production deployment" -ForegroundColor Green
    $ReadinessStatus = "APPROVED"
} elseif ($FailedChecks -le 2 -and $WarningChecks -le 5) {
    Write-Host "`n⚠️ Production readiness: CONDITIONAL" -ForegroundColor Yellow
    Write-Host "Address failed checks before deployment" -ForegroundColor Yellow
    $ReadinessStatus = "CONDITIONAL"
} else {
    Write-Host "`n❌ Production readiness: NOT READY" -ForegroundColor Red
    Write-Host "Critical issues must be resolved before deployment" -ForegroundColor Red
    $ReadinessStatus = "NOT_READY"
}

# Export validation report
$ValidationResults | Export-Csv -Path "production-readiness-validation.csv" -NoTypeInformation
Write-Host "`nValidation results exported to: production-readiness-validation.csv" -ForegroundColor Cyan

# Generate HTML report
$HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Production Readiness Validation Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #0078d4; border-bottom: 3px solid #0078d4; padding-bottom: 10px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .metric { padding: 20px; border-radius: 8px; text-align: center; color: white; }
        .metric.approved { background: linear-gradient(135deg, #107c10, #0e6e0e); }
        .metric.conditional { background: linear-gradient(135deg, #ff8c00, #e67300); }
        .metric.not-ready { background: linear-gradient(135deg, #d13438, #b71c1c); }
        .metric.passed { background: linear-gradient(135deg, #107c10, #0e6e0e); }
        .metric.warning { background: linear-gradient(135deg, #ff8c00, #e67300); }
        .metric.failed { background: linear-gradient(135deg, #d13438, #b71c1c); }
        .metric-value { font-size: 2em; font-weight: bold; }
        .metric-label { font-size: 0.9em; margin-top: 5px; }
        .category { margin: 30px 0; }
        .category h3 { color: #0078d4; border-bottom: 1px solid #e1e1e1; padding-bottom: 5px; }
        .check { background: #f9f9f9; margin: 10px 0; padding: 15px; border-radius: 5px; border-left: 4px solid #ccc; }
        .check.passed { border-left-color: #107c10; }
        .check.warning { border-left-color: #ff8c00; }
        .check.failed { border-left-color: #d13438; }
        .check-header { font-weight: bold; margin-bottom: 5px; }
        .check-details { color: #666; margin: 5px 0; }
        .check-recommendation { color: #0078d4; font-style: italic; margin-top: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Production Readiness Validation Report</h1>
        <p><strong>Validation Date:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')</p>
        <p><strong>App Service:</strong> $AppServiceName</p>
        <p><strong>Resource Group:</strong> $ResourceGroupName</p>
        
        <div class="summary">
            <div class="metric $(if($ReadinessStatus -eq 'APPROVED'){'approved'}elseif($ReadinessStatus -eq 'CONDITIONAL'){'conditional'}else{'not-ready'})">
                <div class="metric-value">$ReadinessStatus</div>
                <div class="metric-label">Production Readiness</div>
            </div>
            <div class="metric passed">
                <div class="metric-value">$PassedChecks</div>
                <div class="metric-label">Passed</div>
            </div>
            <div class="metric warning">
                <div class="metric-value">$WarningChecks</div>
                <div class="metric-label">Warnings</div>
            </div>
            <div class="metric failed">
                <div class="metric-value">$FailedChecks</div>
                <div class="metric-label">Failed</div>
            </div>
        </div>
"@

# Group results by category
$Categories = $ValidationResults | Group-Object -Property Category

foreach ($Category in $Categories) {
    $HtmlReport += @"
        <div class="category">
            <h3>$($Category.Name)</h3>
"@
    
    foreach ($Check in $Category.Group) {
        $CheckClass = $Check.Status.ToLower()
        $HtmlReport += @"
            <div class="check $CheckClass">
                <div class="check-header">$($Check.Check)</div>
                <div class="check-details">$($Check.Details)</div>
"@
        
        if ($Check.Recommendation) {
            $HtmlReport += @"
                <div class="check-recommendation">💡 Recommendation: $($Check.Recommendation)</div>
"@
        }
        
        $HtmlReport += @"
            </div>
"@
    }
    
    $HtmlReport += @"
        </div>
"@
}

$HtmlReport += @"
    </div>
</body>
</html>
"@

$HtmlReport | Out-File -FilePath $ValidationReportPath -Encoding UTF8
Write-Host "HTML report generated: $ValidationReportPath" -ForegroundColor Green

return $ReadinessStatus
```

## 🔄 Blue-Green Deployment Implementation

### Zero-Downtime Deployment Script

```powershell
# blue-green-deployment.ps1 - Zero-downtime production deployment
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$AppServiceName,
    
    [Parameter(Mandatory=$true)]
    [string]$PackagePath,
    
    [Parameter(Mandatory=$false)]
    [string]$StagingSlotName = "staging",
    
    [Parameter(Mandatory=$false)]
    [int]$HealthCheckTimeoutMinutes = 10,
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoSwap = $false
)

Write-Host "=== Blue-Green Deployment Process ===" -ForegroundColor Green

$DeploymentStart = Get-Date

function Write-DeploymentLog {
    param([string]$Message, [string]$Level = "INFO")
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Color = switch ($Level) {
        "INFO" { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }
    
    Write-Host "[$Timestamp] $Message" -ForegroundColor $Color
}

function Test-AppHealth {
    param(
        [string]$Url,
        [int]$TimeoutMinutes = 5
    )
    
    $EndTime = (Get-Date).AddMinutes($TimeoutMinutes)
    $HealthCheck = $false
    
    Write-DeploymentLog "Testing application health at: $Url"
    
    while ((Get-Date) -lt $EndTime -and -not $HealthCheck) {
        try {
            $Response = Invoke-WebRequest -Uri "$Url/health" -UseBasicParsing -TimeoutSec 30
            if ($Response.StatusCode -eq 200) {
                $HealthCheck = $true
                Write-DeploymentLog "Health check passed" "SUCCESS"
            }
        } catch {
            Write-DeploymentLog "Health check attempt failed, retrying..." "WARNING"
            Start-Sleep -Seconds 30
        }
    }
    
    return $HealthCheck
}

# Step 1: Validate prerequisites
Write-DeploymentLog "Validating deployment prerequisites..."

if (-not (Test-Path $PackagePath)) {
    Write-DeploymentLog "Package not found: $PackagePath" "ERROR"
    exit 1
}

try {
    $AppService = Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $AppServiceName -ErrorAction Stop
    Write-DeploymentLog "App Service validated: $AppServiceName" "SUCCESS"
} catch {
    Write-DeploymentLog "Failed to find App Service: $($_.Exception.Message)" "ERROR"
    exit 1
}

# Step 2: Create or validate staging slot
Write-DeploymentLog "Preparing staging slot..."

try {
    $StagingSlot = Get-AzWebAppSlot -ResourceGroupName $ResourceGroupName -Name $AppServiceName -SlotName $StagingSlotName -ErrorAction SilentlyContinue
    if (-not $StagingSlot) {
        Write-DeploymentLog "Creating staging slot: $StagingSlotName"
        $StagingSlot = New-AzWebAppSlot -ResourceGroupName $ResourceGroupName -Name $AppServiceName -SlotName $StagingSlotName
        
        # Copy production configuration to staging
        Write-DeploymentLog "Copying production configuration to staging slot"
        $ProductionConfig = Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $AppServiceName
        
        # Set staging slot configuration
        Set-AzWebAppSlot -ResourceGroupName $ResourceGroupName -Name $AppServiceName -SlotName $StagingSlotName -AppSettings $ProductionConfig.SiteConfig.AppSettings -ConnectionStrings $ProductionConfig.SiteConfig.ConnectionStrings
    }
    
    Write-DeploymentLog "Staging slot ready: $StagingSlotName" "SUCCESS"
} catch {
    Write-DeploymentLog "Failed to prepare staging slot: $($_.Exception.Message)" "ERROR"
    exit 1
}

# Step 3: Deploy to staging slot
Write-DeploymentLog "Deploying application to staging slot..."

try {
    $DeployResult = Publish-AzWebAppSlot -ResourceGroupName $ResourceGroupName -Name $AppServiceName -SlotName $StagingSlotName -ArchivePath $PackagePath -Force
    Write-DeploymentLog "Deployment to staging completed" "SUCCESS"
} catch {
    Write-DeploymentLog "Deployment to staging failed: $($_.Exception.Message)" "ERROR"
    exit 1
}

# Step 4: Health check on staging
Write-DeploymentLog "Performing health checks on staging environment..."

$StagingUrl = "https://$AppServiceName-$StagingSlotName.azurewebsites.net"
$StagingHealthy = Test-AppHealth -Url $StagingUrl -TimeoutMinutes $HealthCheckTimeoutMinutes

if (-not $StagingHealthy) {
    Write-DeploymentLog "Staging health check failed. Deployment aborted." "ERROR"
    exit 1
}

# Step 5: Production backup (configuration snapshot)
Write-DeploymentLog "Creating production configuration backup..."

try {
    $ProductionSnapshot = @{
        AppSettings = (Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $AppServiceName).SiteConfig.AppSettings
        ConnectionStrings = (Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $AppServiceName).SiteConfig.ConnectionStrings
        Timestamp = Get-Date
    }
    
    $BackupFile = "production-snapshot-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $ProductionSnapshot | ConvertTo-Json -Depth 10 | Out-File -FilePath $BackupFile -Encoding UTF8
    Write-DeploymentLog "Production snapshot saved: $BackupFile" "SUCCESS"
} catch {
    Write-DeploymentLog "Warning: Failed to create production snapshot" "WARNING"
}

# Step 6: Slot swap decision
if ($AutoSwap) {
    $SwapDecision = "Y"
} else {
    Write-DeploymentLog "Staging deployment successful and healthy."
    Write-DeploymentLog "Staging URL: $StagingUrl"
    Write-Host "`nReady to swap staging to production. Continue? (Y/N): " -NoNewline -ForegroundColor Yellow
    $SwapDecision = Read-Host
}

if ($SwapDecision -eq "Y" -or $SwapDecision -eq "y") {
    # Step 7: Perform slot swap
    Write-DeploymentLog "Initiating slot swap to production..."
    
    try {
        $SwapOperation = Switch-AzWebAppSlot -ResourceGroupName $ResourceGroupName -Name $AppServiceName -SourceSlotName $StagingSlotName -DestinationSlotName "production"
        Write-DeploymentLog "Slot swap completed" "SUCCESS"
        
        # Step 8: Post-swap health check
        Write-DeploymentLog "Performing post-swap health checks..."
        
        $ProductionUrl = "https://$AppServiceName.azurewebsites.net"
        $ProductionHealthy = Test-AppHealth -Url $ProductionUrl -TimeoutMinutes $HealthCheckTimeoutMinutes
        
        if ($ProductionHealthy) {
            Write-DeploymentLog "Production health check passed - Deployment successful!" "SUCCESS"
            
            # Step 9: Cleanup staging slot (optional)
            Write-Host "`nClean up staging slot? (Y/N): " -NoNewline -ForegroundColor Yellow
            $CleanupDecision = Read-Host
            
            if ($CleanupDecision -eq "Y" -or $CleanupDecision -eq "y") {
                Write-DeploymentLog "Cleaning up staging slot..."
                try {
                    Remove-AzWebAppSlot -ResourceGroupName $ResourceGroupName -Name $AppServiceName -SlotName $StagingSlotName -Force
                    Write-DeploymentLog "Staging slot cleaned up" "SUCCESS"
                } catch {
                    Write-DeploymentLog "Warning: Failed to clean up staging slot" "WARNING"
                }
            }
            
        } else {
            Write-DeploymentLog "Production health check failed - Initiating rollback!" "ERROR"
            
            # Emergency rollback
            try {
                Write-DeploymentLog "Performing emergency rollback..."
                Switch-AzWebAppSlot -ResourceGroupName $ResourceGroupName -Name $AppServiceName -SourceSlotName "production" -DestinationSlotName $StagingSlotName
                Write-DeploymentLog "Rollback completed" "SUCCESS"
            } catch {
                Write-DeploymentLog "Rollback failed: $($_.Exception.Message)" "ERROR"
            }
        }
        
    } catch {
        Write-DeploymentLog "Slot swap failed: $($_.Exception.Message)" "ERROR"
        exit 1
    }
    
} else {
    Write-DeploymentLog "Deployment completed but not swapped to production."
    Write-DeploymentLog "Staging environment available at: $StagingUrl"
    Write-DeploymentLog "Use 'Switch-AzWebAppSlot' to manually promote when ready."
}

$DeploymentDuration = (Get-Date) - $DeploymentStart
Write-DeploymentLog "Total deployment time: $([math]::Round($DeploymentDuration.TotalMinutes, 2)) minutes" "SUCCESS"
```

## 📊 Post-Deployment Monitoring

### Production Health Monitoring Script

```powershell
# post-deployment-monitoring.ps1 - Continuous production health monitoring
param(
    [Parameter(Mandatory=$true)]
    [string]$AppServiceUrl,
    
    [Parameter(Mandatory=$false)]
    [int]$MonitoringDurationMinutes = 60,
    
    [Parameter(Mandatory=$false)]
    [int]$CheckIntervalSeconds = 30,
    
    [Parameter(Mandatory=$false)]
    [string]$AlertEmailAddress = ""
)

Write-Host "=== Post-Deployment Monitoring ===" -ForegroundColor Green
Write-Host "Monitoring URL: $AppServiceUrl" -ForegroundColor Cyan
Write-Host "Duration: $MonitoringDurationMinutes minutes" -ForegroundColor Cyan
Write-Host "Check Interval: $CheckIntervalSeconds seconds" -ForegroundColor Cyan

$MonitoringStart = Get-Date
$EndTime = $MonitoringStart.AddMinutes($MonitoringDurationMinutes)
$MonitoringResults = @()
$ConsecutiveFailures = 0
$AlertThreshold = 3

function Send-Alert {
    param([string]$Subject, [string]$Body)
    
    if ($AlertEmailAddress) {
        try {
            # In a real implementation, you would configure SMTP settings or use Azure Logic Apps
            Write-Host "🚨 ALERT: $Subject" -ForegroundColor Red
            Write-Host "   $Body" -ForegroundColor Red
        } catch {
            Write-Host "Failed to send alert: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Test-ApplicationEndpoint {
    param([string]$Url, [string]$EndpointName)
    
    $TestStart = Get-Date
    try {
        $Response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 30
        $ResponseTime = (Get-Date) - $TestStart
        
        $Result = [PSCustomObject]@{
            Timestamp = Get-Date
            Endpoint = $EndpointName
            StatusCode = $Response.StatusCode
            ResponseTime = $ResponseTime.TotalMilliseconds
            Success = $true
            Error = ""
        }
        
        Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] $EndpointName`: ✅ $($Response.StatusCode) ($([math]::Round($ResponseTime.TotalMilliseconds, 0))ms)" -ForegroundColor Green
        
    } catch {
        $ResponseTime = (Get-Date) - $TestStart
        
        $Result = [PSCustomObject]@{
            Timestamp = Get-Date
            Endpoint = $EndpointName
            StatusCode = 0
            ResponseTime = $ResponseTime.TotalMilliseconds
            Success = $false
            Error = $_.Exception.Message
        }
        
        Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] $EndpointName`: ❌ FAILED - $($_.Exception.Message)" -ForegroundColor Red
        
        $script:ConsecutiveFailures++
        
        if ($script:ConsecutiveFailures -ge $AlertThreshold) {
            Send-Alert -Subject "Production Application Alert" -Body "Application endpoint '$EndpointName' has failed $script:ConsecutiveFailures consecutive health checks"
        }
    }
    
    return $Result
}

# Main monitoring loop
Write-Host "`nStarting continuous monitoring..." -ForegroundColor Yellow

while ((Get-Date) -lt $EndTime) {
    $CycleStart = Get-Date
    
    # Test multiple endpoints
    $Results = @()
    $Results += Test-ApplicationEndpoint -Url "$AppServiceUrl/health" -EndpointName "Health Check"
    $Results += Test-ApplicationEndpoint -Url "$AppServiceUrl/" -EndpointName "Home Page"
    $Results += Test-ApplicationEndpoint -Url "$AppServiceUrl/api/status" -EndpointName "API Status"
    
    # Check if all tests passed
    $AllPassed = ($Results | Where-Object { -not $_.Success }).Count -eq 0
    if ($AllPassed) {
        $ConsecutiveFailures = 0
    }
    
    $MonitoringResults += $Results
    
    # Calculate cycle timing
    $CycleTime = (Get-Date) - $CycleStart
    $SleepTime = [math]::Max(0, $CheckIntervalSeconds - $CycleTime.TotalSeconds)
    
    if ($SleepTime -gt 0) {
        Start-Sleep -Seconds $SleepTime
    }
}

# Generate monitoring summary
$TotalChecks = $MonitoringResults.Count
$SuccessfulChecks = ($MonitoringResults | Where-Object { $_.Success }).Count
$FailedChecks = $TotalChecks - $SuccessfulChecks
$SuccessRate = if ($TotalChecks -gt 0) { [math]::Round(($SuccessfulChecks / $TotalChecks) * 100, 2) } else { 0 }

$SuccessfulResults = $MonitoringResults | Where-Object { $_.Success }
$AvgResponseTime = if ($SuccessfulResults) { [math]::Round(($SuccessfulResults | Measure-Object ResponseTime -Average).Average, 2) } else { 0 }

Write-Host "`n=== Monitoring Summary ===" -ForegroundColor Yellow
Write-Host "Monitoring Duration: $([math]::Round(((Get-Date) - $MonitoringStart).TotalMinutes, 2)) minutes" -ForegroundColor White
Write-Host "Total Checks: $TotalChecks" -ForegroundColor White
Write-Host "Successful: $SuccessfulChecks" -ForegroundColor Green
Write-Host "Failed: $FailedChecks" -ForegroundColor Red
Write-Host "Success Rate: $SuccessRate%" -ForegroundColor White
Write-Host "Average Response Time: ${AvgResponseTime}ms" -ForegroundColor White

# Export monitoring results
$MonitoringResults | Export-Csv -Path "post-deployment-monitoring-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv" -NoTypeInformation
Write-Host "`nMonitoring results exported to CSV" -ForegroundColor Cyan

# Final assessment
if ($SuccessRate -ge 99) {
    Write-Host "`n🎉 Production deployment monitoring: EXCELLENT" -ForegroundColor Green
    Write-Host "Application is performing optimally" -ForegroundColor Green
} elseif ($SuccessRate -ge 95) {
    Write-Host "`n✅ Production deployment monitoring: GOOD" -ForegroundColor Green
    Write-Host "Application is performing well with minor issues" -ForegroundColor Green
} else {
    Write-Host "`n⚠️ Production deployment monitoring: ATTENTION REQUIRED" -ForegroundColor Yellow
    Write-Host "Application has significant performance or availability issues" -ForegroundColor Yellow
    
    if ($AlertEmailAddress) {
        Send-Alert -Subject "Production Deployment Monitoring Alert" -Body "Application success rate is $SuccessRate% - immediate attention required"
    }
}
```

## 🎯 Go-Live Checklist

### Final Production Deployment Checklist

- [ ] **Pre-deployment Validation** - All readiness checks passed
- [ ] **Stakeholder Approval** - Business stakeholders approve go-live
- [ ] **Deployment Window** - Maintenance window scheduled and communicated
- [ ] **Rollback Plan** - Emergency rollback procedures tested and ready
- [ ] **Team Availability** - Technical team available during deployment
- [ ] **Communication Plan** - User communication and status page updates prepared
- [ ] **Database Backup** - Recent database backup verified and tested
- [ ] **Configuration Backup** - Current production configuration saved
- [ ] **Monitoring Alerts** - Production monitoring and alerting configured
- [ ] **Performance Baseline** - Current performance metrics documented
- [ ] **DNS/Traffic Management** - Traffic routing and DNS changes ready
- [ ] **SSL Certificate** - Production SSL certificate installed and validated
- [ ] **Security Scan** - Final security validation completed
- [ ] **Compliance Check** - Regulatory compliance requirements verified
- [ ] **Documentation Updated** - Operational procedures and runbooks current

## 📚 Reference Documentation

- [Azure App Service deployment best practices](https://learn.microsoft.com/azure/app-service/deploy-best-practices)
- [App Service deployment slots](https://learn.microsoft.com/azure/app-service/deploy-staging-slots)
- [Zero-downtime deployment patterns](https://learn.microsoft.com/azure/architecture/patterns/deployment-stamp)
- [Production deployment checklist](https://learn.microsoft.com/azure/app-service/deploy-continuous-deployment)

---

## 🏁 Migration Complete!

**Congratulations!** Your Delphi ISAPI application has been successfully migrated to Azure App Service with enterprise-grade deployment procedures.

### 🎯 What You've Accomplished

- ✅ **Enterprise-Ready Migration** - Professional Azure App Service deployment
- ✅ **Zero-Downtime Deployment** - Blue-green deployment with automatic rollback
- ✅ **Comprehensive Testing** - Functional, performance, and security validation
- ✅ **Production Monitoring** - Continuous health monitoring and alerting
- ✅ **Operational Excellence** - Documentation, procedures, and support framework

### 📋 Post-Migration Activities

1. **Monitor Performance** - Track application metrics and user experience
2. **Optimize Costs** - Review Azure spending and optimize resource allocation
3. **Plan Enhancements** - Identify modernization opportunities and feature improvements
4. **Team Training** - Ensure operational team is trained on Azure management
5. **Documentation Review** - Keep operational procedures current and accessible

### Navigation
- **← Previous**: [Testing and Validation](06-testing-validation.md)
- **🏠 Home**: [Migration Overview](../../../README.md)
- **🔧 Support**: [Troubleshooting Guide](../../../docs/troubleshooting.md)
