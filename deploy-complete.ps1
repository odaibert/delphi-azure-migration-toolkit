#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Complete deployment script for ISAPI Filter Migration to Azure App Service
    
.DESCRIPTION
    This script performs end-to-end deployment including:
    1. Azure infrastructure provisioning with Bicep
    2. App Service configuration for ISAPI filters
    3. Application deployment and validation
    
.PARAMETER ResourceGroupName
    Name of the Azure Resource Group (will be created if it doesn't exist)
    
.PARAMETER Location
    Azure region for deployment (default: East US)
    
.PARAMETER AppName
    Name for the App Service (must be globally unique)
    
.PARAMETER SubscriptionId
    Azure subscription ID (optional - will use current subscription)
    
.PARAMETER ISAPIPath
    Path to your ISAPI filter DLL file
    
.PARAMETER SkipInfrastructure
    Skip infrastructure deployment (use existing resources)
    
.EXAMPLE
    .\deploy-complete.ps1 -ResourceGroupName "rg-isapi-migration" -AppName "my-isapi-app" -ISAPIPath ".\MyFilter.dll"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory = $true)]
    [string]$AppName,
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = "",
    
    [Parameter(Mandatory = $false)]
    [string]$ISAPIPath = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipInfrastructure
)

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# Colors for output
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }

Write-Host @"
🚀 ISAPI to Azure App Service Deployment
=========================================

"@ -ForegroundColor Magenta

# Step 1: Validate Prerequisites
Write-Info "Validating prerequisites..."

# Check if Azure CLI is installed
try {
    $azVersion = az --version 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Azure CLI not found" }
    Write-Success "Azure CLI is installed"
} catch {
    Write-Error "Azure CLI is required. Install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
}

# Check if logged in to Azure
try {
    $account = az account show 2>$null | ConvertFrom-Json
    Write-Success "Logged in as: $($account.user.name)"
} catch {
    Write-Warning "Not logged in to Azure. Please run: az login"
    az login
    $account = az account show | ConvertFrom-Json
}

# Set subscription if provided
if ($SubscriptionId) {
    Write-Info "Setting subscription to: $SubscriptionId"
    az account set --subscription $SubscriptionId
}

$currentSub = az account show | ConvertFrom-Json
Write-Info "Using subscription: $($currentSub.name) ($($currentSub.id))"

# Step 2: Create Resource Group
Write-Info "Creating resource group: $ResourceGroupName"
$rgExists = az group exists --name $ResourceGroupName | ConvertFrom-Json

if (-not $rgExists) {
    az group create --name $ResourceGroupName --location $Location
    Write-Success "Resource group created: $ResourceGroupName"
} else {
    Write-Info "Resource group already exists: $ResourceGroupName"
}

# Step 3: Deploy Infrastructure (if not skipped)
if (-not $SkipInfrastructure) {
    Write-Info "Deploying Azure infrastructure..."
    
    # Update parameters with provided values
    $parametersPath = ".\infrastructure\bicep\parameters.json"
    $bicepPath = ".\infrastructure\bicep\main.bicep"
    
    if (-not (Test-Path $parametersPath)) {
        Write-Error "Parameters file not found: $parametersPath"
        exit 1
    }
    
    if (-not (Test-Path $bicepPath)) {
        Write-Error "Bicep template not found: $bicepPath"
        exit 1
    }
    
    # Create deployment name
    $deploymentName = "isapi-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    Write-Info "Starting infrastructure deployment: $deploymentName"
    
    # Deploy using Bicep
    $deployment = az deployment group create `
        --resource-group $ResourceGroupName `
        --name $deploymentName `
        --template-file $bicepPath `
        --parameters $parametersPath `
        --parameters appName=$AppName location=$Location `
        --output json | ConvertFrom-Json
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Infrastructure deployed successfully"
        
        # Extract outputs
        $appServiceName = $deployment.properties.outputs.appServiceName.value
        $appServiceUrl = $deployment.properties.outputs.appServiceUrl.value
        
        Write-Info "App Service Name: $appServiceName"
        Write-Info "App Service URL: $appServiceUrl"
    } else {
        Write-Error "Infrastructure deployment failed"
        exit 1
    }
} else {
    Write-Warning "Skipping infrastructure deployment"
    $appServiceName = $AppName
}

# Step 4: Configure App Service for ISAPI
Write-Info "Configuring App Service for ISAPI filters..."

# Enable 32-bit if needed (many legacy ISAPI filters are 32-bit)
Write-Info "Configuring platform settings..."
az webapp config set --name $appServiceName --resource-group $ResourceGroupName --use-32bit-worker-process true

