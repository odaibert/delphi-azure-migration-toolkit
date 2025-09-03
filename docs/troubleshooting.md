# Troubleshooting Guide - ISAPI Filter on Azure App Service

This guide helps you diagnose and resolve common issues when migrating Delphi 6 ISAPI filters to Azure App Service.

## 🚨 Common Issues and Solutions

### 1. ISAPI DLL Not Loading

#### Symptoms:
- HTTP 404 errors when accessing the DLL directly
- "The specified module could not be found" errors
- Application event log shows DLL loading failures

#### Solutions:

**Check DLL Architecture:**
```powershell
# Verify your DLL is 64-bit compiled
file YourISAPIFilter.dll
# Should show "PE32+ executable" for 64-bit
```

**Verify DLL Dependencies:**
```powershell
# Use Dependency Walker or similar tool to check missing dependencies
# Common missing dependencies:
# - MSVCRT libraries
# - Delphi runtime libraries
# - Custom third-party DLLs
```

**App Service Configuration:**
- Ensure `use32BitWorkerProcess` is set to `false` in web.config
- Verify the App Service Plan supports 64-bit applications

### 2. HTTP 500 Internal Server Error

#### Symptoms:
- DLL loads but returns 500 errors
- Detailed error messages in App Service logs
- Application crashes or hangs

#### Solutions:

**Enable Detailed Errors:**
```xml
<!-- In web.config -->
<system.web>
  <customErrors mode="Off" />
</system.web>
<system.webServer>
  <httpErrors errorMode="Detailed" />
</system.webServer>
```

**Check Application Logs:**
```powershell
# Stream logs in real-time
az webapp log tail --name your-app-service --resource-group your-rg

# Download log files
az webapp log download --name your-app-service --resource-group your-rg
```

**Common Causes:**
- Missing write permissions to temp directories
- Database connection failures
- Registry access (not available in App Service)
- File path issues (different from IIS on-premises)

### 3. Shared Folder Access Issues

#### Symptoms:
- File not found errors
- Access denied when reading/writing files
- Legacy UNC path failures

#### Solutions:

**Use Azure Files:**
```powershell
# Mount Azure Files as a network drive
$storageAccount = "yourstorageaccount"
$fileShare = "isapi-shared-folder"
$accessKey = "your-storage-key"

# Set application settings in App Service
az webapp config appsettings set --name your-app-service --resource-group your-rg --settings `
  SHARED_FOLDER_CONNECTION="DefaultEndpointsProtocol=https;AccountName=$storageAccount;AccountKey=$accessKey;EndpointSuffix=core.windows.net" `
  SHARED_FOLDER_NAME="$fileShare"
```

**Update ISAPI Code (if possible):**
```pascal
// Instead of hardcoded paths like 'C:\SharedFolder\'
// Use environment variables or app settings
function GetSharedFolderPath: string;
begin
  Result := GetEnvironmentVariable('SHARED_FOLDER_PATH');
  if Result = '' then
    Result := 'D:\home\shared\'; // Default path in App Service
end;
```

### 4. Performance Issues

#### Symptoms:
- Slow response times
- High CPU or memory usage
- Application restarts frequently

#### Solutions:

**Optimize App Service Plan:**
```powershell
# Scale up to higher SKU
az appservice plan update --name your-plan --resource-group your-rg --sku P1v2

# Enable Always On
az webapp config set --name your-app-service --resource-group your-rg --always-on true
```

**Monitor Performance:**
```powershell
# View performance metrics
az monitor metrics list --resource /subscriptions/your-sub/resourceGroups/your-rg/providers/Microsoft.Web/sites/your-app-service --metric-names CpuPercentage,MemoryPercentage
```

**Application Insights:**
- Enable Application Insights for detailed telemetry
- Monitor dependencies and external calls
- Identify bottlenecks in ISAPI processing

### 5. Security and Authentication Issues

#### Symptoms:
- Authentication failures
- Authorization errors
- SSL/TLS certificate issues

#### Solutions:

**Configure Authentication:**
```xml
<!-- In web.config -->
<system.web>
  <authentication mode="None" />
  <!-- Or configure appropriate authentication mode -->
</system.web>
```

**SSL Configuration:**
```powershell
# Force HTTPS
az webapp update --name your-app-service --resource-group your-rg --https-only true

# Configure custom domain with SSL
az webapp config hostname add --webapp-name your-app-service --resource-group your-rg --hostname your-domain.com
```

### 6. Database Connectivity Issues

#### Symptoms:
- Database connection timeouts
- Authentication failures to SQL Server
- Connection string errors

#### Solutions:

**Use Azure SQL Database:**
```xml
<!-- In web.config -->
<connectionStrings>
  <add name="DefaultConnection" 
       connectionString="Server=tcp:your-server.database.windows.net,1433;Initial Catalog=your-db;Persist Security Info=False;User ID=your-user;Password=your-password;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;" 
       providerName="System.Data.SqlClient" />
</connectionStrings>
```

