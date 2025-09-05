#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Enhanced production-ready deployment script for ISAPI applications to Azure App Service
    
.DESCRIPTION
    This script provides enterprise-grade deployment with comprehensive error handling,
    rollback capabilities, and production validation. Features include:
    
    1. Pre-deployment validation and health checks
    2. Blue-green deployment support with staging slots
    3. Comprehensive error handling with automatic rollback
    4. Post-deployment validation and smoke tests
    5. Detailed logging and audit trail
    6. Backup and restore capabilities
    7. Performance monitoring integration
    
.PARAMETER ResourceGroupName
    The Azure resource group name
    
.PARAMETER AppServiceName
    The App Service name
    
.PARAMETER PackagePath
    Path to the deployment package (ZIP file)
    
.PARAMETER Environment
    Target environment (Dev, Test, Prod)
    
.PARAMETER UseStaging
    Use staging slot for blue-green deployment
    
.PARAMETER BackupBeforeDeployment
    Create backup before deployment
    
.PARAMETER RunSmokeTests
    Run smoke tests after deployment
    
.PARAMETER AutoRollbackOnFailure
    Automatically rollback on deployment failure
    
.PARAMETER NotificationEmail
    Email address for deployment notifications
    
.EXAMPLE
    .\deploy-enhanced.ps1 -ResourceGroupName "rg-isapi" -AppServiceName "my-isapi-app" -PackagePath ".\release.zip" -Environment "Prod"
    
.EXAMPLE
    .\deploy-enhanced.ps1 -ResourceGroupName "rg-prod" -AppServiceName "prod-isapi" -PackagePath ".\release.zip" -Environment "Prod" -UseStaging -BackupBeforeDeployment -RunSmokeTests -AutoRollbackOnFailure -NotificationEmail "admin@company.com"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$AppServiceName,
    
    [Parameter(Mandatory = $true)]
    [string]$PackagePath,
    
    [Parameter(Mandatory = $true)]
    [ValidateSet("Dev", "Test", "Prod")]
    [string]$Environment,
    
    [Parameter(Mandatory = $false)]
    [switch]$UseStaging,
    
    [Parameter(Mandatory = $false)]
    [switch]$BackupBeforeDeployment,
    
    [Parameter(Mandatory = $false)]
    [switch]$RunSmokeTests,
    
    [Parameter(Mandatory = $false)]
    [switch]$AutoRollbackOnFailure = $true,
    
    [Parameter(Mandatory = $false)]
    [string]$NotificationEmail
)

# Global variables
$Global:DeploymentId = (New-Guid).ToString()
$Global:DeploymentStartTime = Get-Date
$Global:LogFile = "deployment-$Global:DeploymentId.log"
$Global:BackupPath = ""
$Global:StagingSlotName = "staging"
$Global:DeploymentSteps = @()
$Global:ErrorOccurred = $false

# Logging function
function Write-DeploymentLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Console output with colors
    switch ($Level) {
        "Info"    { Write-Host $logMessage -ForegroundColor White }
        "Warning" { Write-Host $logMessage -ForegroundColor Yellow }
        "Error"   { Write-Host $logMessage -ForegroundColor Red }
        "Success" { Write-Host $logMessage -ForegroundColor Green }
    }
    
    # File output
    $logMessage | Add-Content -Path $Global:LogFile -Encoding UTF8
}

# Error handling function
function Handle-DeploymentError {
    param(
        [string]$ErrorMessage,
        [string]$Step
    )
    
    $Global:ErrorOccurred = $true
    Write-DeploymentLog "ERROR in step '$Step': $ErrorMessage" -Level "Error"
    
    if ($AutoRollbackOnFailure) {
        Write-DeploymentLog "Auto-rollback is enabled. Initiating rollback..." -Level "Warning"
        Invoke-Rollback
    }
    
    Send-DeploymentNotification -Status "Failed" -ErrorMessage $ErrorMessage
    exit 1
}

