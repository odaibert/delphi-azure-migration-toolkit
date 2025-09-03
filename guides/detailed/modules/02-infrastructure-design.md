# Module 2: Infrastructure Architecture Design

⏱️ **Duration**: 40 minutes  
🎯 **Learning Objectives**: Design optimal Azure infrastructure for ISAPI hosting  
📋 **Prerequisites**: Completed Module 1 assessment  

## Introduction

This module focuses on designing the optimal Azure infrastructure for your Delphi ISAPI filter. We'll explore Azure App Service tiers, networking options, security considerations, and cost optimization strategies using Infrastructure as Code principles.

## 🏗️ Azure App Service Architecture

### 2.1 Understanding App Service Plans

App Service Plans determine the compute resources and features available to your application:

#### Service Tier Comparison
| Tier | CPU/Memory | Use Case | ISAPI Support | Cost/Month* |
|------|------------|----------|---------------|-------------|
| **Free (F1)** | Shared | Development/Testing | ❌ No | $0 |
| **Shared (D1)** | Shared | Basic hosting | ❌ No | ~$10 |
| **Basic (B1-B3)** | Dedicated | Small production | ✅ Yes | $13-52 |
| **Standard (S1-S3)** | Dedicated | Production | ✅ Yes | $70-280 |
| **Premium (P1v3-P3v3)** | High performance | Enterprise | ✅ Yes | $200-800 |

*Approximate costs in East US region

#### ISAPI-Specific Requirements
```text
🎯 Minimum Requirements for ISAPI:
□ Basic (B1) or higher tier required
□ Windows operating system (not Linux)
□ .NET Framework runtime support
□ Custom domain support (Standard+)
□ SSL/TLS certificates (Basic+)
□ Auto-scaling (Standard+)
```

### 2.2 Sizing Recommendations

Choose the appropriate tier based on your assessment:

```powershell
# Azure App Service Sizing Calculator
param(
    [int]$ExpectedDailyRequests,
    [int]$PeakConcurrentUsers,
    [string]$ComplexityLevel # "Low", "Medium", "High"
)

function Get-RecommendedTier {
    param($Requests, $Users, $Complexity)
    
    $score = 0
    
    # Request volume scoring
    if ($Requests -lt 1000) { $score += 1 }
    elseif ($Requests -lt 10000) { $score += 2 }
    elseif ($Requests -lt 100000) { $score += 3 }
    else { $score += 4 }
    
    # Concurrent users scoring
    if ($Users -lt 10) { $score += 1 }
    elseif ($Users -lt 50) { $score += 2 }
    elseif ($Users -lt 200) { $score += 3 }
    else { $score += 4 }
    
    # Complexity scoring
    switch ($Complexity) {
        "Low" { $score += 1 }
        "Medium" { $score += 2 }
        "High" { $score += 3 }
    }
    
    # Recommendation logic
    switch ($score) {
        {$_ -le 4} { return "Basic B1" }
        {$_ -le 6} { return "Basic B2" }
        {$_ -le 8} { return "Standard S1" }
        {$_ -le 10} { return "Standard S2" }
        default { return "Premium P1v3" }
    }
}

# Example usage
$recommendation = Get-RecommendedTier -Requests 5000 -Users 25 -Complexity "Medium"
Write-Host "Recommended Tier: $recommendation" -ForegroundColor Green
```

## 🗄️ Database Architecture

### 2.3 Azure SQL Database Design

Design your database tier based on current SQL Server usage:

#### DTU vs vCore Model Comparison
```text
🏛️ DTU Model (Database Transaction Units):
✅ Pros: Simple, predictable pricing
❌ Cons: Less control over resources
💰 Cost: $5-3000/month
🎯 Best for: Stable, predictable workloads

⚙️ vCore Model (Virtual Cores):
✅ Pros: Granular control, hybrid benefits
❌ Cons: More complex pricing
💰 Cost: $30-5000/month
🎯 Best for: Variable workloads, specific requirements
```

