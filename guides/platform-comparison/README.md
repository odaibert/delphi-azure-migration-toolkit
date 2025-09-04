# Azure Platform Decision Matrix for ISAPI Migration

Select the optimal Azure compute platform for your Delphi ISAPI filter migration based on technical requirements, operational constraints, and future modernization goals.

> 📖 **Microsoft Learn Reference**: [Choose an Azure compute service](https://learn.microsoft.com/azure/architecture/guide/technology-choices/compute-decision-tree)

## Platform Comparison Overview

| Factor | App Service | Container Apps | AKS |
|--------|-------------|----------------|-----|
| **Migration Effort** | Low | Medium | High |
| **Time to Deploy** | 1-2 weeks | 1-3 months | 3-6 months |
| **ISAPI Support** | ✅ Native | ❌ Requires rewrite | ❌ Requires rewrite |
| **Shared Folder** | ✅ [Azure Files](https://learn.microsoft.com/azure/app-service/configure-connect-to-azure-storage) | ⚠️ Complex setup | ⚠️ Complex setup |
| **Scaling** | ✅ [Auto](https://learn.microsoft.com/azure/app-service/manage-scale-up) | ✅ [Serverless](https://learn.microsoft.com/azure/container-apps/scale-app) | ✅ [Advanced](https://learn.microsoft.com/azure/aks/concepts-scale) |
| **Cost (Small App)** | $ | $$ | $$$ |
| **Operational Complexity** | Low | Medium | High |
| **Future Modernization** | Limited | Good | Excellent |
| **Windows Support** | ✅ [Native](https://learn.microsoft.com/azure/app-service/configure-language-dotnetframework) | ✅ [Windows containers](https://learn.microsoft.com/azure/container-apps/windows-containers) | ✅ [Windows nodes](https://learn.microsoft.com/azure/aks/windows-aks-cli) |

## Decision Framework

### Use Azure App Service When:
- **ISAPI compatibility** is required with minimal code changes
- **Rapid migration** timeline (weeks, not months)
- **Limited container expertise** in the organization
- **Cost optimization** is a primary concern
- **Platform-managed** infrastructure is preferred

**Microsoft Learn**: [Introduction to Azure App Service](https://learn.microsoft.com/training/modules/introduction-to-azure-app-service/)

### Use Container Apps When:
- **Modernization** is a primary goal
- **Microservices architecture** is planned
- **Event-driven scaling** requirements exist
- **Multi-cloud portability** is important
- **Willing to containerize** the ISAPI application

**Microsoft Learn**: [Introduction to Azure Container Apps](https://learn.microsoft.com/training/modules/intro-to-azure-container-apps/)

### Use AKS When:
- **Enterprise Kubernetes** strategy exists
- **Advanced orchestration** features needed
- **Multi-tenant** or complex networking requirements
- **Full control** over the container runtime
- **Long-term modernization** investment planned

**Microsoft Learn**: [Introduction to Azure Kubernetes Service](https://learn.microsoft.com/training/modules/intro-to-azure-kubernetes-service/)

## Technical Analysis

### Azure App Service for ISAPI

**Advantages:**
- Native ISAPI filter support without code changes
- [Integrated deployment slots](https://learn.microsoft.com/azure/app-service/deploy-staging-slots) for testing
- [Built-in authentication](https://learn.microsoft.com/azure/app-service/overview-authentication-authorization)
- [Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview) integration
- Managed SSL certificates and custom domains

**Limitations:**
- [Sandbox restrictions](https://learn.microsoft.com/azure/app-service/overview-security#sandboxed-environment) on system operations
- Limited to Windows for ISAPI support
- Scaling limitations compared to container platforms

**Implementation Path:**
```powershell
# Deploy App Service with ISAPI support
az appservice plan create --name myAppServicePlan --resource-group myResourceGroup --sku B1 --is-linux false
az webapp create --resource-group myResourceGroup --plan myAppServicePlan --name myISAPIApp --runtime "DOTNETFRAMEWORK|4.8"
```

### Container Apps for ISAPI

**Modernization Requirements:**
- Convert ISAPI filter to [.NET Web API](https://learn.microsoft.com/aspnet/core/web-api/) or middleware
- Containerize using [Windows Server Core](https://learn.microsoft.com/virtualization/windowscontainers/manage-containers/container-base-images)
- Implement [HTTP triggers](https://learn.microsoft.com/azure/container-apps/application-lifecycle-management) for request processing

**Benefits:**
- [Serverless scaling](https://learn.microsoft.com/azure/container-apps/scale-app) including scale-to-zero
- [Event-driven architecture](https://learn.microsoft.com/azure/container-apps/overview) support
- [KEDA](https://learn.microsoft.com/azure/container-apps/scale-app#scale-triggers) integration for advanced scaling

**Implementation Considerations:**
```dockerfile
# Example Dockerfile for ISAPI modernization
FROM mcr.microsoft.com/dotnet/aspnet:8.0-windowsservercore-ltsc2022
COPY ./modernized-api ./app
WORKDIR /app
EXPOSE 80
ENTRYPOINT ["dotnet", "ModernizedISAPI.dll"]
```

### AKS for ISAPI

**Enterprise Requirements:**
- Complete application modernization to microservices
- [Windows node pools](https://learn.microsoft.com/azure/aks/windows-node-limitations) for Windows container support
- Advanced networking with [Azure CNI](https://learn.microsoft.com/azure/aks/configure-azure-cni)
- [Azure AD integration](https://learn.microsoft.com/azure/aks/managed-aad) for authentication

**Advanced Features:**
- [Horizontal Pod Autoscaler](https://learn.microsoft.com/azure/aks/concepts-scale#horizontal-pod-autoscaler)
- [Azure Policy](https://learn.microsoft.com/azure/aks/use-azure-policy) for governance
- [GitOps workflows](https://learn.microsoft.com/azure/aks/gitops-flux2) for deployment

## Cost Analysis

### Monthly Cost Estimation (East US region)

**App Service (Production Ready):**
```text
- App Service Plan (S1): ~$70/month
- Azure SQL Database (S1): ~$30/month
- Application Insights: ~$10/month
- Storage Account: ~$5/month
Total: ~$115/month
```

**Container Apps (Production Ready):**
```text
- Container Apps Environment: ~$45/month
- Container Apps consumption: ~$25/month
- Azure SQL Database (S1): ~$30/month
- Application Insights: ~$10/month
- Container Registry: ~$5/month
Total: ~$115/month
```

**AKS (Production Ready):**
```text
- AKS Cluster Management: Free
- Node Pool (2x Standard_D2s_v3): ~$140/month
- Azure SQL Database (S1): ~$30/month
- Application Insights: ~$10/month
- Load Balancer: ~$20/month
Total: ~$200/month
```

**Microsoft Reference**: [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/)

## Migration Timeline Comparison

### App Service Migration (1-2 weeks)
1. **Week 1**: Infrastructure setup and ISAPI deployment
2. **Week 2**: Configuration optimization and testing

### Container Apps Migration (1-3 months)
1. **Month 1**: Application modernization and containerization
2. **Month 2**: Container Apps deployment and testing
3. **Month 3**: Performance optimization and production readiness

### AKS Migration (3-6 months)
1. **Months 1-2**: Microservices architecture design and development
2. **Months 3-4**: Kubernetes cluster setup and application deployment
3. **Months 5-6**: Advanced features implementation and production hardening

## Decision Tree

```text
Do you need ISAPI compatibility?
├── Yes
│   ├── Rapid migration required? → Azure App Service
│   └── Future modernization priority? → Plan phased approach (App Service → Container Apps)
└── No
    ├── Existing container strategy? → Container Apps
    ├── Enterprise Kubernetes needs? → AKS
    └── Simple web application? → Azure App Service (modernized)
```

## Next Steps

### For App Service Migration:
- Proceed to [Rapid Migration Guide](../rapid-migration/README.md)
- Review [Azure App Service limitations](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits#app-service-limits)

### For Container Apps Migration:
- Complete [Container Apps learning path](https://learn.microsoft.com/training/paths/deploy-manage-containers-azure-container-apps/)
- Plan application modernization strategy

### For AKS Migration:
- Complete [AKS learning path](https://learn.microsoft.com/training/paths/deploy-manage-resource-manager-templates/)
- Assess organizational Kubernetes readiness

## Additional Resources

- [Azure Architecture Center - Web Applications](https://learn.microsoft.com/azure/architecture/browse/?terms=web%20applications)
- [Cloud Adoption Framework - Migrate](https://learn.microsoft.com/azure/cloud-adoption-framework/migrate/)
- [Well-Architected Framework](https://learn.microsoft.com/azure/architecture/framework/)
- [Azure Migration and Modernization Program](https://azure.microsoft.com/migration/migration-modernization-program/)