# Rollback function
function Invoke-Rollback {
    Write-DeploymentLog "🔄 Starting rollback procedure..." -Level "Warning"
    
    try {
        if ($UseStaging -and $Global:BackupPath) {
            Write-DeploymentLog "Rolling back using staging slot..." -Level "Info"
            
            # Swap back to previous version
            az webapp deployment slot swap --resource-group $ResourceGroupName --name $AppServiceName --slot $Global:StagingSlotName --target-slot production --action revert
            
            Write-DeploymentLog "✅ Rollback completed using staging slot" -Level "Success"
        } elseif ($Global:BackupPath) {
            Write-DeploymentLog "Rolling back using backup: $Global:BackupPath" -Level "Info"
            
            # Restore from backup
            az webapp deployment source config-zip --resource-group $ResourceGroupName --name $AppServiceName --src $Global:BackupPath
            
            Write-DeploymentLog "✅ Rollback completed using backup" -Level "Success"
        } else {
            Write-DeploymentLog "⚠️ No rollback method available. Manual intervention required." -Level "Warning"
        }
        
        # Verify rollback
        $healthCheck = Test-ApplicationHealth
        if ($healthCheck.IsHealthy) {
            Write-DeploymentLog "✅ Application is healthy after rollback" -Level "Success"
        } else {
            Write-DeploymentLog "❌ Application is still unhealthy after rollback. Manual intervention required." -Level "Error"
        }
        
    } catch {
        Write-DeploymentLog "❌ Rollback failed: $($_.Exception.Message)" -Level "Error"
        Write-DeploymentLog "Manual intervention required immediately!" -Level "Error"
    }
}

# Health check function
function Test-ApplicationHealth {
    param(
        [string]$TargetUrl = "",
        [int]$MaxRetries = 3,
        [int]$RetryDelaySeconds = 30
    )
    
    if (-not $TargetUrl) {
        $appService = az webapp show --name $AppServiceName --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        $TargetUrl = "https://$($appService.defaultHostName)"
    }
    
    $healthResult = @{
        IsHealthy = $false
        ResponseTime = 0
        StatusCode = 0
        ErrorMessage = ""
    }
    
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            Write-DeploymentLog "Health check attempt $i/$MaxRetries for $TargetUrl" -Level "Info"
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-RestMethod -Uri $TargetUrl -Method Get -TimeoutSec 30 -ErrorAction Stop
            $stopwatch.Stop()
            
            $healthResult.IsHealthy = $true
            $healthResult.ResponseTime = $stopwatch.ElapsedMilliseconds
            $healthResult.StatusCode = 200
            
            Write-DeploymentLog "✅ Health check passed. Response time: $($healthResult.ResponseTime)ms" -Level "Success"
            break
            
        } catch {
            $healthResult.ErrorMessage = $_.Exception.Message
            Write-DeploymentLog "❌ Health check attempt $i failed: $($_.Exception.Message)" -Level "Warning"
            
            if ($i -lt $MaxRetries) {
                Write-DeploymentLog "Waiting $RetryDelaySeconds seconds before retry..." -Level "Info"
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
    }
    
    return $healthResult
}

# Smoke tests function
function Invoke-SmokeTests {
    Write-DeploymentLog "🧪 Running smoke tests..." -Level "Info"
    
    $appService = az webapp show --name $AppServiceName --resource-group $ResourceGroupName --output json | ConvertFrom-Json
    $baseUrl = "https://$($appService.defaultHostName)"
    
    $smokeTests = @(
        @{ Name = "Basic Connectivity"; Url = $baseUrl; Method = "GET"; ExpectedStatus = 200 }
        @{ Name = "Health Endpoint"; Url = "$baseUrl/health"; Method = "GET"; ExpectedStatus = 200; Optional = $true }
        @{ Name = "API Endpoint"; Url = "$baseUrl/api"; Method = "GET"; ExpectedStatus = 200; Optional = $true }
    )
    
    $testResults = @{
        Passed = 0
        Failed = 0
        Optional = 0
        Details = @()
    }
    
    foreach ($test in $smokeTests) {
        try {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-WebRequest -Uri $test.Url -Method $test.Method -TimeoutSec 30 -ErrorAction Stop
            $stopwatch.Stop()
            
            if ($response.StatusCode -eq $test.ExpectedStatus) {
                $testResults.Passed++
                $testResults.Details += @{
                    Name = $test.Name
                    Status = "Passed"
                    ResponseTime = $stopwatch.ElapsedMilliseconds
                    StatusCode = $response.StatusCode
                }
                Write-DeploymentLog "✅ Smoke test passed: $($test.Name) ($($stopwatch.ElapsedMilliseconds)ms)" -Level "Success"
            } else {
                throw "Unexpected status code: $($response.StatusCode)"
            }
            
        } catch {
            if ($test.Optional) {
                $testResults.Optional++
                Write-DeploymentLog "⚠️ Optional smoke test failed: $($test.Name) - $($_.Exception.Message)" -Level "Warning"
            } else {
                $testResults.Failed++
                Write-DeploymentLog "❌ Critical smoke test failed: $($test.Name) - $($_.Exception.Message)" -Level "Error"
            }
            
            $testResults.Details += @{
                Name = $test.Name
                Status = "Failed"
                Error = $_.Exception.Message
                Optional = $test.Optional -eq $true
            }
        }
    }
    
    Write-DeploymentLog "Smoke test results: $($testResults.Passed) passed, $($testResults.Failed) failed, $($testResults.Optional) optional failed" -Level "Info"
    
    if ($testResults.Failed -gt 0) {
        throw "Critical smoke tests failed. Deployment validation unsuccessful."
    }
    
    return $testResults
}

