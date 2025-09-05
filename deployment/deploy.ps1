param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$AppServiceName,
    
    [Parameter(Mandatory=$false)]
    [string]$ISAPIFilePath = ".\YourISAPIFilter.dll",
    
    [Parameter(Mandatory=$false)]
    [string]$WebConfigPath = ".\web.config",
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [switch]$ValidateOnly,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipDependencyCheck
)

# Script to deploy ISAPI filter to Azure App Service
Write-Host "🚀 ISAPI Filter Deployment to Azure App Service" -ForegroundColor Green
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Cyan
Write-Host "App Service: $AppServiceName" -ForegroundColor Cyan
Write-Host "ISAPI DLL: $ISAPIFilePath" -ForegroundColor Cyan
Write-Host

$DeploymentResults = @{
    PreValidation = $false
    AzureConnection = $false
    ResourceValidation = $false
    DLLValidation = $false
    Deployment = $false
    PostValidation = $false
    OverallSuccess = $false
}

# Pre-deployment validation
Write-Host "🔍 Pre-Deployment Validation..." -ForegroundColor Yellow

# Check if Azure CLI is installed and working
try {
    $azVersion = az version --output json 2>$null | ConvertFrom-Json
    Write-Host "✅ Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Green
    $DeploymentResults.PreValidation = $true
} catch {
    Write-Host "❌ Azure CLI is not installed or not in PATH" -ForegroundColor Red
    Write-Host "💡 Install Azure CLI from: https://learn.microsoft.com/cli/azure/install-azure-cli" -ForegroundColor Blue
    exit 1
}

# Validate ISAPI DLL exists and architecture
if (-not (Test-Path $ISAPIFilePath)) {
    Write-Host "❌ ISAPI DLL not found: $ISAPIFilePath" -ForegroundColor Red
    exit 1
}

Write-Host "✅ ISAPI DLL found: $ISAPIFilePath" -ForegroundColor Green

# Run DLL validation if dependency checker is available and not skipped
if (-not $SkipDependencyCheck) {
    $DependencyScript = Join-Path $PSScriptRoot "..\scripts\check-delphi-dependencies.ps1"
    if (Test-Path $DependencyScript) {
        Write-Host "🔍 Running DLL validation..." -ForegroundColor Yellow
        try {
            $ValidationResult = & $DependencyScript -DllPath $ISAPIFilePath
            if ($ValidationResult.OverallSuccess) {
                Write-Host "✅ DLL validation passed" -ForegroundColor Green
                $DeploymentResults.DLLValidation = $true
            } else {
                Write-Host "❌ DLL validation failed - deployment may not work correctly" -ForegroundColor Red
                if (-not $Force) {
                    Write-Host "💡 Use -Force to proceed anyway or fix the issues above" -ForegroundColor Blue
                    exit 1
                } else {
                    Write-Host "⚠️ Proceeding with deployment despite validation issues (Force mode)" -ForegroundColor Yellow
                }
            }
        } catch {
            Write-Host "⚠️ DLL validation failed: $($_.Exception.Message)" -ForegroundColor Yellow
            if (-not $Force) {
                exit 1
            }
        }
    } else {
        Write-Host "⚠️ DLL validation script not found - skipping validation" -ForegroundColor Yellow
    }
} else {
    Write-Host "ℹ️ Skipping DLL validation (SkipDependencyCheck specified)" -ForegroundColor Cyan
    $DeploymentResults.DLLValidation = $true
}

if ($ValidateOnly) {
    Write-Host "✅ Validation completed (ValidateOnly mode)" -ForegroundColor Green
    exit 0
}

# Login check
try {
    $account = az account show --output json 2>$null | ConvertFrom-Json
    Write-Host "✅ Logged in as: $($account.user.name)" -ForegroundColor Green
    
    if ($SubscriptionId -and $account.id -ne $SubscriptionId) {
        Write-Host "🔄 Switching to subscription: $SubscriptionId" -ForegroundColor Yellow
        az account set --subscription $SubscriptionId
    }
} catch {
    Write-Error "❌ Not logged in to Azure. Please run 'az login' first."
    exit 1
}

# Validate required files
if (-not (Test-Path $ISAPIFilePath)) {
    Write-Error "❌ ISAPI DLL file not found: $ISAPIFilePath"
    Write-Host "💡 Please place your compiled ISAPI DLL in the deployment folder and update the -ISAPIFilePath parameter."
    exit 1
}

if (-not (Test-Path $WebConfigPath)) {
    Write-Error "❌ web.config file not found: $WebConfigPath"
    exit 1
}

# Check if App Service exists
Write-Host "🔍 Checking if App Service exists..." -ForegroundColor Yellow
try {
    $appService = az webapp show --name $AppServiceName --resource-group $ResourceGroupName --output json 2>$null | ConvertFrom-Json
    Write-Host "✅ App Service found: $($appService.defaultHostName)" -ForegroundColor Green
} catch {
    Write-Error "❌ App Service '$AppServiceName' not found in resource group '$ResourceGroupName'"
    Write-Host "💡 Please deploy the infrastructure first using the Bicep template."
    exit 1
}

