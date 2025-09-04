param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-isapi-migration",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory=$false)]
    [string]$AppName = "isapi-app",
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = ""
)

# Setup script for Azure environment and infrastructure deployment
Write-Host "🚀 Setting up Azure Environment for ISAPI Migration" -ForegroundColor Green
Write-Host "📖 Documentation: https://docs.microsoft.com/azure/app-service/" -ForegroundColor Cyan
Write-Host "⚠️  Review sandbox restrictions: https://github.com/projectkudu/kudu/wiki/Azure-Web-App-sandbox" -ForegroundColor Yellow

# Check prerequisites
Write-Host "🔍 Checking prerequisites..." -ForegroundColor Yellow

# Check Azure CLI
try {
    $azVersion = az version --output json 2>$null | ConvertFrom-Json
    Write-Host "✅ Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Green
} catch {
    Write-Error "❌ Azure CLI is not installed. Please install it from: https://aka.ms/installazurecliwindows"
    exit 1
}

# Check PowerShell version
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -lt 5) {
    Write-Warning "⚠️ PowerShell version $($psVersion.Major).$($psVersion.Minor) detected. PowerShell 5.0+ recommended."
} else {
    Write-Host "✅ PowerShell version: $($psVersion.Major).$($psVersion.Minor)" -ForegroundColor Green
}

# Azure login and subscription setup
Write-Host "🔐 Checking Azure authentication..." -ForegroundColor Yellow

try {
    $account = az account show --output json 2>$null | ConvertFrom-Json
    Write-Host "✅ Already logged in as: $($account.user.name)" -ForegroundColor Green
    
    if ($SubscriptionId -and $account.id -ne $SubscriptionId) {
        Write-Host "🔄 Switching to subscription: $SubscriptionId" -ForegroundColor Yellow
        az account set --subscription $SubscriptionId
        $account = az account show --output json | ConvertFrom-Json
    }
    
    Write-Host "📋 Active subscription: $($account.name) ($($account.id))" -ForegroundColor Cyan
} catch {
    Write-Host "🔑 Please log in to Azure..." -ForegroundColor Yellow
    az login
    
    if ($SubscriptionId) {
        az account set --subscription $SubscriptionId
    }
    
    $account = az account show --output json | ConvertFrom-Json
    Write-Host "✅ Logged in as: $($account.user.name)" -ForegroundColor Green
}

# Create resource group
Write-Host "📦 Creating resource group..." -ForegroundColor Yellow

$rgExists = az group exists --name $ResourceGroupName --output tsv
if ($rgExists -eq "true") {
    Write-Host "✅ Resource group '$ResourceGroupName' already exists" -ForegroundColor Green
} else {
    Write-Host "🆕 Creating resource group '$ResourceGroupName' in '$Location'..." -ForegroundColor Yellow
    az group create --name $ResourceGroupName --location $Location --output none
    Write-Host "✅ Resource group created successfully" -ForegroundColor Green
}

# Deploy infrastructure based on chosen method
Write-Host "🏗️ Deploying infrastructure using Azure Bicep..." -ForegroundColor Yellow

$deploymentStartTime = Get-Date

try {
    Write-Host "📋 Deploying using Azure Bicep..." -ForegroundColor Yellow
    
    $bicepFile = Join-Path $PSScriptRoot "..\infrastructure\bicep\main.bicep"
    $parametersFile = Join-Path $PSScriptRoot "..\infrastructure\bicep\parameters.json"
    
    if (-not (Test-Path $bicepFile)) {
        Write-Error "❌ Bicep template not found: $bicepFile"
        exit 1
    }
    
    # Update parameters file with current values
    $parameters = @{
        appName = @{ value = $AppName }
        location = @{ value = $Location }
        appServicePlanSku = @{ value = "S1" }
        enableApplicationInsights = @{ value = $true }
        enableAzureFiles = @{ value = $true }
    }
    
    $parametersJson = @{
        '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
        contentVersion = "1.0.0.0"
        parameters = $parameters
    } | ConvertTo-Json -Depth 10
    
    $parametersJson | Set-Content $parametersFile -Encoding UTF8
    
    # Deploy the template
    $deploymentName = "isapi-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    Write-Host "🚀 Starting deployment: $deploymentName" -ForegroundColor Yellow
    $deployment = az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file $bicepFile `
        --parameters "@$parametersFile" `
        --name $deploymentName `
        --output json | ConvertFrom-Json
    
    if ($deployment) {
        Write-Host "✅ Bicep deployment completed successfully!" -ForegroundColor Green
        
        # Get outputs
        $outputs = $deployment.properties.outputs
        if ($outputs) {
            Write-Host "📋 Deployment Outputs:" -ForegroundColor Cyan
            foreach ($output in $outputs.PSObject.Properties) {
                Write-Host "   $($output.Name): $($output.Value.value)" -ForegroundColor White
            }
        }
    }
    
    $deploymentDuration = (Get-Date) - $deploymentStartTime
    Write-Host "⏱️ Deployment completed in $([math]::Round($deploymentDuration.TotalMinutes, 1)) minutes" -ForegroundColor Green
    
} catch {
    Write-Error "❌ Infrastructure deployment failed: $($_.Exception.Message)"
    exit 1
}

# Verify deployment
Write-Host "🔍 Verifying deployment..." -ForegroundColor Yellow

try {
    $appService = az webapp show --name $AppName --resource-group $ResourceGroupName --output json | ConvertFrom-Json
    $appUrl = "https://$($appService.defaultHostName)"
    
    Write-Host "✅ App Service is running: $appUrl" -ForegroundColor Green
    
    # Test connectivity
    try {
        $response = Invoke-WebRequest -Uri $appUrl -Method HEAD -TimeoutSec 30 -UseBasicParsing
        Write-Host "✅ App Service is responding (Status: $($response.StatusCode))" -ForegroundColor Green
    } catch {
        Write-Warning "⚠️ App Service is deployed but not responding yet. This is normal for new deployments."
    }
    
} catch {
    Write-Warning "⚠️ Could not verify App Service deployment: $($_.Exception.Message)"
}

# Summary
Write-Host "" -ForegroundColor White
Write-Host "🎉 Environment Setup Complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "📋 Summary:" -ForegroundColor Cyan
Write-Host "   Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "   App Service: $AppName" -ForegroundColor White
Write-Host "   Location: $Location" -ForegroundColor White
Write-Host "   Deployment Method: Azure Bicep" -ForegroundColor White
if ($appService) {
    Write-Host "   App URL: https://$($appService.defaultHostName)" -ForegroundColor White
}
Write-Host "" -ForegroundColor White

Write-Host "🚀 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Place your ISAPI DLL in the 'deployment' folder" -ForegroundColor White
Write-Host "2. Update the web.config file with your specific settings" -ForegroundColor White
Write-Host "3. Run the deployment script:" -ForegroundColor White
Write-Host "   .\deployment\deploy.ps1 -ResourceGroupName '$ResourceGroupName' -AppServiceName '$AppName'" -ForegroundColor Cyan
Write-Host "" -ForegroundColor White

# Optional: Open Azure Portal
$openPortal = Read-Host "🌐 Would you like to open the Azure Portal to view your resources? (y/N)"
if ($openPortal -eq 'y' -or $openPortal -eq 'Y') {
    $portalUrl = "https://portal.azure.com/#@/resource/subscriptions/$($account.id)/resourceGroups/$ResourceGroupName/overview"
    Start-Process $portalUrl
}

Write-Host "✅ Environment setup completed successfully!" -ForegroundColor Green