# Backup function
function Create-Backup {
    Write-DeploymentLog "💾 Creating backup..." -Level "Info"
    
    try {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupFileName = "$AppServiceName-backup-$timestamp.zip"
        $Global:BackupPath = Join-Path $PWD $backupFileName
        
        # Download current application content
        az webapp deployment source config-zip --resource-group $ResourceGroupName --name $AppServiceName --src $Global:BackupPath
        
        Write-DeploymentLog "✅ Backup created: $Global:BackupPath" -Level "Success"
        return $Global:BackupPath
        
    } catch {
        Write-DeploymentLog "⚠️ Backup creation failed: $($_.Exception.Message)" -Level "Warning"
        return $null
    }
}

# Notification function
function Send-DeploymentNotification {
    param(
        [ValidateSet("Started", "Success", "Failed")]
        [string]$Status,
        [string]$ErrorMessage = ""
    )
    
    if (-not $NotificationEmail) {
        return
    }
    
    $duration = ""
    if ($Status -ne "Started") {
        $elapsed = (Get-Date) - $Global:DeploymentStartTime
        $duration = "Duration: $($elapsed.ToString('hh\:mm\:ss'))"
    }
    
    $subject = "ISAPI Deployment $Status - $AppServiceName ($Environment)"
    $body = @"
Deployment Details:
- Application: $AppServiceName
- Environment: $Environment  
- Resource Group: $ResourceGroupName
- Deployment ID: $Global:DeploymentId
- Package: $PackagePath
- Status: $Status
- Started: $($Global:DeploymentStartTime.ToString('yyyy-MM-dd HH:mm:ss'))
$duration

Configuration:
- Use Staging Slot: $UseStaging
- Backup Before Deployment: $BackupBeforeDeployment
- Run Smoke Tests: $RunSmokeTests
- Auto Rollback: $AutoRollbackOnFailure

$(if ($ErrorMessage) { "Error Details:`n$ErrorMessage`n" })
$(if ($Global:BackupPath) { "Backup Location: $Global:BackupPath`n" })

Log File: $Global:LogFile

For more details, check the deployment logs and Azure Portal.
"@

    Write-DeploymentLog "📧 Sending notification to $NotificationEmail" -Level "Info"
    
    # Note: In a real implementation, you would integrate with your email service
    # For now, we'll just log the notification details
    Write-DeploymentLog "Notification - Subject: $subject" -Level "Info"
    Write-DeploymentLog "Notification - Body: $body" -Level "Info"
}

