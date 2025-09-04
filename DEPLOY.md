# 🚀 Quick Deployment Guide

This guide will help you deploy your ISAPI application to Azure App Service.

## 📋 Prerequisites

1. **Azure CLI** - [Install Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
2. **PowerShell 7+** - [Install PowerShell](https://docs.microsoft.com/powershell/scripting/install/installing-powershell)
3. **Azure Subscription** - Active Azure subscription
4. **ISAPI Filter DLL** - Your compiled ISAPI filter

## ⚡ Quick Start (5 minutes)

### Option 1: Complete Automated Deployment

```powershell
# Login to Azure
az login

# Run the complete deployment script
.\deploy-complete.ps1 -ResourceGroupName "rg-my-isapi-app" -AppName "my-unique-app-name" -ISAPIPath ".\MyFilter.dll"
```

### Option 2: Step-by-Step Deployment

```powershell
# 1. Create infrastructure only
.\deploy-complete.ps1 -ResourceGroupName "rg-my-isapi-app" -AppName "my-unique-app-name" -SkipInfrastructure:$false

# 2. Deploy your application later
.\deployment\deploy.ps1 -ResourceGroupName "rg-my-isapi-app" -AppServiceName "my-unique-app-name" -ISAPIFilePath ".\MyFilter.dll"
```

## 🔧 Configuration Options

### Basic Deployment
```powershell
.\deploy-complete.ps1 -ResourceGroupName "rg-isapi" -AppName "myapp-$(Get-Random)"
```

### Production Deployment
```powershell
.\deploy-complete.ps1 `
    -ResourceGroupName "rg-production-isapi" `
    -AppName "prod-isapi-app" `
    -Location "East US" `
    -ISAPIPath ".\Production\MyFilter.dll"
```

### Development/Testing
```powershell
.\deploy-complete.ps1 `
    -ResourceGroupName "rg-dev-isapi" `
    -AppName "dev-isapi-app" `
    -Location "East US" `
    -ISAPIPath ".\Debug\MyFilter.dll"
```

## 📊 Deployment Parameters

| Parameter | Required | Description | Example |
|-----------|----------|-------------|---------|
| `ResourceGroupName` | ✅ | Azure Resource Group name | `"rg-my-isapi-app"` |
| `AppName` | ✅ | App Service name (must be unique) | `"my-isapi-app-123"` |
| `Location` | ❌ | Azure region | `"East US"` (default) |
| `ISAPIPath` | ❌ | Path to ISAPI DLL | `".\MyFilter.dll"` |
| `SubscriptionId` | ❌ | Azure subscription ID | Auto-detected |
| `SkipInfrastructure` | ❌ | Skip infrastructure creation | `$false` (default) |

## 🎯 What Gets Deployed

### Azure Resources
- **Resource Group** - Container for all resources
- **App Service Plan** (S1 SKU) - Compute resources
- **App Service** - Web application hosting
- **Application Insights** - Monitoring and diagnostics
- **Storage Account** - File storage and shared folders
- **Azure Files** - Shared network drives (if needed)

### App Service Configuration
- ✅ Windows OS with IIS
- ✅ 32-bit worker process support
- ✅ ISAPI filter support enabled  
- ✅ Enhanced logging
- ✅ Application Insights integration

## 🔍 Monitoring & Validation

After deployment, check:

```powershell
# View application logs
az webapp log tail --name YOUR_APP_NAME --resource-group YOUR_RG_NAME

# Check app status  
az webapp show --name YOUR_APP_NAME --resource-group YOUR_RG_NAME --query "state"

# Test the application
curl https://YOUR_APP_NAME.azurewebsites.net
```

## 🛠️ Troubleshooting

### Common Issues:

1. **App Name Already Taken**
   - App Service names must be globally unique
   - Try: `"myapp-$(Get-Random)"` or add timestamp

2. **ISAPI Filter Not Loading**
   - Check if DLL is 32-bit compatible
   - Verify web.config ISAPI configuration
   - Check App Service logs

3. **Permission Issues**
   - Ensure you have Contributor access to subscription
   - Check if resource providers are registered

### Debug Commands:
```powershell
# Check deployment status
az deployment group list --resource-group YOUR_RG_NAME

# View detailed logs
az webapp log download --name YOUR_APP_NAME --resource-group YOUR_RG_NAME

# Access SSH console
# Go to: https://YOUR_APP_NAME.scm.azurewebsites.net/webssh/host
```

## 📱 Post-Deployment Checklist

- [ ] Test ISAPI filter functionality
- [ ] Configure custom domain (if needed)
- [ ] Set up SSL certificate
- [ ] Configure auto-scaling rules
- [ ] Set up monitoring alerts
- [ ] Review security settings
- [ ] Configure backup strategy

## 🔗 Useful Links

- [Azure App Service Documentation](https://docs.microsoft.com/azure/app-service/)
- [ISAPI Filter Migration Guide](./guides/)
- [Troubleshooting Guide](./docs/troubleshooting.md)
- [Azure Portal](https://portal.azure.com/)

## 🆘 Need Help?

1. Check the [troubleshooting guide](./docs/troubleshooting.md)
2. Review App Service logs in Azure Portal
3. Use the enterprise migration modules in `./guides/enterprise/`
4. Contact Azure Support for complex issues

---

**Ready to deploy? Run the deployment script and follow the interactive prompts!** 🚀
