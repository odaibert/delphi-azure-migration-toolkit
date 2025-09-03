# Quick Start Guide - Delphi ISAPI to Azure App Service

⏱️ **Estimated Time**: 30 minutes  
🎯 **Target Audience**: Experienced developers familiar with Azure and PowerShell

This streamlined guide gets your Delphi ISAPI filter running in Azure App Service quickly with minimal explanation.

## Prerequisites Checklist

- [ ] Azure subscription with Owner/Contributor access
- [ ] Azure CLI installed and authenticated (`az login`)
- [ ] PowerShell 5.1+ or PowerShell Core 7+
- [ ] Your compiled ISAPI DLL file ready
- [ ] Basic familiarity with Azure App Service

## 🚀 Rapid Deployment (4 Steps)

### Step 1: Environment Setup (5 minutes)

```powershell
# Clone and navigate
git clone https://github.com/odaibert/delphi-azure-migration-toolkit.git
cd delphi-azure-migration-toolkit

# Set Azure subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Create resource group
az group create --name "rg-delphi-isapi" --location "East US"
```

### Step 2: Infrastructure Deployment (10 minutes)

```powershell
# Deploy infrastructure using Bicep
az deployment group create \
  --resource-group "rg-delphi-isapi" \
  --template-file "infrastructure/bicep/main.bicep" \
  --parameters appName="your-app-name" \
               sqlAdminLogin="sqladmin" \
               sqlAdminPassword="YourSecurePassword123!"
```

### Step 3: ISAPI DLL Deployment (10 minutes)

```powershell
# Copy your ISAPI DLL to deployment folder
Copy-Item "C:\path\to\your\isapi.dll" "deployment\"

# Run deployment script
.\deployment\deploy.ps1 -ResourceGroupName "rg-delphi-isapi" -AppName "your-app-name"
```

### Step 4: Verification (5 minutes)

```powershell
# Test the deployment
.\scripts\test-deployment.ps1 -AppName "your-app-name"

# Open in browser
start "https://your-app-name.azurewebsites.net"
```

## ✅ Success Indicators

- [ ] Azure App Service shows "Running" status
- [ ] ISAPI DLL is loaded in the App Service
- [ ] Your application responds to HTTP requests
- [ ] No errors in Application Insights logs

## 🆘 Quick Troubleshooting

| Issue | Quick Fix |
|-------|-----------|
| DLL not loading | Check [web.config](../../deployment/web.config) ISAPI configuration |
| 500 errors | Review Application Insights logs in Azure portal |
| Permission issues | Verify App Service identity and SQL connection string |
| Sandbox violations | Check [Azure Sandbox Checklist](../../docs/azure-sandbox-checklist.md) |

## Next Steps

- 📊 **Monitor**: Set up alerts in Application Insights
- 🔐 **Secure**: Configure authentication and SSL certificates
- 📈 **Scale**: Enable auto-scaling based on metrics
- 🔄 **CI/CD**: Set up automated deployments

---

### Need More Detail?

If you encounter issues or want to understand the process deeply, switch to our **[Detailed Academic Guide](../detailed/README.md)** for comprehensive explanations and troubleshooting.

### Support Resources

- [Troubleshooting Guide](../../docs/troubleshooting.md)
- [Azure Sandbox Restrictions](../../docs/azure-sandbox-checklist.md)
- [Architecture Diagrams](../../docs/)
- [Official Azure Documentation](https://docs.microsoft.com/azure/app-service/)
