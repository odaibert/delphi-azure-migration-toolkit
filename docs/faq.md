# Frequently Asked Questions (FAQ)

## 🚀 Getting Started

### Q: Which migration path should I choose?
**A:** Use the **Rapid Migration** for development/testing or simple applications. Choose **Enterprise Migration** for production applications with complex requirements, compliance needs, or custom integrations.

### Q: How long does migration take?
**A:** 
- **Rapid Migration**: 2-4 hours for compatible applications
- **Enterprise Migration**: 1-2 weeks including assessment, testing, and production deployment

### Q: What are the costs involved?
**A:** Azure App Service costs vary by tier:
- **Basic B1**: ~$13/month (development/testing)
- **Standard S1**: ~$73/month (production)
- **Premium P1V3**: ~$146/month (enterprise)

## 🔧 Technical Questions

### Q: My ISAPI filter uses registry access. Will it work?
**A:** No, Azure App Service sandbox blocks registry access. Use **Azure App Settings** or **Azure Key Vault** instead. Our [sandbox compatibility guide](docs/azure-sandbox-checklist.md) provides detailed alternatives.

### Q: Can I use COM components?
**A:** In-process COM components work. Out-of-process COM servers are blocked. Consider migrating to Azure Functions or Azure Logic Apps for complex integrations.

### Q: How do I handle file system operations?
**A:** 
- **Temporary files**: Use `D:\local\Temp\` directory
- **Persistent files**: Use Azure Blob Storage
- **Configuration files**: Use Azure App Settings
- **Shared files**: Use Azure Files storage

### Q: What about database connections?
**A:** Azure App Service works with:
- **Azure SQL Database** (recommended)
- **SQL Server on Azure VM**
- **On-premises SQL** (with hybrid connections)
- **Other databases** via connection strings

## ⚡ Deployment Issues

### Q: My deployment fails with "ISAPI filter not loaded"
**A:** Check:
1. DLL is x64 compiled
2. `web.config` has correct handler mapping
3. Dependencies are available in App Service
4. Review deployment logs in Azure portal

### Q: Getting 403 Forbidden errors
**A:** Ensure you have a default document (`default.htm` or `index.html`) in your deployment. App Service requires explicit content files.

### Q: How do I debug ISAPI issues in Azure?
**A:** 
1. Enable **Application Insights** for monitoring
2. Use **Log Stream** in Azure portal
3. Check **Diagnostic Settings** for detailed logs
4. Review IIS logs in `D:\home\LogFiles\`

## 🏗️ Architecture Questions

### Q: Can I use multiple ISAPI filters?
**A:** Yes, configure multiple handlers in `web.config`. Each filter can handle different URL patterns or request types.

### Q: How do I scale my application?
**A:** Azure App Service provides:
- **Manual scaling**: Adjust instance count
- **Auto-scaling**: Scale based on CPU, memory, or custom metrics
- **Scale out**: Multiple regions with Traffic Manager

### Q: What about high availability?
**A:** Use:
- **App Service Plan** with multiple instances
- **Azure Traffic Manager** for multi-region deployment
- **Azure Front Door** for global load balancing

## 🔒 Security & Compliance

### Q: Is my data secure in Azure App Service?
**A:** Yes, Azure App Service provides:
- **HTTPS by default** with managed certificates
- **Network isolation** with VNet integration
- **Azure Key Vault** integration for secrets
- **Azure Active Directory** authentication

### Q: How do I meet compliance requirements?
**A:** Azure App Service supports:
- **SOC 1, SOC 2, SOC 3** compliance
- **GDPR** data protection
- **HIPAA** for healthcare applications
- **FedRAMP** for government workloads

## 💰 Cost Optimization

### Q: How can I reduce Azure costs?
**A:** 
1. **Right-size** your App Service Plan
2. **Use staging slots** instead of separate environments
3. **Enable auto-scaling** to handle traffic spikes
4. **Use Azure Advisor** recommendations
5. **Consider Azure Reserved Instances** for predictable workloads

### Q: What's included in App Service pricing?
**A:** 
- **Compute resources** (CPU, memory, storage)
- **Built-in load balancing**
- **Auto-scaling capabilities**
- **SSL certificates** (managed)
- **Continuous deployment** features

## 🚨 Troubleshooting

### Q: Where do I find error logs?
**A:** Check these locations:
1. **Azure Portal** → App Service → Log stream
2. **Kudu Console** → `D:\home\LogFiles\`
3. **Application Insights** → Failures section
4. **Diagnostic Settings** → Custom logging

### Q: My application performance is poor
**A:** Review:
1. **App Service Plan tier** (CPU/memory limits)
2. **Database connection pooling** settings
3. **Application Insights** performance data
4. **CDN configuration** for static content
5. **Caching strategies** (Redis Cache)

### Q: How do I rollback a deployment?
**A:** Use **Deployment Slots**:
1. Deploy to staging slot first
2. Test functionality
3. Swap slots for zero-downtime deployment
4. Swap back if issues occur

## 📞 Getting Additional Help

### Q: Where can I get more support?
**A:** 
- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: Community questions and guidance
- **Azure Support**: Official Microsoft support plans
- **Microsoft Docs**: Comprehensive Azure documentation

### Q: How do I contribute to this project?
**A:** See our [Contributing Guide](CONTRIBUTING.md) for:
- Code contributions
- Documentation improvements
- Bug reports and feature requests
- Community support

---

**Can't find your answer?** [Ask the community](https://github.com/odaibert/delphi-azure-migration-toolkit/discussions) or [create an issue](https://github.com/odaibert/delphi-azure-migration-toolkit/issues)!
