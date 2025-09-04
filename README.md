# Delphi ISAPI Filter Migration to Azure App Service

Migrate legacy Delphi ISAPI filter applications to Microsoft Azure App Service using proven cloud migration patterns and Infrastructure as Code.

> 📖 **Microsoft Documentation**: [Azure App Service overview](https://learn.microsoft.com/azure/app-service/overview) | [ISAPI extensions and filters](https://learn.microsoft.com/azure/app-service/configure-language-dotnetframework#isapi-extensions-and-filters)

> ⚠️ **Platform Limitations**: Review [Azure App Service sandbox restrictions](https://learn.microsoft.com/azure/app-service/overview-security#sandboxed-environment) before migration. Use our [Azure Platform Compatibility Assessment](docs/azure-sandbox-checklist.md) for detailed restriction analysis.

## 🎯 Migration Approach Selection

Choose your migration strategy based on technical requirements and organizational constraints:

### 🚀 **Rapid Migration (2-4 hours)**
Lift-and-shift approach for compatible applications.
- **[Rapid Migration Guide](guides/rapid-migration/README.md)**
- Pre-validated ISAPI compatibility
- Minimal code modifications required
- Direct Azure App Service deployment

### 🏗️ **Comprehensive Migration (1-2 weeks)**
Complete assessment and optimization for enterprise workloads.
- **[Enterprise Migration Guide](guides/enterprise/README.md)**
- Platform compatibility assessment
- Architecture optimization and modernization
- Production-ready deployment automation

### 📊 **Platform Comparison Analysis**
Evaluate Azure hosting options for your specific requirements.
- **[Azure Platform Decision Matrix](guides/platform-comparison/README.md)**
- App Service vs Container Apps vs AKS analysis
- Cost and complexity trade-offs
- Future modernization pathways

---

## 🏗️ Technical Prerequisites

Configure your development environment before migration:
- [Azure subscription](https://azure.microsoft.com/free/) with Contributor access
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) 2.50.0 or later
- [PowerShell 7.0+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) or Windows PowerShell 5.1
- Compiled ISAPI DLL and source code access

## 🗂️ Repository Structure

```
├── README.md                 # Migration overview and strategy selection
├── guides/                   # Implementation guides
│   ├── rapid-migration/      # Lift-and-shift deployment (2-4 hours)
│   │   └── README.md         # Rapid migration procedures
│   ├── enterprise/           # Comprehensive migration (1-2 weeks)
│   │   ├── README.md         # Enterprise migration framework
│   │   └── modules/          # Technical implementation modules
│   └── platform-comparison/  # Azure platform decision matrix
│       └── README.md         # App Service vs Container Apps vs AKS
├── infrastructure/           # Infrastructure as Code templates
│   └── bicep/               # Azure Bicep templates
│       ├── main.bicep       # App Service infrastructure
│       └── parameters.json  # Environment configurations
├── deployment/              # Deployment automation
│   ├── deploy.ps1          # PowerShell deployment scripts
│   ├── web.config          # IIS configuration for ISAPI
│   └── applicationHost.config # Advanced IIS settings
├── scripts/                # Utility and validation scripts
│   ├── setup-environment.ps1
│   └── validate-deployment.ps1
└── docs/                   # Technical documentation
    ├── troubleshooting.md
    ├── migration-checklist.md
    ├── azure-sandbox-checklist.md
    ├── architecture-diagram.svg
    └── simple-architecture-diagram.svg
```

## 🏗️ Solution Architecture

Transform legacy on-premises ISAPI infrastructure to cloud-native Azure services:

### Reference Architecture
- **[Detailed Architecture Diagram](docs/architecture-diagram.svg)** - Complete migration transformation
- **[Simplified Architecture Overview](docs/simple-architecture-diagram.svg)** - High-level component mapping

### Migration Transformation
- **Legacy**: Windows Server + IIS + Local SQL Server + File System
- **Modern**: [Azure App Service](https://learn.microsoft.com/azure/app-service/overview) + [Azure SQL Database](https://learn.microsoft.com/azure/azure-sql/database/sql-database-paas-overview) + [Azure Storage](https://learn.microsoft.com/azure/storage/common/storage-introduction)

## 📚 Technical Documentation

### Implementation Resources
- **[Migration Troubleshooting](docs/troubleshooting.md)** - Common issues and resolutions
- **[Pre-migration Checklist](docs/migration-checklist.md)** - Migration readiness validation
- **[Azure Platform Compatibility](docs/azure-sandbox-checklist.md)** - Sandbox restriction analysis

### Microsoft Learn References
- [Configure App Service plans](https://learn.microsoft.com/training/modules/configure-app-service-plans/)
- [Deploy applications to App Service](https://learn.microsoft.com/training/modules/deploy-app-service/)
- [Monitor App Service performance](https://learn.microsoft.com/training/modules/monitor-app-service-performance/)

## 🤝 Support and Contribution

### Technical Support
- [GitHub Issues](https://github.com/odaibert/delphi-azure-migration-toolkit/issues) - Report issues and request features
- [Azure App Service documentation](https://learn.microsoft.com/azure/app-service/) - Official Microsoft documentation
- [Azure Community Support](https://learn.microsoft.com/answers/tags/azure-app-service/) - Community-driven support forum

### Contributing
Follow [Microsoft's contribution guidelines](https://learn.microsoft.com/contribute/) for documentation improvements and code contributions.

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
