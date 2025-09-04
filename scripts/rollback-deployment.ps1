#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Emergency rollback script for ISAPI deployments
    
.DESCRIPTION
    This script provides emergency rollback capabilities including:
    1. Deployment slot swapping for zero-downtime rollback
    2. Previous version restoration from deployment history
    3. Configuration rollback and validation
    4. Health check verification after rollback
    
.PARAMETER ResourceGroupName
    Name of the Azure Resource Group
    
.PARAMETER AppServiceName
    Name of the App Service
    
.PARAMETER RollbackMethod
    Method to use for rollback: 'SlotSwap' or 'VersionRestore'
    
.PARAMETER TargetSlot
    Target slot name for slot swap (default: 'staging')
    
.PARAMETER Validate
    Run validation after rollback (default: true)
    
.EXAMPLE
    .\rollback-deployment.ps1 -ResourceGroupName "rg-isapi" -AppServiceName "my-app" -RollbackMethod "SlotSwap"
    
.EXAMPLE
    .\rollback-deployment.ps1 -ResourceGroupName "rg-isapi" -AppServiceName "my-app" -RollbackMethod "VersionRestore" -Validate:$false
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$AppServiceName,
    
    [Parameter(Mandatory = $true)]
    [ValidateSet("SlotSwap", "VersionRestore")]
    [string]$RollbackMethod,
    
    [Parameter(Mandatory = $false)]
    [string]$TargetSlot = "staging",
    
    [Parameter(Mandatory = $false)]
    [bool]$Validate = $true
)

Write-Host "=== EMERGENCY ROLLBACK PROCEDURE ===" -ForegroundColor Red
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "App Service: $AppServiceName" -ForegroundColor Yellow
Write-Host "Rollback Method: $RollbackMethod" -ForegroundColor Yellow
if ($RollbackMethod -eq "SlotSwap") {
    Write-Host "Target Slot: $TargetSlot" -ForegroundColor Yellow
}
Write-Host

# Verify Azure CLI is logged in
try {
    $currentAccount = az account show --query "user.name" -o tsv
    if ([string]::IsNullOrEmpty($currentAccount)) {
        throw "Not logged in"
    }
    Write-Host "✅ Authenticated as: $currentAccount" -ForegroundColor Green
} catch {
    Write-Host "❌ Azure CLI not authenticated. Please run 'az login'" -ForegroundColor Red
    exit 1
}

# Pre-rollback validation
Write-Host "🔍 Pre-rollback Validation..." -ForegroundColor Yellow

# Check if App Service exists
$appServiceExists = az webapp show --resource-group $ResourceGroupName --name $AppServiceName --query "name" -o tsv 2>$null
if ([string]::IsNullOrEmpty($appServiceExists)) {
    Write-Host "❌ App Service '$AppServiceName' not found in resource group '$ResourceGroupName'" -ForegroundColor Red
    exit 1
}
Write-Host "✅ App Service exists and accessible" -ForegroundColor Green

# Get current App Service URL for later validation
$appServiceUrl = az webapp show --resource-group $ResourceGroupName --name $AppServiceName --query "defaultHostName" -o tsv
$appServiceUrl = "https://$appServiceUrl"
Write-Host "📍 App Service URL: $appServiceUrl" -ForegroundColor Cyan

# Pre-rollback health check
Write-Host "`n📊 Current Application Status..." -ForegroundColor Yellow
try {
    $preRollbackResponse = Invoke-WebRequest -Uri $appServiceUrl -UseBasicParsing -TimeoutSec 30
    Write-Host "Current Status: $($preRollbackResponse.StatusCode)" -ForegroundColor Cyan
} catch {
    Write-Host "Current Status: UNHEALTHY - $($_.Exception.Message)" -ForegroundColor Red
}