#### Database Sizing Script
```sql
-- Run this on your current SQL Server to assess sizing needs
-- Database size analysis
SELECT 
    DB_NAME() as DatabaseName,
    SUM(size * 8.0 / 1024) as SizeMB,
    SUM(CASE WHEN type = 0 THEN size * 8.0 / 1024 END) as DataSizeMB,
    SUM(CASE WHEN type = 1 THEN size * 8.0 / 1024 END) as LogSizeMB
FROM sys.database_files;

-- Transaction log analysis (run for 24 hours)
SELECT 
    GETDATE() as SampleTime,
    cntr_value as LogKBUsed
FROM sys.dm_os_performance_counters 
WHERE counter_name = 'Log File(s) Used Size (KB)';

-- Connection analysis
SELECT 
    COUNT(*) as ActiveConnections,
    MAX(login_time) as LastLogin,
    MIN(login_time) as FirstLogin
FROM sys.dm_exec_sessions 
WHERE is_user_process = 1;
```

### 2.4 Storage Architecture

Design storage strategy for file operations:

#### Azure Storage Options
| Storage Type | Use Case | Performance | Cost |
|--------------|----------|-------------|------|
| **Blob Storage** | File uploads, documents | Standard/Premium | $0.018/GB |
| **Azure Files** | Shared file access | Standard/Premium | $0.06/GB |
| **App Service Files** | Application files | Standard | Included |

#### Storage Implementation Pattern
```csharp
// Example: Migrating file operations to Azure Blob Storage
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
// Enhanced main.bicep template
@description('Application name prefix')
param appName string = 'delphi-isapi'

@description('Environment (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('App Service Plan SKU')
@allowed(['B1', 'B2', 'B3', 'S1', 'S2', 'S3', 'P1v3', 'P2v3', 'P3v3'])
param appServicePlanSku string = 'B2'

@description('Azure SQL Database tier')
@allowed(['Basic', 'Standard', 'Premium'])
param sqlDatabaseTier string = 'Standard'

@description('Enable Application Insights')
param enableApplicationInsights bool = true

@description('Enable Azure Storage')
param enableStorage bool = true

var resourcePrefix = '${appName}-${environment}'
var location = resourceGroup().location

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: '${resourcePrefix}-plan'
  location: location
  sku: {
    name: appServicePlanSku
    tier: contains(appServicePlanSku, 'B') ? 'Basic' : contains(appServicePlanSku, 'S') ? 'Standard' : 'PremiumV3'
  }
  kind: 'app'
  properties: {
    reserved: false // Windows
    targetWorkerCount: 1
    targetWorkerSizeId: 0
  }
}

// App Service
resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: '${resourcePrefix}-app'
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
      detailedErrorLoggingEnabled: true
      requestTracingEnabled: true
      // ISAPI specific configuration
      virtualApplications: [
        {
          virtualPath: '/'
          physicalPath: 'site\\wwwroot'
          preloadEnabled: true
        }
      ]
    }
    httpsOnly: true
    clientAffinityEnabled: false
  }
}

// SQL Server
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: '${resourcePrefix}-sql'
  location: location
  properties: {
    administratorLogin: 'sqladmin'
    administratorLoginPassword: 'P@ssw0rd123!' // Use Key Vault in production
    version: '12.0'
    publicNetworkAccess: 'Enabled'
  }
}

// SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: '${resourcePrefix}-db'
  location: location
  sku: {
    name: sqlDatabaseTier == 'Basic' ? 'Basic' : sqlDatabaseTier == 'Standard' ? 'S1' : 'P1'
    tier: sqlDatabaseTier
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: sqlDatabaseTier == 'Basic' ? 2147483648 : 268435456000 // 2GB or 250GB
  }
}

// Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = if (enableApplicationInsights) {
  name: '${resourcePrefix}-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = if (enableApplicationInsights) {
  name: '${resourcePrefix}-logs'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = if (enableStorage) {
  name: replace('${resourcePrefix}storage', '-', '')
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

// App Service Configuration
resource appServiceConfig 'Microsoft.Web/sites/config@2023-01-01' = {
  parent: appService
  name: 'appsettings'
  properties: {
    APPINSIGHTS_INSTRUMENTATIONKEY: enableApplicationInsights ? applicationInsights.properties.InstrumentationKey : ''
    APPLICATIONINSIGHTS_CONNECTION_STRING: enableApplicationInsights ? applicationInsights.properties.ConnectionString : ''
    AzureStorageConnectionString: enableStorage ? 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value}' : ''
    DatabaseConnectionString: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDatabase.name};Persist Security Info=False;User ID=${sqlServer.properties.administratorLogin};Password=${sqlServer.properties.administratorLoginPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
  }
}

// Outputs
output appServiceUrl string = 'https://${appService.properties.defaultHostName}'
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output storageAccountName string = enableStorage ? storageAccount.name : ''
output applicationInsightsInstrumentationKey string = enableApplicationInsights ? applicationInsights.properties.InstrumentationKey : ''
```

