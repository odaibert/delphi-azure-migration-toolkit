// App Service Bicep Module for ISAPI Migration
@description('Name of the App Service')
param appServiceName string

@description('Location for resources')
param location string = resourceGroup().location

@description('App Service Plan SKU')
param skuName string = 'B1'

@description('App Service Plan capacity')
param capacity int = 1

@description('Enable Application Insights')
param enableAppInsights bool = true

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: '${appServiceName}-plan'
  location: location
  sku: {
    name: skuName
    capacity: capacity
  }
  properties: {
    reserved: false // Windows App Service
  }
  tags: {
    purpose: 'ISAPI Migration'
    environment: 'production'
  }
}

// App Service
resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: appServiceName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      netFrameworkVersion: 'v4.0'
      use32BitWorkerProcess: false
      webSocketsEnabled: false
      alwaysOn: skuName != 'F1' && skuName != 'D1'
      defaultDocuments: [
        'default.htm'
        'default.html'
        'index.htm'
        'index.html'
      ]
    }
    httpsOnly: true
  }
  tags: {
    purpose: 'ISAPI Migration'
    environment: 'production'
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = if (enableAppInsights) {
  name: '${appServiceName}-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
  tags: {
    purpose: 'ISAPI Migration'
    environment: 'production'
  }
}

// App Service configuration for Application Insights
resource appServiceAppSettings 'Microsoft.Web/sites/config@2023-01-01' = if (enableAppInsights) {
  parent: appService
  name: 'appsettings'
  properties: {
    APPINSIGHTS_INSTRUMENTATIONKEY: appInsights!.properties.InstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights!.properties.ConnectionString
  }
}

output appServiceName string = appService.name
output appServiceUrl string = 'https://${appService.properties.defaultHostName}'
output appInsightsKey string = enableAppInsights ? appInsights!.properties.InstrumentationKey : ''
