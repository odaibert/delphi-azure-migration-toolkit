@description('Main Bicep template for ISAPI filter migration to Azure App Service')
@minLength(2)
@maxLength(60)
param appName string = 'isapi-migration-${uniqueString(resourceGroup().id)}'

@description('Location for all resources')
param location string = resourceGroup().location

@description('App Service Plan SKU')
@allowed([
  'F1'
  'D1'
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1'
  'P2'
  'P3'
  'P1v2'
  'P2v2'
  'P3v2'
])
param appServicePlanSku string = 'S1'

@description('Enable Application Insights')
param enableApplicationInsights bool = true

@description('Enable Managed Identity for secure Azure resource access')
param enableManagedIdentity bool = true

@description('Enable Azure SQL Database deployment')
param enableAzureSQL bool = false

@description('Azure SQL Database administrator login')
param sqlAdminLogin string = 'isapiadmin'

@description('Azure SQL Database administrator password')
@secure()
param sqlAdminPassword string = ''

@description('Enable Key Vault for secrets management')
param enableKeyVault bool = true

@description('Enable Azure Files for shared folder replacement')
param enableAzureFiles bool = true

// Variables
var appServicePlanName = 'asp-${appName}'
var storageAccountName = 'st${replace(appName, '-', '')}${substring(uniqueString(resourceGroup().id), 0, 4)}'
var applicationInsightsName = 'ai-${appName}'
var keyVaultName = 'kv-${replace(appName, '-', '')}${substring(uniqueString(resourceGroup().id), 0, 4)}'
var sqlServerName = 'sql-${appName}'
var sqlDatabaseName = '${appName}-db'
var fileShareName = 'isapi-shared-folder'

// Storage Account for shared folder replacement
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = if (enableAzureFiles) {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

// File Share for legacy shared folder
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = if (enableAzureFiles) {
  name: '${storageAccount.name}/default/${fileShareName}'
  properties: {
    shareQuota: 100 // 100 GB quota
  }
}

// Key Vault for secrets management
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = if (enableKeyVault) {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: []
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: false
    enableRbacAuthorization: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

// Azure SQL Server
resource sqlServer 'Microsoft.Sql/servers@2023-02-01-preview' = if (enableAzureSQL) {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    publicNetworkAccess: 'Enabled'
  }
}

// Azure SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-02-01-preview' = if (enableAzureSQL) {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648 // 2GB
  }
}

// SQL Server Firewall Rule for Azure Services
resource sqlFirewallRule 'Microsoft.Sql/servers/firewallRules@2023-02-01-preview' = if (enableAzureSQL) {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = if (enableApplicationInsights) {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: appServicePlanSku
    capacity: 1
  }
  kind: 'app'
  properties: {}
}

// App Service
resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: appName
  location: location
  identity: enableManagedIdentity ? {
    type: 'SystemAssigned'
  } : null
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      netFrameworkVersion: 'v4.8'
      use32BitWorkerProcess: false // Force 64-bit for ISAPI compatibility
      defaultDocuments: [
        'default.htm'
        'default.html'
        'default.asp'
        'index.html'
        'iisstart.htm'
      ]
      httpLoggingEnabled: true
      logsDirectorySizeLimit: 35
      requestTracingEnabled: true
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: enableApplicationInsights && applicationInsights != null ? applicationInsights.properties.InstrumentationKey : ''
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: enableApplicationInsights && applicationInsights != null ? applicationInsights.properties.ConnectionString : ''
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~2'
        }
        {
          name: 'ISAPI_FILTER_ENABLED'
          value: 'true'
        }
        {
          name: 'SHARED_FOLDER_CONNECTION'
          value: enableAzureFiles && storageAccount != null ? 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net' : ''
        }
        {
          name: 'SHARED_FOLDER_NAME'
          value: enableAzureFiles ? fileShareName : ''
        }
        {
          name: 'AZURE_SQL_CONNECTION_STRING'
          value: enableAzureSQL ? 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDatabaseName};Authentication=Active Directory Default;' : ''
        }
        {
          name: 'KEY_VAULT_NAME'
          value: enableKeyVault ? keyVaultName : ''
        }
      ]
    }
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
  }
}

// App Service configuration for ISAPI
resource appServiceConfig 'Microsoft.Web/sites/config@2023-01-01' = {
  parent: appService
  name: 'web'
  properties: {
    netFrameworkVersion: 'v4.8'
    use32BitWorkerProcess: false
    managedPipelineMode: 'Classic'
    virtualApplications: [
      {
        virtualPath: '/'
        physicalPath: 'site\\wwwroot'
        preloadEnabled: true
      }
    ]
    defaultDocuments: [
      'default.htm'
      'default.html'
      'default.asp'
      'index.html'
      'iisstart.htm'
    ]
    httpLoggingEnabled: true
    requestTracingEnabled: true
    detailedErrorLoggingEnabled: true
  }
}

// Outputs
output appServiceName string = appService.name
output appServiceUrl string = 'https://${appService.properties.defaultHostName}'
output appServicePrincipalId string = enableManagedIdentity && appService.identity != null ? appService.identity.principalId : ''
output storageAccountName string = enableAzureFiles ? storageAccount.name : ''
output fileShareName string = enableAzureFiles ? fileShareName : ''
output applicationInsightsInstrumentationKey string = enableApplicationInsights ? applicationInsights.properties.InstrumentationKey : ''
output keyVaultName string = enableKeyVault ? keyVaultName : ''
output sqlServerName string = enableAzureSQL ? sqlServerName : ''
output sqlDatabaseName string = enableAzureSQL ? sqlDatabaseName : ''

// Secure connection string output (use Key Vault references in production)
output azureSqlConnectionString string = enableAzureSQL ? 'Server=tcp:${sqlServer.name}.${environment().suffixes.sqlServerHostname},1433;Initial Catalog=${sqlDatabaseName};Authentication=Active Directory Default;' : ''