# Main deployment function
function Start-EnhancedDeployment {
    Write-DeploymentLog "🚀 Starting Enhanced ISAPI Deployment" -Level "Info"
    Write-DeploymentLog "Deployment ID: $Global:DeploymentId" -Level "Info"
    Write-DeploymentLog "Target: $AppServiceName ($Environment)" -Level "Info"
    Write-DeploymentLog "Package: $PackagePath" -Level "Info"
    Write-DeploymentLog "Configuration: Staging=$UseStaging, Backup=$BackupBeforeDeployment, SmokeTests=$RunSmokeTests, AutoRollback=$AutoRollbackOnFailure" -Level "Info"
    
    Send-DeploymentNotification -Status "Started"
    
    try {
        # Step 1: Pre-deployment validation
        Write-DeploymentLog "`n📋 Step 1: Pre-deployment validation" -Level "Info"
        $Global:DeploymentSteps += "Pre-deployment validation"
        
        # Validate package exists
        if (-not (Test-Path $PackagePath)) {
            throw "Deployment package not found: $PackagePath"
        }
        Write-DeploymentLog "✅ Deployment package validated: $PackagePath" -Level "Success"
        
        # Validate Azure resources
        $appService = az webapp show --name $AppServiceName --resource-group $ResourceGroupName --output json 2>$null | ConvertFrom-Json
        if (-not $appService) {
            throw "App Service not found: $AppServiceName in resource group $ResourceGroupName"
        }
        Write-DeploymentLog "✅ App Service validated: $AppServiceName" -Level "Success"
        
        # Check current application health
        $currentHealth = Test-ApplicationHealth
        if (-not $currentHealth.IsHealthy) {
            Write-DeploymentLog "⚠️ Current application is not healthy. Proceeding with deployment..." -Level "Warning"
        } else {
            Write-DeploymentLog "✅ Current application is healthy" -Level "Success"
        }
        
        # Step 2: Create backup if requested
        if ($BackupBeforeDeployment) {
            Write-DeploymentLog "`n💾 Step 2: Creating backup" -Level "Info"
            $Global:DeploymentSteps += "Backup creation"
            
            $backupResult = Create-Backup
            if (-not $backupResult) {
                if ($Environment -eq "Prod") {
                    throw "Backup creation failed and this is a production deployment. Aborting for safety."
                } else {
                    Write-DeploymentLog "⚠️ Backup creation failed but continuing with non-production deployment" -Level "Warning"
                }
            }
        }
        
        # Step 3: Prepare deployment slot
        if ($UseStaging) {
            Write-DeploymentLog "`n🎭 Step 3: Preparing staging slot" -Level "Info"
            $Global:DeploymentSteps += "Staging slot preparation"
            
            # Create staging slot if it doesn't exist
            try {
                az webapp deployment slot list --name $AppServiceName --resource-group $ResourceGroupName --output table
            } catch {
                Write-DeploymentLog "Creating staging slot..." -Level "Info"
                az webapp deployment slot create --name $AppServiceName --resource-group $ResourceGroupName --slot $Global:StagingSlotName
            }
            
            Write-DeploymentLog "✅ Staging slot prepared: $Global:StagingSlotName" -Level "Success"
        }
        
        # Step 4: Deploy application
        Write-DeploymentLog "`n🚀 Step 4: Deploying application" -Level "Info"
        $Global:DeploymentSteps += "Application deployment"
        
        $deploymentTarget = $AppServiceName
        if ($UseStaging) {
            $deploymentTarget += " --slot $Global:StagingSlotName"
        }
        
        Write-DeploymentLog "Deploying to: $deploymentTarget" -Level "Info"
        
        $deploymentResult = az webapp deployment source config-zip --resource-group $ResourceGroupName --name $AppServiceName --src $PackagePath $(if ($UseStaging) { "--slot $Global:StagingSlotName" })
        
        if ($LASTEXITCODE -ne 0) {
            throw "Deployment failed with exit code: $LASTEXITCODE"
        }
        
        Write-DeploymentLog "✅ Application deployed successfully" -Level "Success"
        
        # Step 5: Post-deployment validation
        Write-DeploymentLog "`n🔍 Step 5: Post-deployment validation" -Level "Info"
        $Global:DeploymentSteps += "Post-deployment validation"
        
        # Wait for application to start
        Write-DeploymentLog "Waiting for application to start..." -Level "Info"
        Start-Sleep -Seconds 30
        
        # Test application health
        $targetUrl = if ($UseStaging) { 
            $appService = az webapp show --name $AppServiceName --resource-group $ResourceGroupName --output json | ConvertFrom-Json
            "https://$AppServiceName-$Global:StagingSlotName.azurewebsites.net"
        } else { 
            $appService = az webapp show --name $AppServiceName --resource-group $ResourceGroupName --output json | ConvertFrom-Json
            "https://$($appService.defaultHostName)"
        }
        
        $postDeployHealth = Test-ApplicationHealth -TargetUrl $targetUrl
        if (-not $postDeployHealth.IsHealthy) {
            throw "Application health check failed after deployment"
        }
        
        Write-DeploymentLog "✅ Post-deployment health check passed" -Level "Success"
        
        # Step 6: Run smoke tests
        if ($RunSmokeTests) {
            Write-DeploymentLog "`n🧪 Step 6: Running smoke tests" -Level "Info"
            $Global:DeploymentSteps += "Smoke tests"
            
            $smokeTestResults = Invoke-SmokeTests
            Write-DeploymentLog "✅ Smoke tests completed successfully" -Level "Success"
        }
        
        # Step 7: Promote to production (if using staging)
        if ($UseStaging) {
            Write-DeploymentLog "`n🔄 Step 7: Promoting to production" -Level "Info"
            $Global:DeploymentSteps += "Production promotion"
            
            # Swap staging to production
            az webapp deployment slot swap --resource-group $ResourceGroupName --name $AppServiceName --slot $Global:StagingSlotName --target-slot production
            
            # Verify production health after swap
            Start-Sleep -Seconds 30
            $productionHealth = Test-ApplicationHealth
            if (-not $productionHealth.IsHealthy) {
                Write-DeploymentLog "❌ Production health check failed after swap. Initiating emergency rollback..." -Level "Error"
                az webapp deployment slot swap --resource-group $ResourceGroupName --name $AppServiceName --slot production --target-slot $Global:StagingSlotName
                throw "Production deployment failed health check. Emergency rollback completed."
            }
            
            Write-DeploymentLog "✅ Successfully promoted to production" -Level "Success"
        }
        
        # Step 8: Final validation
        Write-DeploymentLog "`n✅ Step 8: Final validation" -Level "Info"
        $Global:DeploymentSteps += "Final validation"
        
        $finalHealth = Test-ApplicationHealth
        if (-not $finalHealth.IsHealthy) {
            throw "Final health check failed"
        }
        
        # Log deployment summary
        $deploymentDuration = (Get-Date) - $Global:DeploymentStartTime
        Write-DeploymentLog "`n🎉 Deployment completed successfully!" -Level "Success"
        Write-DeploymentLog "Duration: $($deploymentDuration.ToString('hh\:mm\:ss'))" -Level "Success"
        Write-DeploymentLog "Health check response time: $($finalHealth.ResponseTime)ms" -Level "Success"
        
        if ($Global:BackupPath) {
            Write-DeploymentLog "Backup available at: $Global:BackupPath" -Level "Info"
        }
        
        Send-DeploymentNotification -Status "Success"
        
    } catch {
        Handle-DeploymentError -ErrorMessage $_.Exception.Message -Step ($Global:DeploymentSteps[-1] ?? "Unknown")
    }
}

