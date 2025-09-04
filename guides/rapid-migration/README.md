# Rapid Migration Guide - Delphi ISAPI to Azure App Service

Deploy your Delphi ISAPI filter to Azure App Service using a lift-and-shift approach with minimal code modifications.

⏱️ **Implementation Time**: 2-4 hours  
🎯 **Target Scenario**: Compatible ISAPI applications requiring rapid cloud migration  
📋 **Prerequisites**: Azure subscription, Azure CLI, PowerShell, compiled ISAPI DLL

> 📖 **Microsoft Learn**: [Azure App Service deployment](https://learn.microsoft.com/azure/app-service/deploy-continuous-deployment)

## Prerequisites Validation

Verify your environment meets Azure App Service requirements:

- [ ] [Azure subscription](https://azure.microsoft.com/free/) with Contributor access
- [ ] [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) 2.50.0+ authenticated (`az login`)
- [ ] [PowerShell 7.0+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) or Windows PowerShell 5.1
- [ ] ISAPI DLL compiled and tested
- [ ] [Platform compatibility assessment](../../docs/azure-sandbox-checklist.md) completed

## Implementation Steps

### Step 1: Configure Azure Environment

Set up your Azure subscription and resource group:

```powershell
# Authenticate to Azure
az login

# Set target subscription
az account set --subscription "your-subscription-id"

# Create resource group
$resourceGroup = "rg-delphi-isapi-prod"
$location = "East US"
az group create --name $resourceGroup --location $location
```

**Reference**: [Manage Azure resource groups](https://learn.microsoft.com/azure/azure-resource-manager/management/manage-resource-groups-cli)

### Step 2: Deploy Azure Infrastructure

Deploy App Service infrastructure using Azure Bicep:

```powershell
# Deploy infrastructure
az deployment group create \
  --resource-group $resourceGroup \
  --template-file "infrastructure/bicep/main.bicep" \
  --parameters appName="delphi-isapi-app" \
               environment="prod" \
               appServicePlanSku="S1" \
               sqlDatabaseTier="Standard"
```

**Reference**: [Deploy Bicep files with Azure CLI](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deploy-cli)

### Step 3: Configure ISAPI Deployment

Prepare and deploy your ISAPI filter:

```powershell
# Copy ISAPI DLL to deployment directory
$isapiDllPath = "C:\path\to\your\isapi.dll"
Copy-Item $isapiDllPath "deployment\"

# Configure App Service for ISAPI
$appName = "delphi-isapi-app"
az webapp config set --resource-group $resourceGroup --name $appName --net-framework-version "v4.8"

# Deploy ISAPI application
.\deployment\deploy.ps1 -ResourceGroupName $resourceGroup -AppName $appName
```

**Reference**: [Configure Windows Apps in Azure App Service](https://learn.microsoft.com/azure/app-service/configure-common)

### Step 4: Validate Deployment

Verify successful deployment and functionality:

```powershell
# Test application endpoint
$appUrl = "https://$appName.azurewebsites.net"
$response = Invoke-WebRequest -Uri $appUrl -Method GET -ErrorAction Continue

if ($response.StatusCode -eq 200) {
    Write-Host "✅ Application deployed successfully" -ForegroundColor Green
    Write-Host "URL: $appUrl" -ForegroundColor Blue
} else {
    Write-Host "❌ Deployment validation failed" -ForegroundColor Red
    Write-Host "Status Code: $($response.StatusCode)" -ForegroundColor Yellow
}

# Validate ISAPI filter registration
az webapp log tail --resource-group $resourceGroup --name $appName
```

**Reference**: [Monitor Azure App Service](https://learn.microsoft.com/azure/app-service/troubleshoot-diagnostic-logs)

## Configuration Verification

### Deployment Success Indicators
- [ ] Azure App Service shows "Running" status in portal
- [ ] ISAPI filter loads without errors in Application Insights
- [ ] HTTP requests return expected responses
- [ ] Database connectivity established (if applicable)
- [ ] Static content serves correctly

### Common Deployment Issues

| Issue | Resolution | Reference |
|-------|------------|-----------|
| ISAPI DLL not loading | Verify [web.config configuration](../../deployment/web.config) | [Configure handlers](https://learn.microsoft.com/iis/configuration/system.webserver/handlers/) |
| HTTP 500 errors | Check Application Insights logs | [Diagnose exceptions](https://learn.microsoft.com/azure/azure-monitor/app/asp-net-exceptions) |
| Database connection failures | Validate connection strings in App Settings | [Configure connection strings](https://learn.microsoft.com/azure/app-service/configure-common#configure-connection-strings) |
| Sandbox violations | Review [compatibility assessment](../../docs/azure-sandbox-checklist.md) | [App Service sandbox](https://learn.microsoft.com/azure/app-service/overview-security#sandboxed-environment) |

## Post-Deployment Tasks

### Security Configuration
```powershell
# Enable HTTPS-only
az webapp update --resource-group $resourceGroup --name $appName --https-only true

# Configure minimum TLS version
az webapp config set --resource-group $resourceGroup --name $appName --min-tls-version "1.2"

# Enable managed identity
az webapp identity assign --resource-group $resourceGroup --name $appName
```

**Reference**: [Secure Azure App Service](https://learn.microsoft.com/azure/app-service/overview-security)

### Monitoring Setup
```powershell
# Configure Application Insights alerts
az monitor metrics alert create \
  --name "High CPU Usage" \
  --resource-group $resourceGroup \
  --scopes "/subscriptions/{subscription-id}/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$appName" \
  --condition "avg Percentage CPU > 80"
```

**Reference**: [Monitor App Service performance](https://learn.microsoft.com/azure/azure-monitor/app/web-monitor-performance)

## Next Steps

### Production Readiness
- **Security**: Configure [authentication and authorization](https://learn.microsoft.com/azure/app-service/overview-authentication-authorization)
- **Scaling**: Set up [auto-scaling rules](https://learn.microsoft.com/azure/app-service/manage-scale-up)
- **Backup**: Configure [automated backups](https://learn.microsoft.com/azure/app-service/manage-backup)
- **Custom Domain**: Add [custom domain and SSL](https://learn.microsoft.com/azure/app-service/app-service-web-tutorial-custom-domain)

### Advanced Configuration
For complex scenarios requiring detailed planning, proceed to the [Enterprise Migration Guide](../enterprise/README.md).

## Support Resources

### Troubleshooting
- [Azure App Service diagnostics](https://learn.microsoft.com/azure/app-service/overview-diagnostics)
- [Migration troubleshooting guide](../../docs/troubleshooting.md)
- [Azure sandbox compatibility](../../docs/azure-sandbox-checklist.md)

### Microsoft Learn Paths
- [Deploy a website to Azure with Azure App Service](https://learn.microsoft.com/training/paths/deploy-a-website-with-azure-app-service/)
- [Configure and manage Azure App Service](https://learn.microsoft.com/training/paths/configure-manage-azure-app-service/)
- [Monitor and back up Azure resources](https://learn.microsoft.com/training/paths/architect-storage-infrastructure/)