# Create deployment package
Write-Host "📦 Creating deployment package..." -ForegroundColor Yellow

$tempDir = Join-Path $env:TEMP "isapi-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$deploymentDir = Join-Path $tempDir "wwwroot"
$binDir = Join-Path $deploymentDir "bin"

try {
    # Create directory structure
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    
    # Copy ISAPI DLL to bin folder
    $dllName = Split-Path $ISAPIFilePath -Leaf
    $targetDllPath = Join-Path $binDir $dllName
    Copy-Item $ISAPIFilePath $targetDllPath -Force
    Write-Host "✅ Copied ISAPI DLL: $dllName" -ForegroundColor Green
    
    # Update web.config with actual DLL name
    $webConfigContent = Get-Content $WebConfigPath -Raw
    $webConfigContent = $webConfigContent -replace "YourISAPIFilter\.dll", $dllName
    $webConfigContent | Set-Content (Join-Path $deploymentDir "web.config") -Encoding UTF8
    Write-Host "✅ Updated web.config with DLL name: $dllName" -ForegroundColor Green
    
    # Create a simple default page
    $defaultPage = @"
<!DOCTYPE html>
<html>
<head>
    <title>Delphi ISAPI Filter - Azure App Service</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { color: #0078d4; }
        .success { color: #107c10; }
    </style>
</head>
<body>
    <h1 class="header">🚀 Delphi ISAPI Filter Deployed Successfully!</h1>
    <p class="success">Your legacy Delphi ISAPI filter is now running on Azure App Service.</p>
    <h3>Deployment Information:</h3>
    <ul>
        <li><strong>ISAPI DLL:</strong> $dllName</li>
        <li><strong>Deployed:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</li>
        <li><strong>App Service:</strong> $AppServiceName</li>
        <li><strong>Resource Group:</strong> $ResourceGroupName</li>
    </ul>
    <h3>Test Your ISAPI Filter:</h3>
    <p>Try accessing: <a href="$dllName" target="_blank">$dllName</a></p>
    <p>Or use your custom endpoints as configured in your ISAPI filter.</p>
</body>
</html>
"@
    $defaultPage | Set-Content (Join-Path $deploymentDir "default.html") -Encoding UTF8
    
    # Create deployment zip
    $zipPath = Join-Path $tempDir "deployment.zip"
    if (Get-Command Compress-Archive -ErrorAction SilentlyContinue) {
        Compress-Archive -Path "$deploymentDir\*" -DestinationPath $zipPath -Force
    } else {
        # Fallback for older PowerShell versions
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory($deploymentDir, $zipPath)
    }
    
    Write-Host "✅ Created deployment package: $zipPath" -ForegroundColor Green
    
} catch {
    Write-Error "❌ Failed to create deployment package: $($_.Exception.Message)"
    exit 1
}

# Deploy to App Service
Write-Host "🚀 Deploying to App Service..." -ForegroundColor Yellow

try {
    # Stop the app service before deployment (optional, for zero-downtime use slots)
    if ($Force) {
        Write-Host "⏸️ Stopping App Service..." -ForegroundColor Yellow
        az webapp stop --name $AppServiceName --resource-group $ResourceGroupName --output none
    }
    
    # Deploy using zip deployment
    Write-Host "📤 Uploading deployment package..." -ForegroundColor Yellow
    az webapp deployment source config-zip --name $AppServiceName --resource-group $ResourceGroupName --src $zipPath --output none
    
    # Start the app service
    if ($Force) {
        Write-Host "▶️ Starting App Service..." -ForegroundColor Yellow
        az webapp start --name $AppServiceName --resource-group $ResourceGroupName --output none
    }
    
    Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Error "❌ Deployment failed: $($_.Exception.Message)"
    
    # Start the app service even if deployment failed
    if ($Force) {
        Write-Host "▶️ Starting App Service after failed deployment..." -ForegroundColor Yellow
        az webapp start --name $AppServiceName --resource-group $ResourceGroupName --output none
    }
    exit 1
} finally {
    # Cleanup temp files
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Get the App Service URL
$appUrl = "https://$($appService.defaultHostName)"
Write-Host "" -ForegroundColor White
Write-Host "🎉 Deployment Summary:" -ForegroundColor Green
Write-Host "   App Service URL: $appUrl" -ForegroundColor Cyan
Write-Host "   ISAPI DLL: $dllName" -ForegroundColor Cyan
Write-Host "   Resource Group: $ResourceGroupName" -ForegroundColor Cyan
Write-Host "" -ForegroundColor White

# Optional: Open browser
$openBrowser = Read-Host "🌐 Would you like to open the App Service in your browser? (y/N)"
if ($openBrowser -eq 'y' -or $openBrowser -eq 'Y') {
    Start-Process $appUrl
}

# Show deployment logs
Write-Host "📋 To view deployment logs, run:" -ForegroundColor Yellow
Write-Host "   az webapp log tail --name $AppServiceName --resource-group $ResourceGroupName" -ForegroundColor White

Write-Host "" -ForegroundColor White
Write-Host "✅ ISAPI Filter deployment completed successfully!" -ForegroundColor Green
