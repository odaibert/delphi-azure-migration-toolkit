# Download Instructions

This file contains all the necessary files to migrate your ISAPI filter to Azure App Service. 

> 📖 **Before You Start**: Review the [Azure Web App Sandbox Restrictions](https://github.com/projectkudu/kudu/wiki/Azure-Web-App-sandbox#general-sandbox-restrictions) and [Azure App Service Documentation](https://docs.microsoft.com/azure/app-service/) to understand platform limitations.

Here's how to download and use them:

## 📥 Quick Download Options

### Option 1: Download Individual Files (Recommended)

You can copy each file individually from this repository. The files are organized as follows:

```
📁 Root Directory
├── 📄 README.md (Main documentation)
├── 📁 infrastructure/
│   └── 📁 bicep/
│       ├── 📄 main.bicep
│       └── 📄 parameters.json
├── 📁 deployment/
│   ├── 📄 deploy.ps1
│   ├── 📄 web.config
│   └── 📄 applicationHost.config
├── 📁 scripts/
│   ├── 📄 setup-environment.ps1
│   └── 📄 test-deployment.ps1
└── 📁 docs/
    ├── 📄 troubleshooting.md
    └── 📄 migration-checklist.md
```

### Option 2: Download All Files as ZIP

If you're using GitHub or a similar platform:

1. Click the "Download ZIP" button or "Code" → "Download ZIP"
2. Extract the ZIP file to your desired location
3. Follow the setup instructions in the README.md

### Option 3: Clone Repository

If this is a Git repository:

```bash
git clone [repository-url]
cd "ISAPI to App Service"
```

## 🚀 Quick Start Guide

After downloading all files:

### 1. Prepare Your Environment

```powershell
# Navigate to the project directory
cd "path\to\ISAPI to App Service"

# Run the environment setup script
.\scripts\setup-environment.ps1
```

### 2. Add Your ISAPI DLL

1. Copy your compiled ISAPI DLL to the `deployment` folder
2. Rename it or update the `web.config` file accordingly

### 3. Configure Parameters

Edit the parameters in:
- `infrastructure\bicep\parameters.json` (for Bicep deployment)

### 4. Deploy Infrastructure

**Using Azure Bicep:**
```powershell
.\scripts\setup-environment.ps1
```

### 5. Deploy Your Application

```powershell
.\deployment\deploy.ps1 -ResourceGroupName "rg-isapi-migration" -AppServiceName "your-app-name"
```

### 6. Test the Deployment

```powershell
.\scripts\test-deployment.ps1 -AppServiceUrl "https://your-app-service.azurewebsites.net"
```

## 📁 File Descriptions

### Core Files

| File | Description | Required |
|------|-------------|----------|
| `README.md` | Complete migration guide and documentation | ✅ |
| `deployment/web.config` | IIS configuration for ISAPI filter | ✅ |
| `deployment/deploy.ps1` | PowerShell deployment script | ✅ |

### Infrastructure Files

| File | Description | Required |
|------|-------------|----------|
| `infrastructure/bicep/main.bicep` | Azure Bicep template | ✅ |
| `infrastructure/bicep/parameters.json` | Bicep parameters | ✅ |

### Utility Scripts

| File | Description | Required |
|------|-------------|----------|
| `scripts/setup-environment.ps1` | Environment setup automation | ⭐ |
| `scripts/test-deployment.ps1` | Deployment testing script | ⭐ |

### Documentation

| File | Description | Required |
|------|-------------|----------|
| `docs/troubleshooting.md` | Comprehensive troubleshooting guide | 📖 |
| `docs/migration-checklist.md` | Step-by-step migration checklist | 📖 |

**Legend:**
- ✅ Essential files
- ⭐ Highly recommended
- 📖 Reference documentation

## 🛠️ Prerequisites

Before using these files, ensure you have:

- **Azure CLI** installed and configured
- **PowerShell 5.0+** (Windows PowerShell or PowerShell Core)
- **Azure subscription** with appropriate permissions
- **Your compiled ISAPI DLL** (64-bit version required)

### Optional Tools

- **Git** (for version control)
- **Visual Studio Code** (for editing configuration files)

## 📝 Customization

### Required Customizations

1. **Update `web.config`:**
   - Replace `YourISAPIFilter.dll` with your actual DLL name
   - Adjust ISAPI filter settings as needed

2. **Update parameters:**
   - Set your preferred app name, region, and pricing tier
   - Configure any specific application settings

3. **Add your DLL:**
   - Place your compiled ISAPI DLL in the `deployment` folder

### Optional Customizations

1. **Modify deployment scripts:**
   - Adjust resource naming conventions
   - Add environment-specific configurations

2. **Update infrastructure templates:**
   - Modify SKUs, regions, or additional Azure services
   - Add custom monitoring or security configurations

## 🔧 Troubleshooting Download Issues

### File Encoding Issues

If you experience encoding issues with PowerShell scripts:

```powershell
# Convert file encoding to UTF-8
Get-Content "script-file.ps1" | Set-Content "script-file.ps1" -Encoding UTF8
```

### PowerShell Execution Policy

If scripts won't run due to execution policy:

```powershell
# Temporarily allow script execution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or run with bypass
PowerShell -ExecutionPolicy Bypass -File ".\script-name.ps1"
```

### Missing Files

If any files are missing or corrupted:

1. Re-download the problematic files
2. Check file integrity
3. Ensure all directories are created properly

## 📞 Support

If you encounter issues with downloading or using these files:

1. Check the **troubleshooting guide** (`docs/troubleshooting.md`)
2. Review the **migration checklist** (`docs/migration-checklist.md`)
3. Consult [Azure App Service documentation](https://docs.microsoft.com/azure/app-service/)
4. Review [Azure Web App Sandbox Restrictions](https://github.com/projectkudu/kudu/wiki/Azure-Web-App-sandbox#general-sandbox-restrictions)
5. Check [Azure App Service Configuration documentation](https://learn.microsoft.com/azure/app-service/configure-common)

## 🏁 Next Steps

After downloading all files:

1. ✅ Review the main `README.md` for complete instructions
2. ✅ Follow the migration checklist for systematic approach
3. ✅ Start with the setup script to provision Azure resources
4. ✅ Deploy your ISAPI filter using the deployment script
5. ✅ Test thoroughly using the testing script

---

**Happy migrating! 🚀**