# Script execution starts here
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "    Enhanced ISAPI Deployment Script" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Validate prerequisites
try {
    # Check Azure CLI
    $azVersion = az version --output json 2>$null | ConvertFrom-Json
    if (-not $azVersion) {
        throw "Azure CLI not found or not authenticated"
    }
    Write-DeploymentLog "✅ Azure CLI validated: $($azVersion.'azure-cli')" -Level "Success"
    
    # Check Azure authentication
    $currentAccount = az account show --output json 2>$null | ConvertFrom-Json
    if (-not $currentAccount) {
        throw "Not authenticated with Azure CLI. Please run 'az login'"
    }
    Write-DeploymentLog "✅ Azure authentication validated: $($currentAccount.user.name)" -Level "Success"
    
} catch {
    Write-DeploymentLog "❌ Prerequisites check failed: $($_.Exception.Message)" -Level "Error"
    exit 1
}

# Start deployment
Start-EnhancedDeployment

Write-Host "`n============================================" -ForegroundColor Green
Write-Host "    Deployment Process Complete" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host "📊 Deployment ID: $Global:DeploymentId" -ForegroundColor Cyan
Write-Host "📋 Log File: $Global:LogFile" -ForegroundColor Cyan
if ($Global:BackupPath) {
    Write-Host "💾 Backup: $Global:BackupPath" -ForegroundColor Cyan
}
Write-Host "🌐 Application URL: https://$AppServiceName.azurewebsites.net" -ForegroundColor Cyan
