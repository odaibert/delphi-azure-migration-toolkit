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

@description('Enable Azure Files for shared folder replacement')
param enableAzureFiles bool = true

// Variables
var appServicePlanName = 'asp-${appName}'
var storageAccountName = 'st${replace(appName, '-', '')}${substring(uniqueString(resourceGroup().id), 0, 4)}'
var applicationInsightsName = 'ai-${appName}'
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
  dependsOn: [
    storageAccount
  ]
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
          value: enableApplicationInsights ? applicationInsights.properties.InstrumentationKey : ''
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: enableApplicationInsights ? applicationInsights.properties.ConnectionString : ''
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
          value: enableAzureFiles ? 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net' : ''
        }
        {
          name: 'SHARED_FOLDER_NAME'
          value: enableAzureFiles ? fileShareName : ''
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
output storageAccountName string = enableAzureFiles ? storageAccount.name : ''
output storageAccountKey string = enableAzureFiles ? storageAccount.listKeys().keys[0].value : ''
output fileShareName string = enableAzureFiles ? fileShareName : ''
output applicationInsightsInstrumentationKey string = enableApplicationInsights ? applicationInsights.properties.InstrumentationKey : ''
