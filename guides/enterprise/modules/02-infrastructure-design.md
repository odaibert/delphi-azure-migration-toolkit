# Azure Infrastructure Architecture

Comprehensive infrastructure design framework for enterprise-grade Delphi ISAPI migration to Azure App Service with Infrastructure as Code implementation.

**⏱️ Implementation Time**: 6-8 hours  
**👥 Team Involvement**: Solution Architects, DevOps Engineers, Security Team  
**📋 Prerequisites**: Completed migration assessment with strategy selection

## Architecture Framework Overview

This module implements [Azure Well-Architected Framework](https://learn.microsoft.com/azure/architecture/framework/) principles for designing scalable, secure, and cost-effective infrastructure using [Azure Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/) Infrastructure as Code.

### Design Deliverables

- **Azure Architecture Diagram** with security and networking design
- **Infrastructure as Code Templates** with Bicep implementation
- **Cost Optimization Strategy** with Azure Cost Management integration
- **Security Architecture** following Azure Security Benchmark
- **Scaling and Performance Strategy** with monitoring implementation

## 🏗️ Azure App Service Architecture Design

### App Service Plan Selection Framework

Select optimal App Service tier based on enterprise requirements:

#### **Production Tier Recommendations**

| Tier | vCPU/RAM | Production Use Case | ISAPI Compatibility | Monthly Cost (East US) |
|------|----------|-------------------|---------------------|------------------------|
| **Basic (B2)** | 2 vCPU, 3.5GB | Small production workloads | ✅ Full Support | ~$70 |
| **Standard (S2)** | 2 vCPU, 3.5GB | Standard production + auto-scale | ✅ Full Support | ~$140 |
| **Premium v3 (P1v3)** | 2 vCPU, 8GB | High-performance production | ✅ Full Support | ~$200 |
| **Premium v3 (P2v3)** | 4 vCPU, 16GB | Enterprise production workloads | ✅ Full Support | ~$400 |

> 📖 **Reference**: [App Service pricing](https://learn.microsoft.com/azure/app-service/overview-hosting-plans)

#### **Enterprise Requirements Matrix**

```powershell
# PowerShell script for Azure App Service tier selection
param(
    [int]$ExpectedDailyRequests,
    [int]$PeakConcurrentUsers,
    [string]$PerformanceRequirement, # "Standard", "High", "Critical"
    [bool]$RequiresAutoScale = $true,
    [bool]$RequiresCustomDomain = $true
)

Write-Host "=== Azure App Service Tier Recommendation ===" -ForegroundColor Green

# Calculate recommendation score
$RequestScore = switch ($ExpectedDailyRequests) {
    {$_ -lt 10000} { 1 }
    {$_ -lt 50000} { 2 }
    {$_ -lt 200000} { 3 }
    default { 4 }
}

$UserScore = switch ($PeakConcurrentUsers) {
    {$_ -lt 50} { 1 }
    {$_ -lt 200} { 2 }
    {$_ -lt 500} { 3 }
    default { 4 }
}

$PerformanceScore = switch ($PerformanceRequirement) {
    "Standard" { 1 }
    "High" { 2 }
    "Critical" { 3 }
}

$TotalScore = $RequestScore + $UserScore + $PerformanceScore

# Tier recommendation logic
$RecommendedTier = switch ($TotalScore) {
    {$_ -le 4} { 
        if ($RequiresAutoScale) { "Standard S1" } else { "Basic B2" }
    }
    {$_ -le 6} { "Standard S2" }
    {$_ -le 8} { "Premium P1v3" }
    default { "Premium P2v3" }
}

Write-Host "Recommended App Service Tier: $RecommendedTier" -ForegroundColor Yellow
Write-Host "Auto-scaling requirement: $RequiresAutoScale" -ForegroundColor Cyan
```

## 🗄️ Database Architecture Design

### Azure SQL Database Configuration

Design database tier aligned with current SQL Server performance:

#### **DTU vs vCore Selection Framework**

**DTU Model (Recommended for ISAPI migrations)**
- **Simple pricing**: Predictable monthly costs
- **Good for**: Stable ISAPI workloads with consistent database usage
- **Cost range**: $15-$400/month for typical ISAPI applications

**vCore Model (For complex scenarios)**
- **Flexible scaling**: Independent compute and storage scaling
- **Good for**: Variable workloads, specific compliance requirements
- **Cost range**: $50-$800/month with Azure Hybrid Benefit

#### **Database Sizing Assessment**

```sql
-- SQL Server assessment script for Azure SQL Database sizing
-- Run on current SQL Server instance

-- Database size and growth analysis
SELECT 
    DB_NAME() as DatabaseName,
    CAST(SUM(size * 8.0 / 1024) as DECIMAL(10,2)) as CurrentSizeMB,
    CAST(SUM(CASE WHEN type = 0 THEN size * 8.0 / 1024 END) as DECIMAL(10,2)) as DataSizeMB,
    CAST(SUM(CASE WHEN type = 1 THEN size * 8.0 / 1024 END) as DECIMAL(10,2)) as LogSizeMB,
    CAST(SUM(max_size * 8.0 / 1024) as DECIMAL(10,2)) as MaxSizeMB
FROM sys.database_files;

-- Performance counter analysis
SELECT 
    counter_name,
    cntr_value,
    GETDATE() as sample_time
FROM sys.dm_os_performance_counters 
WHERE counter_name IN (
    'Transactions/sec',
    'Batch Requests/sec', 
    'SQL Compilations/sec',
    'Page life expectancy'
);

-- Connection and session analysis
SELECT 
    COUNT(*) as active_connections,
    AVG(DATEDIFF(second, login_time, GETDATE())) as avg_session_duration_sec,
    MAX(DATEDIFF(second, login_time, GETDATE())) as max_session_duration_sec
FROM sys.dm_exec_sessions 
WHERE is_user_process = 1 AND status = 'running';
```

### Storage Architecture Strategy

Design cloud storage strategy for ISAPI file operations:

#### **Azure Storage Service Selection**

| Service | ISAPI Use Case | Performance Tier | Monthly Cost (1TB) |
|---------|----------------|------------------|-------------------|
| **Blob Storage** | File uploads, document storage | Hot: Fast access | $18-24 |
| **Azure Files** | Shared application files | Premium: High IOPS | $200+ |
| **App Service Storage** | Application binaries, logs | Standard: Included | $0 |

> 📖 **Reference**: [Azure Storage pricing](https://learn.microsoft.com/azure/storage/common/storage-introduction)
public class AzureFileManager 
{
    private readonly BlobServiceClient _blobClient;
    private readonly string _containerName;
    
    public AzureFileManager(string connectionString, string containerName)
    {
        _blobClient = new BlobServiceClient(connectionString);
        _containerName = containerName;
    }
    
    // Replace local file save operations
    public async Task<string> SaveFileAsync(byte[] fileData, string fileName)
    {
        var containerClient = _blobClient.GetBlobContainerClient(_containerName);
        var blobClient = containerClient.GetBlobClient(fileName);
        
        using var stream = new MemoryStream(fileData);
        await blobClient.UploadAsync(stream, overwrite: true);
        
        return blobClient.Uri.ToString();
    }
    
    // Replace local file read operations
    public async Task<byte[]> ReadFileAsync(string fileName)
    {
        var containerClient = _blobClient.GetBlobContainerClient(_containerName);
        var blobClient = containerClient.GetBlobClient(fileName);
        
        var response = await blobClient.DownloadContentAsync();
        return response.Value.Content.ToArray();
    }
}
```

## 🏗️ Infrastructure as Code (Bicep)

### 2.5 Comprehensive Bicep Template

Let me enhance the existing Bicep template with detailed configurations:

```bicep
## 🏗️ Infrastructure as Code Implementation

### Bicep Template Architecture

Complete enterprise-grade infrastructure deployment using Azure Bicep:

```bicep
// main.bicep - Enterprise ISAPI infrastructure template
@description('Application name used for resource naming')
@minLength(3)
@maxLength(10)
param applicationName string

@description('Environment designation')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'prod'

@description('Azure region for resource deployment')
param location string = resourceGroup().location

@description('App Service Plan SKU for production workloads')
@allowed(['B2', 'S1', 'S2', 'P1v3', 'P2v3'])
param appServicePlanSku string = 'S2'

@description('Azure SQL Database service tier')
@allowed(['Basic', 'Standard', 'Premium'])
param sqlDatabaseTier string = 'Standard'

@description('Database administrator username')
@secure()
param sqlAdminUsername string

@description('Database administrator password')
@secure()
param sqlAdminPassword string

@description('Enable Application Insights monitoring')
param enableMonitoring bool = true

@description('Enable Azure Storage for file operations')
param enableBlobStorage bool = true

// Variable definitions
var resourceNamePrefix = '${applicationName}-${environment}'
var sqlServerName = '${resourceNamePrefix}-sqlserver'
var databaseName = '${applicationName}db'

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: '${resourceNamePrefix}-plan'
  location: location
  sku: {
    name: appServicePlanSku
    tier: startsWith(appServicePlanSku, 'B') ? 'Basic' : 
          startsWith(appServicePlanSku, 'S') ? 'Standard' : 'PremiumV3'
    capacity: 1
  }
  kind: 'app'
  properties: {
    reserved: false // Windows required for ISAPI
    perSiteScaling: false
    elasticScaleEnabled: false
    maximumElasticWorkerCount: 1
    isSpot: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
  }
  tags: {
    Environment: environment
    Application: applicationName
    ManagedBy: 'Bicep'
  }
}

// App Service for ISAPI hosting
resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: '${resourceNamePrefix}-app'
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      netFrameworkVersion: 'v4.8'
      defaultDocuments: [
        'index.html'
        'default.aspx'
      ]
      httpLoggingEnabled: true
      logsDirectorySizeLimit: 35
      detailedErrorLoggingEnabled: true
      publishingUsername: '$${resourceNamePrefix}-app'
      scmType: 'None'
      use32BitWorkerProcess: false
      webSocketsEnabled: false
      alwaysOn: contains(appServicePlanSku, 'B') ? false : true
      managedPipelineMode: 'Integrated'
      virtualApplications: [
        {
          virtualPath: '/'
          physicalPath: 'site\\wwwroot'
          preloadEnabled: false
        }
      ]
      loadBalancing: 'LeastRequests'
      experiments: {
        rampUpRules: []
      }
      autoHealEnabled: false
      localMySqlEnabled: false
      ipSecurityRestrictions: [
        {
          ipAddress: 'Any'
          action: 'Allow'
          priority: 1
          name: 'Allow all'
          description: 'Allow all access'
        }
      ]
      scmIpSecurityRestrictions: [
        {
          ipAddress: 'Any'
          action: 'Allow'
          priority: 1
          name: 'Allow all'
          description: 'Allow all access'
        }
      ]
      scmIpSecurityRestrictionsUseMain: false
      http20Enabled: false
      minTlsVersion: '1.2'
      ftpsState: 'FtpsOnly'
    }
    httpsOnly: true
    redundancyMode: 'None'
    storageAccountRequired: false
    keyVaultReferenceIdentity: 'SystemAssigned'
  }
  identity: {
    type: 'SystemAssigned'
  }
  tags: {
    Environment: environment
    Application: applicationName
    ManagedBy: 'Bicep'
  }
}

// Azure SQL Server
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    restrictOutboundNetworkAccess: 'Disabled'
  }
  tags: {
    Environment: environment
    Application: applicationName
    ManagedBy: 'Bicep'
  }
}

// Azure SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: databaseName
  location: location
  sku: {
    name: sqlDatabaseTier == 'Basic' ? 'Basic' : sqlDatabaseTier == 'Standard' ? 'S1' : 'P1'
    tier: sqlDatabaseTier
    capacity: sqlDatabaseTier == 'Basic' ? 5 : sqlDatabaseTier == 'Standard' ? 20 : 125
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: sqlDatabaseTier == 'Basic' ? 2147483648 : 268435456000 // 2GB or 250GB
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: false
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: 'Local'
  }
  tags: {
    Environment: environment
    Application: applicationName
    ManagedBy: 'Bicep'
  }
}

// SQL Server Firewall Rules
resource sqlFirewallRuleAzure 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = if (enableMonitoring) {
  name: '${resourceNamePrefix}-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
    RetentionInDays: 90
    IngestionMode: 'ApplicationInsights'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: {
    Environment: environment
    Application: applicationName
    ManagedBy: 'Bicep'
  }
}

// Storage Account for blob storage
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = if (enableBlobStorage) {
  name: '${applicationName}${environment}storage'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    dnsEndpointType: 'Standard'
    defaultToOAuthAuthentication: false
    publicNetworkAccess: 'Enabled'
    allowCrossTenantReplication: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      requireInfrastructureEncryption: false
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
  tags: {
    Environment: environment
    Application: applicationName
    ManagedBy: 'Bicep'
  }
}

// Blob container for ISAPI file operations
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = if (enableBlobStorage) {
  name: '${storageAccount.name}/default/isapi-files'
  properties: {
    immutableStorageWithVersioning: {
      enabled: false
    }
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  }
}

// App Service Configuration
resource appServiceConfig 'Microsoft.Web/sites/config@2023-01-01' = {
  parent: appService
  name: 'appsettings'
  properties: {
    'ConnectionStrings:DefaultConnection': 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${databaseName};Persist Security Info=False;User ID=${sqlAdminUsername};Password=${sqlAdminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
    'AzureStorage:ConnectionString': enableBlobStorage ? 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net' : ''
    'AzureStorage:ContainerName': 'isapi-files'
    'ApplicationInsights:InstrumentationKey': enableMonitoring ? applicationInsights.properties.InstrumentationKey : ''
    'ApplicationInsights:ConnectionString': enableMonitoring ? applicationInsights.properties.ConnectionString : ''
    'Environment': environment
    'Application:Name': applicationName
    'WEBSITE_TIME_ZONE': 'UTC'
    'WEBSITE_RUN_FROM_PACKAGE': '1'
  }
}

// Outputs for deployment verification
output appServiceName string = appService.name
output appServiceUrl string = 'https://${appService.properties.defaultHostName}'
output sqlServerName string = sqlServer.name
output databaseName string = sqlDatabase.name
output storageAccountName string = enableBlobStorage ? storageAccount.name : ''
output applicationInsightsName string = enableMonitoring ? applicationInsights.name : ''
```
### Deployment Parameters Configuration

Create environment-specific parameter files for consistent deployments:

```json
// parameters-production.json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "applicationName": {
      "value": "isapi-app"
    },
    "environment": {
      "value": "prod"
    },
    "location": {
      "value": "East US"
    },
    "appServicePlanSku": {
      "value": "S2"
    },
    "sqlDatabaseTier": {
      "value": "Standard"
    },
    "sqlAdminUsername": {
      "reference": {
        "keyVault": {
          "id": "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.KeyVault/vaults/{vault-name}"
        },
        "secretName": "sql-admin-username"
      }
    },
    "sqlAdminPassword": {
      "reference": {
        "keyVault": {
          "id": "/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.KeyVault/vaults/{vault-name}"
        },
        "secretName": "sql-admin-password"
      }
    },
    "enableMonitoring": {
      "value": true
    },
    "enableBlobStorage": {
      "value": true
    }
  }
}
```

### PowerShell Deployment Automation

```powershell
# deploy-infrastructure.ps1 - Enterprise deployment script
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory=$false)]
    [string]$TemplateFile = ".\main.bicep",
    
    [Parameter(Mandatory=$false)]
    [string]$ParametersFile = ".\parameters-$Environment.json"
)

Write-Host "=== Azure Infrastructure Deployment ===" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow

# Verify Azure CLI authentication
try {
    $account = az account show --query name -o tsv
    Write-Host "Authenticated as: $account" -ForegroundColor Cyan
} catch {
    Write-Error "Please run 'az login' to authenticate with Azure"
    exit 1
}

# Set active subscription
Write-Host "Setting active subscription..." -ForegroundColor Cyan
az account set --subscription $SubscriptionId

# Create resource group if it doesn't exist
Write-Host "Ensuring resource group exists..." -ForegroundColor Cyan
az group create --name $ResourceGroupName --location $Location

# Validate Bicep template
Write-Host "Validating Bicep template..." -ForegroundColor Cyan
$validationResult = az deployment group validate `
    --resource-group $ResourceGroupName `
    --template-file $TemplateFile `
    --parameters $ParametersFile `
    --query "error" -o tsv

if ($validationResult) {
    Write-Error "Template validation failed: $validationResult"
    exit 1
}
Write-Host "✅ Template validation successful" -ForegroundColor Green

# Deploy infrastructure
Write-Host "Deploying infrastructure..." -ForegroundColor Cyan
$deploymentName = "isapi-infrastructure-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

$deploymentResult = az deployment group create `
    --resource-group $ResourceGroupName `
    --name $deploymentName `
    --template-file $TemplateFile `
    --parameters $ParametersFile `
    --query "properties.provisioningState" -o tsv

if ($deploymentResult -eq "Succeeded") {
    Write-Host "✅ Infrastructure deployment successful" -ForegroundColor Green
    
    # Get deployment outputs
    Write-Host "Retrieving deployment outputs..." -ForegroundColor Cyan
    $outputs = az deployment group show `
        --resource-group $ResourceGroupName `
        --name $deploymentName `
        --query "properties.outputs" -o json | ConvertFrom-Json
    
    Write-Host "`n=== Deployment Results ===" -ForegroundColor Yellow
    Write-Host "App Service Name: $($outputs.appServiceName.value)" -ForegroundColor White
    Write-Host "App Service URL: $($outputs.appServiceUrl.value)" -ForegroundColor White
    Write-Host "SQL Server: $($outputs.sqlServerName.value)" -ForegroundColor White
    Write-Host "Database: $($outputs.databaseName.value)" -ForegroundColor White
    
    if ($outputs.storageAccountName.value) {
        Write-Host "Storage Account: $($outputs.storageAccountName.value)" -ForegroundColor White
    }
    
    if ($outputs.applicationInsightsName.value) {
        Write-Host "Application Insights: $($outputs.applicationInsightsName.value)" -ForegroundColor White
    }
    
} else {
    Write-Error "Infrastructure deployment failed with state: $deploymentResult"
    
    # Get deployment error details
    $errors = az deployment group show `
        --resource-group $ResourceGroupName `
        --name $deploymentName `
        --query "properties.error" -o json
    
    Write-Host "Deployment errors: $errors" -ForegroundColor Red
    exit 1
}

Write-Host "`n🚀 Infrastructure deployment completed successfully!" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Deploy your ISAPI application" -ForegroundColor White
Write-Host "2. Configure database connection strings" -ForegroundColor White
Write-Host "3. Set up monitoring and alerting" -ForegroundColor White
```
    },
    "sqlDatabaseTier": {
      "value": "Standard"
    },
    "enableApplicationInsights": {
      "value": true
    },
    "enableStorage": {
      "value": true
    }
  }
}
```

## 🔒 Security Architecture

### 2.7 Security Best Practices

Implement security-first design principles:

#### Network Security
```text
🛡️ Network Security Layers:
□ HTTPS-only enforcement
□ TLS 1.2+ minimum version
□ Application Gateway (Premium)
□ VNet integration (Standard+)
□ Private endpoints (Premium)
□ NSG rules for database access
```

#### Identity and Access Management
```text
🔐 IAM Configuration:
□ Managed Identity for App Service
□ Azure Key Vault for secrets
□ RBAC for resource access
□ SQL Database firewall rules
□ Application-level authentication
```

#### Security Implementation Script
```powershell
# Security hardening script
param(
    [string]$ResourceGroupName,
    [string]$AppServiceName,
    [string]$SqlServerName
)

# Enable HTTPS only
az webapp update --resource-group $ResourceGroupName --name $AppServiceName --https-only true

# Set minimum TLS version
az webapp config set --resource-group $ResourceGroupName --name $AppServiceName --min-tls-version 1.2

# Enable managed identity
$identity = az webapp identity assign --resource-group $ResourceGroupName --name $AppServiceName | ConvertFrom-Json

# Configure SQL firewall for Azure services
az sql server firewall-rule create --resource-group $ResourceGroupName --server $SqlServerName --name "AllowAzureServices" --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0

Write-Host "Security hardening completed" -ForegroundColor Green
Write-Host "Managed Identity ID: $($identity.principalId)" -ForegroundColor Yellow
```

## 💰 Cost Optimization

### 2.8 Cost Management Strategies

Optimize costs while maintaining performance:

#### Cost Estimation Template
```text
📊 Monthly Cost Estimation:

Basic Configuration (B2 + Basic SQL):
- App Service Plan B2: ~$35/month
- SQL Database Basic: ~$5/month  
- Storage Account: ~$3/month
- Application Insights: ~$2/month
## 💰 Cost Optimization and Management

### Enterprise Cost Planning Framework

Implement [Azure Cost Management](https://learn.microsoft.com/azure/cost-management-billing/) best practices for ISAPI migration:

#### **Production Cost Estimation**

**Standard Production Configuration**
- **App Service Plan S2**: $140/month (East US)
- **Azure SQL Database S1**: $30/month
- **Storage Account (1TB)**: $18/month
- **Application Insights**: $24/month (5GB retention)
- **Bandwidth**: $8.7/month (estimated)
- **Total Monthly**: ~$220

**Enterprise Production Configuration**
- **App Service Plan P1v3**: $200/month
- **Azure SQL Database S2**: $75/month
- **Storage Account Premium**: $50/month
- **Application Insights**: $50/month (enhanced monitoring)
- **Bandwidth**: $15/month
- **Total Monthly**: ~$390

> 📖 **Reference**: [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator/)

### Cost Optimization Automation

```powershell
# cost-optimization.ps1 - Automated cost analysis and recommendations
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [int]$AnalysisDays = 30
)

Write-Host "=== Azure Cost Optimization Analysis ===" -ForegroundColor Green

# Set context
az account set --subscription $SubscriptionId

# Get resource group cost data
Write-Host "Analyzing costs for last $AnalysisDays days..." -ForegroundColor Cyan

$startDate = (Get-Date).AddDays(-$AnalysisDays).ToString("yyyy-MM-dd")
$endDate = (Get-Date).ToString("yyyy-MM-dd")

# Analyze App Service utilization
Write-Host "`nApp Service Optimization:" -ForegroundColor Yellow

$appServices = az webapp list --resource-group $ResourceGroupName --query "[].{name:name, id:id, sku:appServicePlanId}" -o json | ConvertFrom-Json

foreach ($app in $appServices) {
    Write-Host "  Analyzing: $($app.name)" -ForegroundColor Cyan
    
    # Get CPU metrics
    $cpuMetrics = az monitor metrics list `
        --resource $app.id `
        --metric "CpuPercentage" `
        --start-time $startDate `
        --end-time $endDate `
        --interval PT1H `
        --aggregation Average `
        --query "value[0].timeseries[0].data[].average" -o tsv
    
    if ($cpuMetrics) {
        $avgCpu = ($cpuMetrics | Measure-Object -Average).Average
        Write-Host "    Average CPU: $([math]::Round($avgCpu, 2))%" -ForegroundColor White
        
        if ($avgCpu -lt 20) {
            Write-Host "    ⬇️ RECOMMENDATION: Consider downgrading App Service Plan" -ForegroundColor Yellow
        } elseif ($avgCpu -gt 80) {
            Write-Host "    ⬆️ RECOMMENDATION: Consider upgrading App Service Plan" -ForegroundColor Red
        } else {
            Write-Host "    ✅ Current tier appears optimal" -ForegroundColor Green
        }
    }
}

# Analyze SQL Database utilization
Write-Host "`nSQL Database Optimization:" -ForegroundColor Yellow

$sqlServers = az sql server list --resource-group $ResourceGroupName --query "[].name" -o tsv

foreach ($server in $sqlServers) {
    $databases = az sql db list --resource-group $ResourceGroupName --server $server --query "[?name!='master'].{name:name, sku:currentSku}" -o json | ConvertFrom-Json
    
    foreach ($db in $databases) {
        Write-Host "  Database: $($db.name)" -ForegroundColor Cyan
        Write-Host "    Current SKU: $($db.sku.name)" -ForegroundColor White
        
        # Get DTU usage
        $dtuMetrics = az monitor metrics list `
            --resource "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Sql/servers/$server/databases/$($db.name)" `
            --metric "dtu_consumption_percent" `
            --start-time $startDate `
            --end-time $endDate `
            --interval PT1H `
            --aggregation Average `
            --query "value[0].timeseries[0].data[].average" -o tsv
        
        if ($dtuMetrics) {
            $avgDtu = ($dtuMetrics | Measure-Object -Average).Average
            Write-Host "    Average DTU: $([math]::Round($avgDtu, 2))%" -ForegroundColor White
            
            if ($avgDtu -lt 30) {
                Write-Host "    ⬇️ RECOMMENDATION: Consider downgrading database tier" -ForegroundColor Yellow
            } elseif ($avgDtu -gt 80) {
                Write-Host "    ⬆️ RECOMMENDATION: Consider upgrading database tier" -ForegroundColor Red
            } else {
                Write-Host "    ✅ Current tier appears optimal" -ForegroundColor Green
            }
        }
    }
}

# Generate cost report
Write-Host "`nGenerating cost optimization report..." -ForegroundColor Cyan

$costData = az consumption usage list `
    --start-date $startDate `
    --end-date $endDate `
    --billing-period-name (Get-Date -Format "yyyyMM") `
    --query "[?contains(instanceName, '$ResourceGroupName')]" -o json | ConvertFrom-Json

$totalCost = ($costData | Measure-Object -Property pretaxCost -Sum).Sum

Write-Host "`n=== Cost Summary ===" -ForegroundColor Green
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "Analysis Period: $startDate to $endDate" -ForegroundColor White
Write-Host "Total Cost: $([math]::Round($totalCost, 2)) USD" -ForegroundColor White

Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Review resource utilization recommendations above" -ForegroundColor White
Write-Host "2. Consider Reserved Instances for long-term workloads" -ForegroundColor White
Write-Host "3. Implement Azure Advisor recommendations" -ForegroundColor White
Write-Host "4. Set up cost alerts and budgets" -ForegroundColor White
```

## 📋 Infrastructure Design Checklist

- [ ] **App Service tier** selected based on performance requirements
- [ ] **Azure SQL Database** tier configured for workload demands
- [ ] **Storage strategy** designed for file operations
- [ ] **Security architecture** implemented with TLS 1.2+ and managed identities
- [ ] **Monitoring and logging** configured with Application Insights
- [ ] **Infrastructure as Code** templates created and validated
- [ ] **Cost optimization** strategy implemented with monitoring
- [ ] **Environment-specific** parameters configured for dev/staging/prod
- [ ] **Deployment automation** scripts tested and documented

## 📚 Reference Documentation

- [Azure App Service plans](https://learn.microsoft.com/azure/app-service/overview-hosting-plans)
- [Azure SQL Database purchasing models](https://learn.microsoft.com/azure/azure-sql/database/purchasing-models)
- [Azure Bicep documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure Cost Management best practices](https://learn.microsoft.com/azure/cost-management-billing/costs/cost-mgt-best-practices)

---

## 🚀 Next Steps

With your infrastructure architecture designed and implemented, proceed to **[Module 3: Platform Compliance](03-sandbox-compliance.md)** to ensure your ISAPI application meets Azure App Service sandbox requirements.

### Navigation
- **← Previous**: [Migration Assessment](01-pre-migration-assessment.md)
- **→ Next**: [Platform Compliance](03-sandbox-compliance.md)
- **🔧 Troubleshooting**: [Infrastructure Issues](../../../docs/troubleshooting.md#infrastructure-issues)

### Deliverables
- [ ] **Infrastructure Design**: Bicep templates and parameters
- [ ] **Cost Estimate**: Monthly cost projections
- [ ] **Security Plan**: Security configuration checklist
- [ ] **Sizing Recommendation**: Appropriate tier selection

## 🔄 Next Steps

Proceed to **[Module 3: Azure Sandbox Compliance](03-sandbox-compliance.md)** to ensure your ISAPI filter code is compatible with Azure App Service sandbox restrictions.

---

### 📚 Additional Resources
- [Azure App Service Plans](https://docs.microsoft.com/azure/app-service/overview-hosting-plans)
- [Azure SQL Database Pricing](https://azure.microsoft.com/pricing/details/sql-database/)
- [Azure Bicep Documentation](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure Cost Management](https://docs.microsoft.com/azure/cost-management-billing/)