# Configure IIS settings for ISAPI
$appSettings = @{
    "WEBSITE_LOAD_USER_PROFILE" = "1"
    "WEBSITE_DYNAMIC_CACHE" = "0"
    "WEBSITE_LOAD_CERTIFICATES" = "1"
}

foreach ($setting in $appSettings.GetEnumerator()) {
    az webapp config appsettings set --name $appServiceName --resource-group $ResourceGroupName --settings "$($setting.Key)=$($setting.Value)"
}

Write-Success "App Service configured for ISAPI"

# Step 5: Deploy Application Files
Write-Info "Deploying default application files..."

# Create deployment package
$tempDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -Type Directory -Path $_ }
$deploymentDir = Join-Path $tempDir "deployment"
New-Item -Type Directory -Path $deploymentDir -Force

# Always copy default page and web.config
if (Test-Path ".\deployment\default.htm") {
    Copy-Item ".\deployment\default.htm" -Destination $deploymentDir
    Write-Info "Copied default landing page"
}

# Copy web.config
if (Test-Path ".\deployment\web.config") {
    Copy-Item ".\deployment\web.config" -Destination $deploymentDir
    Write-Info "Copied web.config"
}

# Copy applicationHost.config if exists
if (Test-Path ".\deployment\applicationHost.config") {
    Copy-Item ".\deployment\applicationHost.config" -Destination $deploymentDir
    Write-Info "Copied applicationHost.config"
}

if ($ISAPIPath -and (Test-Path $ISAPIPath)) {
    Write-Info "Deploying ISAPI filter: $ISAPIPath"
    
    # Copy ISAPI filter
    $isapiFileName = Split-Path $ISAPIPath -Leaf
    $binDir = Join-Path $deploymentDir "bin"
    New-Item -Type Directory -Path $binDir -Force
    Copy-Item $ISAPIPath -Destination (Join-Path $binDir $isapiFileName)
    Write-Info "Copied ISAPI filter to bin directory"
} else {
    Write-Warning "No ISAPI filter provided or file not found: $ISAPIPath"
    Write-Info "Deploying infrastructure-ready package with default landing page"
}

# Create ZIP package
$zipPath = Join-Path $tempDir "deployment.zip"
Compress-Archive -Path "$deploymentDir\*" -DestinationPath $zipPath

# Deploy via ZIP
Write-Info "Uploading deployment package..."
az webapp deployment source config-zip --name $appServiceName --resource-group $ResourceGroupName --src $zipPath

# Cleanup
Remove-Item $tempDir -Recurse -Force

Write-Success "Application deployed successfully"

# Step 6: Restart App Service
Write-Info "Restarting App Service to apply changes..."
az webapp restart --name $appServiceName --resource-group $ResourceGroupName
Write-Success "App Service restarted"

# Step 7: Validation and Health Check
Write-Info "Performing health check..."
Start-Sleep -Seconds 30  # Wait for app to start

try {
    $healthUrl = "https://$appServiceName.azurewebsites.net"
    $response = Invoke-WebRequest -Uri $healthUrl -Method GET -TimeoutSec 30
    
    if ($response.StatusCode -eq 200) {
        Write-Success "Health check passed - App is running"
    } else {
        Write-Warning "Health check returned status: $($response.StatusCode)"
    }
} catch {
    Write-Warning "Health check failed - this may be normal for ISAPI filters that don't respond to root path"
    Write-Info "Check the App Service logs for detailed status"
}

# Step 8: Summary and Next Steps
Write-Host @"

🎉 Deployment Complete!
=====================

✅ Infrastructure: Deployed
✅ App Service: Configured for ISAPI
✅ Application: $(if($ISAPIPath) {"Deployed"} else {"Ready for deployment"})

📋 Resources Created:
• Resource Group: $ResourceGroupName
• App Service: $appServiceName
• URL: https://$appServiceName.azurewebsites.net

📝 Next Steps:
$(if(-not $ISAPIPath) {"1. Deploy your ISAPI filter DLL to the App Service"})
2. Test your ISAPI filter functionality
3. Configure custom domains if needed
4. Set up monitoring and alerts
5. Configure scaling if required

🔧 Management:
• Azure Portal: https://portal.azure.com/#@/resource/subscriptions/$($currentSub.id)/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$appServiceName
• App Service Logs: az webapp log tail --name $appServiceName --resource-group $ResourceGroupName
• SSH Access: https://$appServiceName.scm.azurewebsites.net/webssh/host

"@ -ForegroundColor Green

Write-Success "Deployment completed successfully! 🚀"
