# Production Deployment Automation (Optional)

Advanced CI/CD pipeline implementation for enterprise-grade Delphi ISAPI deployment automation with Infrastructure as Code and continuous delivery practices.

**⏱️ Implementation Time**: 6-8 hours  
**👥 Team Involvement**: DevOps Engineers, Release Managers, Developers  
**📋 Prerequisites**: Infrastructure design completed, source code in version control  
**🔄 Module Status**: **Optional** - Skip if existing CI/CD processes are in place

> 📝 **Optional Module Notice**: This module provides advanced deployment automation. Organizations with existing CI/CD pipelines can proceed directly to [Module 6: Testing and Validation](06-testing-validation.md).

## Automation Framework Overview

This module implements [Azure DevOps best practices](https://learn.microsoft.com/azure/devops/pipelines/) and [GitHub Actions workflows](https://learn.microsoft.com/azure/developer/github/github-actions) for automated ISAPI application deployment.

### Automation Deliverables

- **CI/CD Pipeline Templates** for Azure DevOps and GitHub Actions
- **Infrastructure as Code Automation** with Bicep deployment pipelines
- **Configuration Management** with environment-specific parameters
- **Blue-Green Deployment Strategy** for zero-downtime releases
- **Rollback Procedures** with automated recovery mechanisms

## 🚀 CI/CD Pipeline Architecture

### Pipeline Strategy Selection

Choose the appropriate automation platform for your organization:

#### **Azure DevOps Pipelines** (Recommended for Microsoft ecosystems)
- **Integration**: Native Azure resource management
- **Security**: Azure AD integration and service principals
- **Monitoring**: Built-in Azure Monitor integration
- **Cost**: Free tier available, enterprise licensing

#### **GitHub Actions** (Recommended for open-source or GitHub-centric workflows)
- **Integration**: Excellent for GitHub repositories
- **Security**: OIDC authentication with Azure
- **Flexibility**: Large marketplace of actions
- **Cost**: Free for public repositories, usage-based pricing

> 📖 **Reference**: [Choose between Azure DevOps and GitHub](https://learn.microsoft.com/azure/devops/user-guide/alm-devops-features)

## 🔧 Azure DevOps Implementation

### Azure DevOps Pipeline Configuration

```yaml
# azure-pipelines.yml - Enterprise ISAPI deployment pipeline
trigger:
  branches:
    include:
    - main
    - develop
  paths:
    include:
    - src/*
    - infrastructure/*

variables:
  - group: 'isapi-app-variables'
  - name: buildConfiguration
    value: 'Release'
  - name: azureSubscription
    value: 'Azure-Production-Connection'

stages:
- stage: Build
  displayName: 'Build and Test'
  jobs:
  - job: BuildISAPI
    displayName: 'Build ISAPI Application'
    pool:
      vmImage: 'windows-latest'
    
    steps:
    - checkout: self
      fetchDepth: 1
    
    - task: VSBuild@1
      displayName: 'Build ISAPI Project'
      inputs:
        solution: 'src/*.dproj'
        msbuildArgs: '/p:Configuration=$(buildConfiguration) /p:Platform="Win32"'
        configuration: $(buildConfiguration)
        maximumCpuCount: true
    
    - task: CopyFiles@2
      displayName: 'Copy Build Artifacts'
      inputs:
        SourceFolder: 'src/Win32/Release'
        Contents: |
          *.dll
          *.exe
          web.config
        TargetFolder: '$(Build.ArtifactStagingDirectory)/app'
    
    - task: CopyFiles@2
      displayName: 'Copy Infrastructure Templates'
      inputs:
        SourceFolder: 'infrastructure'
        Contents: |
          *.bicep
          *.json
          *.ps1
        TargetFolder: '$(Build.ArtifactStagingDirectory)/infrastructure'
    
    - task: PublishBuildArtifacts@1
      displayName: 'Publish Build Artifacts'
      inputs:
        PathtoPublish: '$(Build.ArtifactStagingDirectory)'
        ArtifactName: 'isapi-application'

- stage: ValidateInfrastructure
  displayName: 'Validate Infrastructure'
  dependsOn: Build
  condition: succeeded()
  jobs:
  - job: ValidateBicep
    displayName: 'Validate Bicep Templates'
    pool:
      vmImage: 'ubuntu-latest'
    
    steps:
    - download: current
      artifact: isapi-application
    
    - task: AzureCLI@2
      displayName: 'Validate Bicep Template'
      inputs:
        azureSubscription: $(azureSubscription)
        scriptType: 'bash'
        scriptLocation: 'inlineScript'
        inlineScript: |
          az deployment group validate \
            --resource-group $(resourceGroupName) \
            --template-file $(Pipeline.Workspace)/isapi-application/infrastructure/main.bicep \
            --parameters $(Pipeline.Workspace)/isapi-application/infrastructure/parameters-$(environment).json

- stage: DeployDevelopment
  displayName: 'Deploy to Development'
  dependsOn: ValidateInfrastructure
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/develop'))
  variables:
    environment: 'dev'
    resourceGroupName: 'rg-isapi-dev'
  jobs:
  - deployment: DeployInfrastructure
    displayName: 'Deploy Infrastructure'
    environment: 'development'
    pool:
      vmImage: 'ubuntu-latest'
    strategy:
      runOnce:
        deploy:
          steps:
          - download: current
            artifact: isapi-application
          
          - task: AzureCLI@2
            displayName: 'Deploy Infrastructure'
            inputs:
              azureSubscription: $(azureSubscription)
              scriptType: 'bash'
              scriptLocation: 'inlineScript'
              inlineScript: |
                az deployment group create \
                  --resource-group $(resourceGroupName) \
                  --template-file $(Pipeline.Workspace)/isapi-application/infrastructure/main.bicep \
                  --parameters $(Pipeline.Workspace)/isapi-application/infrastructure/parameters-$(environment).json \
                  --name "infrastructure-$(Build.BuildNumber)"
          
          - task: AzureWebApp@1
            displayName: 'Deploy ISAPI Application'
            inputs:
              azureSubscription: $(azureSubscription)
              appType: 'webApp'
              appName: '$(appServiceName)'
              package: '$(Pipeline.Workspace)/isapi-application/app'
              deploymentMethod: 'zipDeploy'

- stage: DeployProduction
  displayName: 'Deploy to Production'
  dependsOn: ValidateInfrastructure
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  variables:
    environment: 'prod'
    resourceGroupName: 'rg-isapi-prod'
  jobs:
  - deployment: DeployProduction
    displayName: 'Production Deployment'
    environment: 'production'
    pool:
      vmImage: 'ubuntu-latest'
    strategy:
      runOnce:
        deploy:
          steps:
          - download: current
            artifact: isapi-application
          
          - task: AzureCLI@2
            displayName: 'Deploy Infrastructure'
            inputs:
              azureSubscription: $(azureSubscription)
              scriptType: 'bash'
              scriptLocation: 'inlineScript'
              inlineScript: |
                az deployment group create \
                  --resource-group $(resourceGroupName) \
                  --template-file $(Pipeline.Workspace)/isapi-application/infrastructure/main.bicep \
                  --parameters $(Pipeline.Workspace)/isapi-application/infrastructure/parameters-$(environment).json \
                  --name "infrastructure-$(Build.BuildNumber)"
          
          - task: AzureAppServiceManage@0
            displayName: 'Create Deployment Slot'
            inputs:
              azureSubscription: $(azureSubscription)
              action: 'Create or Update Slot'
              webAppName: '$(appServiceName)'
              resourceGroupName: '$(resourceGroupName)'
              slotName: 'staging'
          
          - task: AzureWebApp@1
            displayName: 'Deploy to Staging Slot'
            inputs:
              azureSubscription: $(azureSubscription)
              appType: 'webAppLinux'
              appName: '$(appServiceName)'
              slotName: 'staging'
              package: '$(Pipeline.Workspace)/isapi-application/app'
              deploymentMethod: 'zipDeploy'
          
          - task: AzureAppServiceManage@0
            displayName: 'Swap Staging to Production'
            inputs:
              azureSubscription: $(azureSubscription)
              action: 'Swap Slots'
              webAppName: '$(appServiceName)'
              resourceGroupName: '$(resourceGroupName)'
              sourceSlot: 'staging'
              targetSlot: 'production'
```

## 🐙 GitHub Actions Implementation

### GitHub Actions Workflow

```yaml
# .github/workflows/deploy-isapi.yml
name: Deploy ISAPI to Azure App Service

on:
  push:
    branches: [ main, develop ]
    paths:
      - 'src/**'
      - 'infrastructure/**'
  pull_request:
    branches: [ main ]
    paths:
      - 'src/**'
      - 'infrastructure/**'

env:
  AZURE_WEBAPP_NAME: 'isapi-app-prod'
  AZURE_WEBAPP_PACKAGE_PATH: './src'
  BUILD_CONFIGURATION: 'Release'

permissions:
  id-token: write
  contents: read

jobs:
  build:
    runs-on: windows-latest
    outputs:
      app-artifact: ${{ steps.upload-artifact.outputs.artifact-id }}
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup MSBuild
      uses: microsoft/setup-msbuild@v1
    
    - name: Setup NuGet
      uses: NuGet/setup-nuget@v1
    
    - name: Restore NuGet packages
      run: nuget restore src/*.sln
    
    - name: Build ISAPI Application
      run: |
        msbuild src/*.dproj /p:Configuration=${{ env.BUILD_CONFIGURATION }} /p:Platform=Win32
    
    - name: Upload build artifacts
      id: upload-artifact
      uses: actions/upload-artifact@v4
      with:
        name: isapi-application
        path: |
          src/Win32/Release/*.dll
          src/Win32/Release/*.exe
          src/web.config
          infrastructure/

  validate-infrastructure:
    runs-on: ubuntu-latest
    needs: build
    
    steps:
    - name: Download artifacts
      uses: actions/download-artifact@v4
      with:
        name: isapi-application
    
    - name: Azure Login
      uses: azure/login@v1
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    
    - name: Validate Bicep template
      run: |
        az deployment group validate \
          --resource-group ${{ vars.AZURE_RG_NAME }} \
          --template-file infrastructure/main.bicep \
          --parameters infrastructure/parameters-prod.json

  deploy-development:
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    needs: [build, validate-infrastructure]
    environment: development
    
    steps:
    - name: Download artifacts
      uses: actions/download-artifact@v4
      with:
        name: isapi-application
    
    - name: Azure Login
      uses: azure/login@v1
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    
    - name: Deploy Infrastructure
      run: |
        az deployment group create \
          --resource-group ${{ vars.AZURE_RG_DEV }} \
          --template-file infrastructure/main.bicep \
          --parameters infrastructure/parameters-dev.json \
          --name "infrastructure-${{ github.run_number }}"
    
    - name: Deploy Application
      uses: azure/webapps-deploy@v2
      with:
        app-name: ${{ vars.AZURE_WEBAPP_NAME_DEV }}
        package: './src/Win32/Release'

  deploy-production:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    needs: [build, validate-infrastructure]
    environment: production
    
    steps:
    - name: Download artifacts
      uses: actions/download-artifact@v4
      with:
        name: isapi-application
    
    - name: Azure Login
      uses: azure/login@v1
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    
    - name: Deploy Infrastructure
      run: |
        az deployment group create \
          --resource-group ${{ vars.AZURE_RG_PROD }} \
          --template-file infrastructure/main.bicep \
          --parameters infrastructure/parameters-prod.json \
          --name "infrastructure-${{ github.run_number }}"
    
    - name: Deploy to Staging Slot
      uses: azure/webapps-deploy@v2
      with:
        app-name: ${{ vars.AZURE_WEBAPP_NAME }}
        slot-name: 'staging'
        package: './src/Win32/Release'
    
    - name: Swap to Production
      run: |
        az webapp deployment slot swap \
          --resource-group ${{ vars.AZURE_RG_PROD }} \
          --name ${{ vars.AZURE_WEBAPP_NAME }} \
          --slot staging \
          --target-slot production
```

## 🔄 Blue-Green Deployment Strategy

### PowerShell Blue-Green Deployment Script

```powershell
# blue-green-deployment.ps1 - Zero-downtime deployment automation
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$AppServiceName,
    
    [Parameter(Mandatory=$true)]
    [string]$ArtifactPath,
    
    [Parameter(Mandatory=$false)]
    [string]$HealthCheckUrl = "/health",
    
    [Parameter(Mandatory=$false)]
    [int]$HealthCheckTimeoutSeconds = 300,
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoRollback = $true
)

Write-Host "=== Blue-Green Deployment for $AppServiceName ===" -ForegroundColor Green

# Verify current production status
Write-Host "Checking current production status..." -ForegroundColor Cyan
$ProductionUrl = "https://$AppServiceName.azurewebsites.net"

try {
    $ProductionResponse = Invoke-WebRequest -Uri "$ProductionUrl$HealthCheckUrl" -TimeoutSec 30 -UseBasicParsing
    Write-Host "✅ Production is healthy (Status: $($ProductionResponse.StatusCode))" -ForegroundColor Green
} catch {
    Write-Warning "⚠️ Production health check failed: $($_.Exception.Message)"
}

# Create or update staging slot
Write-Host "Preparing staging slot..." -ForegroundColor Cyan
$StagingSlotExists = az webapp deployment slot list --resource-group $ResourceGroupName --name $AppServiceName --query "[?name=='staging']" -o tsv

if (-not $StagingSlotExists) {
    Write-Host "Creating staging slot..." -ForegroundColor Yellow
    az webapp deployment slot create --resource-group $ResourceGroupName --name $AppServiceName --slot staging
} else {
    Write-Host "Staging slot already exists" -ForegroundColor Green
}

# Deploy to staging slot
Write-Host "Deploying to staging slot..." -ForegroundColor Cyan
az webapp deploy --resource-group $ResourceGroupName --name $AppServiceName --slot staging --src-path $ArtifactPath --type zip

if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ Deployment to staging failed"
    exit 1
}

Write-Host "✅ Deployment to staging completed" -ForegroundColor Green

# Health check staging slot
Write-Host "Performing health check on staging..." -ForegroundColor Cyan
$StagingUrl = "https://$AppServiceName-staging.azurewebsites.net"
$HealthCheckPassed = $false
$HealthCheckStartTime = Get-Date

do {
    try {
        $StagingResponse = Invoke-WebRequest -Uri "$StagingUrl$HealthCheckUrl" -TimeoutSec 30 -UseBasicParsing
        if ($StagingResponse.StatusCode -eq 200) {
            Write-Host "✅ Staging health check passed (Status: $($StagingResponse.StatusCode))" -ForegroundColor Green
            $HealthCheckPassed = $true
            break
        }
    } catch {
        Write-Host "⏳ Staging not ready yet: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    Start-Sleep -Seconds 10
    $ElapsedSeconds = (Get-Date) - $HealthCheckStartTime
    
    if ($ElapsedSeconds.TotalSeconds -gt $HealthCheckTimeoutSeconds) {
        Write-Error "❌ Staging health check timeout after $HealthCheckTimeoutSeconds seconds"
        
        if ($AutoRollback) {
            Write-Host "🔄 Auto-rollback enabled, cleaning up staging..." -ForegroundColor Yellow
            # Keep staging for troubleshooting but don't proceed with swap
        }
        exit 1
    }
} while (-not $HealthCheckPassed)

# Perform blue-green swap
Write-Host "Performing blue-green swap..." -ForegroundColor Cyan
$SwapResult = az webapp deployment slot swap --resource-group $ResourceGroupName --name $AppServiceName --slot staging --target-slot production

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Blue-green swap completed successfully" -ForegroundColor Green
    
    # Verify production after swap
    Write-Host "Verifying production after swap..." -ForegroundColor Cyan
    Start-Sleep -Seconds 30  # Allow time for swap to propagate
    
    try {
        $PostSwapResponse = Invoke-WebRequest -Uri "$ProductionUrl$HealthCheckUrl" -TimeoutSec 30 -UseBasicParsing
        Write-Host "✅ Post-swap production verification successful (Status: $($PostSwapResponse.StatusCode))" -ForegroundColor Green
        
        # Log deployment success
        Write-Host "`n🎉 Blue-Green Deployment Completed Successfully!" -ForegroundColor Green
        Write-Host "Production URL: $ProductionUrl" -ForegroundColor White
        Write-Host "Previous version available in staging slot for rollback if needed" -ForegroundColor White
        
    } catch {
        Write-Error "❌ Post-swap production verification failed: $($_.Exception.Message)"
        
        if ($AutoRollback) {
            Write-Host "🔄 Performing automatic rollback..." -ForegroundColor Yellow
            az webapp deployment slot swap --resource-group $ResourceGroupName --name $AppServiceName --slot production --target-slot staging
            Write-Host "✅ Rollback completed" -ForegroundColor Green
        }
        exit 1
    }
} else {
    Write-Error "❌ Blue-green swap failed"
    exit 1
}

