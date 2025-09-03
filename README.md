# Delphi ISAPI Filter Migration to Azure App Service

This repository contains all the necessary files and step-by-step instructions to migrate a legacy Delphi ISAPI filter application to Microsoft Azure App Service.

> 📖 **Official Documentation**: For comprehensive Azure App Service guidance, see the [Azure App Service Documentation](https://docs.microsoft.com/azure/app-service/) and [ISAPI Extension and Filter support](https://docs.microsoft.com/azure/app-service/configure-language-dotnetframework#isapi-extensions-and-filters).

> ⚠️ **Important**: Before migrating, review the [Azure Web App Sandbox Restrictions](https://github.com/projectkudu/kudu/wiki/Azure-Web-App-sandbox#general-sandbox-restrictions) to understand platform limitations. See our comprehensive [Azure Sandbox Checklist](docs/azure-sandbox-checklist.md) for detailed coverage of each restriction with official Microsoft documentation references.

## 📋 Prerequisites

- Azure subscription
- Azure CLI installed
- Your compiled ISAPI DLL file
- PowerShell (for Windows deployment scripts)

## 🏗️ Repository Structure

```
├── README.md                 # This file - complete migration guide
├── infrastructure/           # Azure infrastructure files
│   └── bicep/               # ARM/Bicep templates
│       ├── main.bicep       # Main infrastructure template
│       └── parameters.json  # Environment parameters
├── deployment/              # Deployment scripts and configs
│   ├── deploy.ps1          # PowerShell deployment script
│   ├── web.config          # IIS configuration for ISAPI
│   └── applicationHost.config # Advanced IIS settings
├── scripts/                # Utility scripts
│   ├── setup-environment.ps1
│   └── test-deployment.ps1
└── docs/                   # Additional documentation
    ├── troubleshooting.md
    ├── migration-checklist.md
    └── azure-sandbox-checklist.md
```

## 🚀 Step-by-Step Migration Guide

### Step 1: Prepare Your Environment

1. **Install Azure CLI** (if not already installed):
   ```powershell
   winget install Microsoft.AzureCLI
   ```

2. **Login to Azure**:
   ```powershell
   az login
   ```

3. **Set your subscription**:
   ```powershell
   az account set --subscription "your-subscription-id"
   ```

### Step 2: Provision Azure Resources

**Deploy the infrastructure using Azure Bicep:**

1. **Deploy the infrastructure**:
   ```powershell
   .\scripts\setup-environment.ps1
   ```

2. **Or manually deploy**:
   ```powershell
   az deployment group create \
     --resource-group rg-isapi-migration \
     --template-file infrastructure/bicep/main.bicep \
     --parameters @infrastructure/bicep/parameters.json
   ```

### Step 3: Prepare Your ISAPI DLL

1. **Place your ISAPI DLL** in the `deployment` folder
2. **Ensure the DLL is compiled for x64** (App Service requirement)
3. **Test the DLL locally** with IIS Express if possible

### Step 4: Configure IIS Settings

The `web.config` file in the `deployment` folder contains the necessary IIS configuration for your ISAPI filter. Key configurations include:

- ISAPI filter registration
- Handler mappings
- Security settings
- Request filtering

### Step 5: Deploy Your Application

Run the deployment script:
```powershell
.\deployment\deploy.ps1 -ResourceGroupName "rg-isapi-migration" -AppServiceName "your-app-service-name"
```

### Step 6: Configure App Service

1. **Enable native code execution** (already configured in Bicep template)
2. **Set up application settings** for your ISAPI filter
3. **Configure shared folder access** using Azure Files or Storage Account

### Step 7: Test and Verify

1. **Run the test script**:
   ```powershell
   .\scripts\test-deployment.ps1 -AppServiceUrl "https://your-app-service.azurewebsites.net"
   ```

2. **Monitor logs** in Azure Portal or using:
   ```powershell
   az webapp log tail --name your-app-service-name --resource-group rg-isapi-migration
   ```

## 🔧 Configuration Options

### Shared Folder Migration

Your legacy shared folder can be replaced with:
- **Azure Files**: SMB-compatible file share
- **Azure Blob Storage**: For file storage with REST API access
- **Azure Storage Account**: General-purpose storage

### Scaling Options

- **App Service Plan**: Choose appropriate tier (Standard or Premium for production)
- **Auto-scaling**: Configure based on CPU/memory metrics
- **Load balancing**: Built-in with App Service

## 📚 Additional Resources

- [Azure App Service Documentation](https://docs.microsoft.com/azure/app-service/)
- [ISAPI Extensions and Filters on App Service](https://docs.microsoft.com/azure/app-service/configure-language-dotnetframework#isapi-extensions-and-filters)
- [Azure Web App Sandbox Restrictions](https://github.com/projectkudu/kudu/wiki/Azure-Web-App-sandbox#general-sandbox-restrictions)
- [Azure Bicep Documentation](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
- [Troubleshooting Guide](docs/troubleshooting.md)
- [Migration Checklist](docs/migration-checklist.md)
- [Azure App Service Pricing](https://azure.microsoft.com/pricing/details/app-service/windows/)

## 🆘 Support

If you encounter issues:
1. Check the troubleshooting guide
2. Review Azure App Service logs
3. Verify ISAPI DLL compatibility
4. Check IIS configuration in web.config

## 📝 Notes

- ISAPI filters on App Service have limitations compared to full IIS - see [Azure Web App Sandbox Restrictions](https://github.com/projectkudu/kudu/wiki/Azure-Web-App-sandbox#general-sandbox-restrictions)
- Consider modernizing to ASP.NET Core for better cloud-native support
- Test thoroughly in a development environment before production deployment
- Review [Azure App Service limitations](https://docs.microsoft.com/azure/app-service/overview-compare) for ISAPI compatibility

---

**Happy migrating! 🚀**