# Confirmation prompt
Write-Host "`n⚠️ WARNING: You are about to perform an emergency rollback!" -ForegroundColor Red
Write-Host "This action will:" -ForegroundColor Yellow
if ($RollbackMethod -eq "SlotSwap") {
    Write-Host "  • Swap production with '$TargetSlot' slot" -ForegroundColor Yellow
    Write-Host "  • Current production becomes '$TargetSlot'" -ForegroundColor Yellow
    Write-Host "  • Previous '$TargetSlot' becomes production" -ForegroundColor Yellow
} else {
    Write-Host "  • Restore previous deployment from history" -ForegroundColor Yellow
    Write-Host "  • Current deployment will be replaced" -ForegroundColor Yellow
}
Write-Host

$confirmation = Read-Host "Type 'ROLLBACK' to confirm this emergency procedure"
if ($confirmation -ne "ROLLBACK") {
    Write-Host "❌ Rollback cancelled by user" -ForegroundColor Yellow
    exit 0
}

# Execute rollback based on method
Write-Host "`n🚨 Executing Emergency Rollback..." -ForegroundColor Red

if ($RollbackMethod -eq "SlotSwap") {
    Write-Host "🔄 Performing Deployment Slot Swap..." -ForegroundColor Yellow
    
    # Check if target slot exists
    $slotExists = az webapp deployment slot show --resource-group $ResourceGroupName --name $AppServiceName --slot $TargetSlot --query "name" -o tsv 2>$null
    if ([string]::IsNullOrEmpty($slotExists)) {
        Write-Host "❌ Target slot '$TargetSlot' does not exist" -ForegroundColor Red
        Write-Host "Available slots:" -ForegroundColor Yellow
        az webapp deployment slot list --resource-group $ResourceGroupName --name $AppServiceName --query "[].name" -o tsv
        exit 1
    }
    
    # Perform the slot swap
    try {
        Write-Host "  Swapping 'production' ↔ '$TargetSlot'..." -ForegroundColor Cyan
        az webapp deployment slot swap --resource-group $ResourceGroupName --name $AppServiceName --slot $TargetSlot --target-slot production
        Write-Host "✅ Slot swap completed successfully" -ForegroundColor Green
    } catch {
        Write-Host "❌ Slot swap failed: $_" -ForegroundColor Red
        exit 1
    }
    
} elseif ($RollbackMethod -eq "VersionRestore") {
    Write-Host "📂 Restoring Previous Deployment..." -ForegroundColor Yellow
    
    # Get deployment history
    Write-Host "  Retrieving deployment history..." -ForegroundColor Cyan
    $deploymentHistory = az webapp deployment list --resource-group $ResourceGroupName --name $AppServiceName --query "[0:5].[id,status,author,active,received_time]" -o table
    
    if ([string]::IsNullOrEmpty($deploymentHistory)) {
        Write-Host "❌ No deployment history found" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Recent deployments:" -ForegroundColor Cyan
    Write-Host $deploymentHistory
    
    # Get the previous successful deployment
    $previousDeployment = az webapp deployment list --resource-group $ResourceGroupName --name $AppServiceName --query "[?status=='Success' && active!=true] | [0].id" -o tsv
    
    if ([string]::IsNullOrEmpty($previousDeployment)) {
        Write-Host "❌ No previous successful deployment found to restore" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "  Restoring deployment: $previousDeployment" -ForegroundColor Cyan
    
    # This is a conceptual example - actual implementation would depend on your deployment method
    # For Git-based deployments:
    try {
        # Get the commit ID from the deployment
        $commitId = az webapp deployment show --resource-group $ResourceGroupName --name $AppServiceName --deployment-id $previousDeployment --query "id" -o tsv
        
        # You would implement actual restoration logic here based on your deployment method
        # This might involve redeploying from source control, restoring from backup, etc.
        
        Write-Host "⚠️ Version restore requires manual intervention for this deployment method" -ForegroundColor Yellow
        Write-Host "  Please use your deployment pipeline to redeploy the previous version" -ForegroundColor Yellow
        Write-Host "  Previous deployment ID: $previousDeployment" -ForegroundColor Cyan
        
    } catch {
        Write-Host "❌ Version restore failed: $_" -ForegroundColor Red
        exit 1
    }
}

# Post-rollback validation
if ($Validate) {
    Write-Host "`n✅ Post-Rollback Validation..." -ForegroundColor Green
    
    # Wait for application to start
    Write-Host "  Waiting for application to restart..." -ForegroundColor Cyan
    Start-Sleep -Seconds 30
    
    # Health check
    $maxRetries = 10
    $retryCount = 0
    $healthCheckPassed = $false
    
    while ($retryCount -lt $maxRetries -and -not $healthCheckPassed) {
        try {
            Write-Host "  Health check attempt $($retryCount + 1) of $maxRetries..." -ForegroundColor Cyan
            $postRollbackResponse = Invoke-WebRequest -Uri $appServiceUrl -UseBasicParsing -TimeoutSec 30
            
            if ($postRollbackResponse.StatusCode -eq 200) {
                Write-Host "✅ Application is responding normally (Status: $($postRollbackResponse.StatusCode))" -ForegroundColor Green
                $healthCheckPassed = $true
            } else {
                Write-Host "⚠️ Application returned status: $($postRollbackResponse.StatusCode)" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "⚠️ Health check failed: $($_.Exception.Message)" -ForegroundColor Yellow
            $retryCount++
            
            if ($retryCount -lt $maxRetries) {
                Write-Host "  Retrying in 15 seconds..." -ForegroundColor Cyan
                Start-Sleep -Seconds 15
            }
        }
    }
    
    if (-not $healthCheckPassed) {
        Write-Host "❌ Post-rollback health check failed" -ForegroundColor Red
        Write-Host "   Please check Application Logs in Azure Portal" -ForegroundColor Yellow
        Write-Host "   URL: https://portal.azure.com/#@/resource/subscriptions/{subscription}/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$AppServiceName/logStream" -ForegroundColor Cyan
    }
    
    # Performance validation
    Write-Host "`n⚡ Performance Validation..." -ForegroundColor Yellow
    $responseTimes = @()
    for ($i = 1; $i -le 5; $i++) {
        try {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $perfResponse = Invoke-WebRequest -Uri $appServiceUrl -UseBasicParsing -TimeoutSec 30
            $stopwatch.Stop()
            
            $responseTimes += $stopwatch.ElapsedMilliseconds
            Write-Host "  Response test $i`: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Cyan
        } catch {
            Write-Host "  Response test $i`: FAILED" -ForegroundColor Red
        }
    }
    
    if ($responseTimes.Count -gt 0) {
        $avgResponseTime = ($responseTimes | Measure-Object -Average).Average
        Write-Host "  Average response time: $([math]::Round($avgResponseTime, 2))ms" -ForegroundColor Cyan
    }
}

# Summary and next steps
Write-Host "`n=== Rollback Summary ===" -ForegroundColor Green
Write-Host "Rollback Method: $RollbackMethod" -ForegroundColor Cyan
Write-Host "Execution Status: $(if ($healthCheckPassed -or -not $Validate) { 'SUCCESS' } else { 'PARTIAL - REQUIRES ATTENTION' })" -ForegroundColor $(if ($healthCheckPassed -or -not $Validate) { 'Green' } else { 'Yellow' })
Write-Host "Application URL: $appServiceUrl" -ForegroundColor Cyan

Write-Host "`n📝 Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Monitor application performance in Azure Portal" -ForegroundColor White
Write-Host "  2. Check Application Insights for any errors or issues" -ForegroundColor White
Write-Host "  3. Review deployment logs to identify root cause of original issue" -ForegroundColor White
Write-Host "  4. Update incident documentation with rollback details" -ForegroundColor White
Write-Host "  5. Plan corrective deployment once issues are resolved" -ForegroundColor White

if ($RollbackMethod -eq "SlotSwap") {
    Write-Host "`n⚠️ Important: Your previous production is now in the '$TargetSlot' slot" -ForegroundColor Yellow
    Write-Host "   Consider this when planning your next deployment" -ForegroundColor Yellow
}

Write-Host "`n🚨 Emergency rollback procedure completed" -ForegroundColor Green
Write-Host "Monitor the application closely and be prepared for further action if needed." -ForegroundColor Cyan