Write-Host "`n📋 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Monitor application performance and error rates" -ForegroundColor White
Write-Host "2. Run post-deployment validation tests" -ForegroundColor White
Write-Host "3. Update monitoring dashboards if needed" -ForegroundColor White
Write-Host "4. Clean up staging slot after validation period" -ForegroundColor White
```

## 📋 Deployment Automation Checklist

- [ ] **CI/CD Platform** selected and configured (Azure DevOps or GitHub Actions)
- [ ] **Pipeline Templates** created for build, test, and deployment
- [ ] **Infrastructure Automation** implemented with Bicep validation
- [ ] **Environment Management** configured for dev/staging/production
- [ ] **Blue-Green Deployment** strategy implemented for zero-downtime releases
- [ ] **Health Checks** implemented for automated deployment validation
- [ ] **Rollback Procedures** tested and documented
- [ ] **Security Scanning** integrated into pipeline (optional)
- [ ] **Deployment Notifications** configured for team communication

## 📚 Reference Documentation

- [Azure DevOps Pipelines](https://learn.microsoft.com/azure/devops/pipelines/)
- [GitHub Actions for Azure](https://learn.microsoft.com/azure/developer/github/github-actions)
- [Azure App Service deployment slots](https://learn.microsoft.com/azure/app-service/deploy-staging-slots)
- [Infrastructure as Code best practices](https://learn.microsoft.com/azure/azure-resource-manager/templates/best-practices)

---

## 🚀 Next Steps

With deployment automation implemented, proceed to **[Module 5: Operations and Monitoring](05-advanced-configuration.md)** for advanced operational procedures, or skip to **[Module 6: Testing and Validation](06-testing-validation.md)** if using existing monitoring solutions.

### Navigation
- **← Previous**: [Platform Compliance](03-sandbox-compliance.md)
- **→ Next (Optional)**: [Operations and Monitoring](05-advanced-configuration.md)
- **→ Next (Core Path)**: [Testing and Validation](06-testing-validation.md)
- **🔧 Troubleshooting**: [Deployment Issues](../../../docs/troubleshooting.md#deployment-issues)