### 2.6 Environment-Specific Parameters

Create parameter files for different environments:

#### parameters-dev.json
```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "appName": {
      "value": "delphi-isapi"
    },
    "environment": {
      "value": "dev"
    },
    "appServicePlanSku": {
      "value": "B1"
    },
    "sqlDatabaseTier": {
      "value": "Basic"
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

#### parameters-prod.json
```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "appName": {
      "value": "delphi-isapi"
    },
    "environment": {
      "value": "prod"
    },
    "appServicePlanSku": {
      "value": "S2"
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
Total: ~$45/month

Standard Configuration (S1 + Standard SQL):
- App Service Plan S1: ~$70/month
- SQL Database S1: ~$30/month
- Storage Account: ~$5/month
- Application Insights: ~$5/month
Total: ~$110/month

Premium Configuration (P1v3 + Premium SQL):
- App Service Plan P1v3: ~$200/month
- SQL Database P1: ~$465/month
- Storage Account: ~$10/month
- Application Insights: ~$10/month
Total: ~$685/month
```

#### Cost Optimization Script
```powershell
# Cost optimization analysis
function Get-AzureCostOptimization {
    param(
        [string]$SubscriptionId,
        [string]$ResourceGroupName
    )
    
    # Get current costs
    $costs = az consumption usage list --billing-period-name $(Get-Date -Format "yyyyMM") | ConvertFrom-Json
    $rgCosts = $costs | Where-Object { $_.instanceName -like "*$ResourceGroupName*" }
    
    # Recommendations
    Write-Host "=== Cost Optimization Recommendations ===" -ForegroundColor Green
    
    # App Service recommendations
    $appServices = az webapp list --resource-group $ResourceGroupName | ConvertFrom-Json
    foreach ($app in $appServices) {
        $metrics = az monitor metrics list --resource $app.id --metric "CpuPercentage" --interval PT1H --start-time (Get-Date).AddDays(-7) | ConvertFrom-Json
        $avgCpu = ($metrics.value.timeseries.data | Measure-Object average -Average).Average
        
        if ($avgCpu -lt 30) {
            Write-Host "⬇️ App Service $($app.name): Consider downgrading tier (CPU: $([math]::Round($avgCpu, 2))%)" -ForegroundColor Yellow
        }
    }
    
    # SQL Database recommendations
    $sqlDatabases = az sql db list --resource-group $ResourceGroupName --server $SqlServerName | ConvertFrom-Json
    foreach ($db in $sqlDatabases) {
        Write-Host "📊 SQL Database $($db.name): Review DTU usage patterns" -ForegroundColor Blue
    }
}
```

## ✅ Module 2 Completion

### Knowledge Check
- [ ] I understand App Service tier requirements for ISAPI
- [ ] I've designed the database architecture
- [ ] I've created environment-specific Bicep templates
- [ ] I understand security best practices
- [ ] I've estimated costs for different configurations

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