**Firewall Configuration:**
```powershell
# Add App Service IP to SQL Server firewall
az sql server firewall-rule create --resource-group your-rg --server your-sql-server --name "AppService" --start-ip-address 0.0.0.0 --end-ip-address 255.255.255.255
```

## 🔧 Debugging Tools and Techniques

### Enable Detailed Logging

1. **Application Logging:**
```powershell
az webapp log config --name your-app-service --resource-group your-rg --application-logging true --level information
```

2. **Web Server Logging:**
```powershell
az webapp log config --name your-app-service --resource-group your-rg --web-server-logging true
```

3. **Failed Request Tracing:**
```powershell
az webapp log config --name your-app-service --resource-group your-rg --failed-request-tracing true
```

### Access Kudu Console

```powershell
# Open Kudu (Advanced Tools)
az webapp browse --name your-app-service --resource-group your-rg --logs
# Navigate to: https://your-app-service.scm.azurewebsites.net
```

In Kudu, you can:
- Browse the file system (`/site/wwwroot`)
- View process list and resource usage
- Access debug console
- Download log files

### Monitor Resource Usage

```powershell
# Real-time metrics
az webapp show --name your-app-service --resource-group your-rg --query "siteConfig.{AlwaysOn:alwaysOn,Use32Bit:use32BitWorkerProcess}"

# Historical metrics
az monitor metrics list --resource "/subscriptions/your-sub/resourceGroups/your-rg/providers/Microsoft.Web/sites/your-app-service" --metric-names "CpuPercentage,MemoryPercentage,Http5xx,ResponseTime"
```

## 📋 Diagnostic Checklist

### Pre-Migration Checklist

- [ ] ISAPI DLL compiled for x64 architecture
- [ ] All dependencies available or can be deployed
- [ ] Database connections tested with Azure connection strings
- [ ] File system operations don't rely on specific Windows paths
- [ ] No registry dependencies
- [ ] No COM/DCOM dependencies
- [ ] Performance tested under expected load

### Post-Migration Verification

- [ ] Basic connectivity test passes
- [ ] ISAPI DLL loads successfully
- [ ] Core functionality works
- [ ] File access (if applicable) works
- [ ] Database connections established
- [ ] Performance meets requirements
- [ ] Error handling works properly
- [ ] Logging is functional

### Security Checklist

- [ ] HTTPS enforced
- [ ] Sensitive files protected (web.config, etc.)
- [ ] Database connections use secure authentication
- [ ] No hardcoded credentials
- [ ] Proper error handling (no sensitive info in errors)
- [ ] File upload restrictions in place

## 🆘 Getting Help

### Azure Support Resources

1. **Azure Documentation:**
   - [App Service documentation](https://docs.microsoft.com/azure/app-service/)
   - [IIS on App Service](https://docs.microsoft.com/azure/app-service/configure-common)

2. **Community Forums:**
   - [Microsoft Q&A](https://docs.microsoft.com/answers/)
   - [Stack Overflow](https://stackoverflow.com/questions/tagged/azure-app-service)

3. **Azure Support:**
   - Create support ticket in Azure Portal
   - Use Azure Advisor recommendations

### Logs to Collect for Support

When contacting support, gather these logs:

```powershell
# Download all available logs
az webapp log download --name your-app-service --resource-group your-rg

# Get deployment logs
az webapp deployment list --name your-app-service --resource-group your-rg

# Export App Service configuration
az webapp config show --name your-app-service --resource-group your-rg > app-config.json
az webapp config appsettings list --name your-app-service --resource-group your-rg > app-settings.json
```

## 📊 Performance Optimization

### App Service Plan Optimization

```powershell
# Monitor current usage
az monitor metrics list --resource "/subscriptions/your-sub/resourceGroups/your-rg/providers/Microsoft.Web/serverfarms/your-plan" --metric-names "CpuPercentage,MemoryPercentage"

# Scale up if needed
az appservice plan update --name your-plan --resource-group your-rg --sku P2v2

# Enable auto-scaling
az monitor autoscale create --resource-group your-rg --resource "/subscriptions/your-sub/resourceGroups/your-rg/providers/Microsoft.Web/serverfarms/your-plan" --name autoscale-plan --min-count 1 --max-count 3 --count 1
```

### Application-Level Optimization

- **Connection Pooling:** Ensure database connections are properly pooled
- **Caching:** Implement appropriate caching strategies
- **Static Content:** Use Azure CDN for static files
- **Code Optimization:** Profile and optimize ISAPI filter code

---

Remember: Migration to cloud often requires some code changes for optimal performance and compatibility. Consider modernizing to ASP.NET Core for better cloud-native support in the long term.
