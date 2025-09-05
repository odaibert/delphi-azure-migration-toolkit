# No-Code-Change ISAPI Migration Guide

This guide provides a comprehensive approach to migrate existing ISAPI DLLs from Windows Server + IIS to Azure App Service **without requiring any source code modifications**. The solution focuses on configuration, deployment packaging, and runtime environment preparation.

> 📖 **Microsoft Learn**: [Configure Windows Apps in Azure App Service](https://learn.microsoft.com/azure/app-service/configure-common)

## � **Migration Philosophy**

This toolkit enables **zero-code-change migration** by:
- **Environment Simulation**: Replicating Windows Server + IIS environment on Azure App Service
- **Runtime Compatibility**: Ensuring all dependencies and libraries are available
- **Configuration Translation**: Converting IIS configurations to Azure App Service equivalents
- **Path Mapping**: Translating file system paths transparently

### **Prerequisites Verification**

Before migration, verify your existing ISAPI DLL meets these requirements:

#### **Architecture Requirements**
1. **64-bit ISAPI DLL**: Azure App Service requires 64-bit applications
   ```powershell
   # Run dependency check script
   .\scripts\check-isapi-dependencies.ps1 -ISAPIPath "C:\path\to\YourISAPI.dll"
   ```

3. **IIS Configuration Backup**: Export current IIS settings
   ```powershell
   # Export IIS configuration
   %windir%\system32\inetsrv\appcmd.exe list config > current-iis-config.xml
   ```

## 📦 **Deployment Package Preparation**

### **1. Package Structure**
Create a deployment package with this exact structure:
```
deployment-package/
├── YourISAPI.dll              # Your existing ISAPI DLL (no changes needed)
├── web.config                 # Azure App Service configuration
├── dependencies/              # Required runtime libraries
│   ├── msvcp140.dll          # Visual C++ Runtime
│   ├── vcruntime140.dll      # Visual C++ Runtime
│   └── [other-dependencies]   # Additional DLLs identified by scanner
├── applicationHost.config     # IIS compatibility layer
└── assets/                    # Static files, if any
    ├── css/
    ├── js/
    └── images/
```

### **2. Runtime Dependencies Collection**
Use the automated dependency collector:
```powershell
# Collect all dependencies automatically
.\scripts\collect-dependencies.ps1 -ISAPIPath "YourISAPI.dll" -OutputPath "dependencies"
```

### **3. Configuration Translation**
Convert your existing IIS configuration to Azure App Service format:
```powershell
# Convert IIS config to Azure App Service web.config
.\scripts\convert-iis-config.ps1 -IISConfig "current-iis-config.xml" -Output "web.config"
```

## 🔧 **Environment Configuration**

### **1. Web.config for ISAPI (No Code Changes)**
Configure Azure App Service to run your existing ISAPI DLL:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <!-- ISAPI Filter Registration -->
    <isapiFilters>
      <filter name="YourISAPIFilter" 
              path="YourISAPI.dll" 
              enabled="true" />
    </isapiFilters>
    
    <!-- Handler Mapping for ISAPI Extension -->
    <handlers>
      <add name="YourISAPIHandler" 
           path="*.dll" 
           verb="GET,POST,PUT,DELETE" 
           modules="IsapiModule" 
           scriptProcessor="YourISAPI.dll" 
           resourceType="File" 
           preCondition="bitness64" />
    </handlers>
    
    <!-- Directory Structure Simulation -->
    <staticContent>
      <clientCache cacheControlMode="UseMaxAge" cacheControlMaxAge="30.00:00:00" />
    </staticContent>
    
    <!-- Request Filtering (preserve existing security) -->
    <security>
      <requestFiltering>
        <requestLimits maxAllowedContentLength="52428800" /> <!-- 50MB -->
        <fileExtensions>
          <add fileExtension=".dll" allowed="true" />
        </fileExtensions>
      </requestFiltering>
    </security>
    
    <!-- Path Translation for Azure App Service -->
    <rewrite>
      <rules>
        <!-- Map legacy paths to Azure paths -->
        <rule name="MapSharedFolder" stopProcessing="true">
          <match url="^shared/(.*)" />
          <action type="Rewrite" url="D:/home/shared/{R:1}" />
        </rule>
        <rule name="MapTempFolder" stopProcessing="true">
          <match url="^temp/(.*)" />
          <action type="Rewrite" url="D:/local/Temp/{R:1}" />
        </rule>
      </rules>
    </rewrite>
    
    <!-- Environment Variables for Path Mapping -->
    <environmentVariables>
      <add name="SHARED_FOLDER" value="D:\home\shared" />
      <add name="TEMP_FOLDER" value="D:\local\Temp" />
      <add name="DATA_FOLDER" value="D:\home\data" />
      <add name="LOG_FOLDER" value="D:\home\LogFiles" />
    </environmentVariables>
    
    <!-- Default Document -->
    <defaultDocument>
      <files>
        <clear />
        <add value="YourISAPI.dll" />
      </files>
    </defaultDocument>
  </system.webServer>
  
  <!-- App Settings Translation -->
  <appSettings>
    <!-- Copy your existing appSettings here -->
    <add key="ConnectionString" value="[Your existing connection string]" />
    <add key="DataPath" value="D:\home\data" />
    <add key="TempPath" value="D:\local\Temp" />
  </appSettings>
  
  <!-- Connection Strings -->
  <connectionStrings>
    <!-- Copy your existing connection strings here -->
  </connectionStrings>
</configuration>
```

### **2. Application Initialization (No DLL Changes)**
Create an initialization script that runs before your ISAPI DLL:

```xml
<!-- In web.config -->
<system.webServer>
  <applicationInitialization doAppInitAfterRestart="true">
    <add initializationPage="/initialize" />
  </applicationInitialization>
</system.webServer>
```

## 🌐 **Environment Compatibility Layer**

### **1. Registry Access Simulation**
If your ISAPI DLL reads from Windows Registry, create registry simulation:

```xml
<!-- In web.config -->
<appSettings>
  <!-- Simulate registry keys your ISAPI DLL expects -->
  <add key="HKEY_LOCAL_MACHINE\SOFTWARE\YourApp\Setting1" value="YourValue1" />
  <add key="HKEY_LOCAL_MACHINE\SOFTWARE\YourApp\Setting2" value="YourValue2" />
</appSettings>
```

### **2. Windows Service Simulation**
If your ISAPI DLL interacts with Windows Services, use Azure alternatives:

```xml
<!-- In web.config -->
<appSettings>
  <!-- Replace Windows Service endpoints with Azure Service Bus or HTTP APIs -->
  <add key="ServiceEndpoint" value="https://your-service-bus-namespace.servicebus.windows.net/" />
  <add key="ServiceToken" value="[Your Service Bus Token]" />
</appSettings>
```

### **3. File System Path Mapping**
Automatic path translation for your existing ISAPI DLL:

```xml
<!-- In applicationHost.config -->
<configuration>
  <system.webServer>
    <virtualDirectoryDefaults>
      <add key="physicalPath" value="D:\home\site\wwwroot" />
    </virtualDirectoryDefaults>
  </system.webServer>
</configuration>
```

## 📊 **Database Connectivity (No Code Changes)**

### **1. Connection String Translation**
Update connection strings in web.config without changing ISAPI code:

```xml
<!-- Replace SQL Server Windows Authentication -->
<connectionStrings>
  <!-- Before (Windows Server) -->
  <!-- <add name="DefaultConnection" connectionString="Server=localhost;Database=YourDB;Integrated Security=true;" /> -->
  
  <!-- After (Azure App Service) -->
  <add name="DefaultConnection" connectionString="Server=your-server.database.windows.net;Database=YourDB;Authentication=Active Directory Managed Identity;Encrypt=True;" />
</connectionStrings>
```

### **2. Database Driver Compatibility**
Ensure database drivers are included in deployment:

```
dependencies/
├── sqlncli11.dll      # SQL Server Native Client (if used)
├── msado15.dll        # ADO components (if used)
└── oledb32.dll        # OLE DB Provider (if used)
```

## 🚀 **Deployment Process (Automated)**

### **1. Pre-Deployment Validation**
```powershell
# Validate ISAPI DLL before deployment
.\scripts\validate-isapi-migration.ps1 -ISAPIPath "YourISAPI.dll" -ConfigPath "web.config"
```

### **2. Zero-Downtime Deployment**
```powershell
# Deploy to staging slot first
.\scripts\deploy-no-code-isapi.ps1 `
  -ResourceGroup "your-rg" `
  -AppService "your-app" `
  -PackagePath "deployment-package.zip" `
  -UseStaging
```

### **3. Post-Deployment Verification**
```powershell
# Verify ISAPI DLL is working
.\scripts\test-isapi-functionality.ps1 -AppServiceUrl "https://your-app.azurewebsites.net"
```
## 🔍 **Migration Troubleshooting**

### **Common Issues and Solutions**

#### **1. ISAPI DLL Not Loading**
```powershell
# Check if DLL architecture matches Azure App Service
dumpbin /headers YourISAPI.dll | findstr "machine"

# Verify all dependencies are present
.\scripts\check-isapi-dependencies.ps1 -ISAPIPath "YourISAPI.dll"
```

**Solution**: Ensure DLL is 64-bit and all dependencies are included in deployment package.

#### **2. File Path Issues**
If your ISAPI DLL uses hardcoded paths, create symbolic links:
```xml
<!-- In web.config -->
<system.webServer>
  <rewrite>
    <rules>
      <rule name="MapLegacyPaths">
        <match url="^C:/YourApp/(.*)" />
        <action type="Rewrite" url="D:/home/site/wwwroot/{R:1}" />
      </rule>
    </rules>
  </rewrite>
</system.webServer>
```

#### **3. Database Connection Failures**
Update connection strings for Azure SQL Database:
```xml
<!-- In web.config -->
<connectionStrings>
  <add name="DefaultConnection" 
       connectionString="Server=tcp:your-server.database.windows.net,1433;Database=YourDB;Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;" />
</connectionStrings>
```

#### **4. Registry Access Issues**
Simulate registry values using app settings:
```xml
<!-- In web.config -->
<appSettings>
  <!-- Map registry keys to app settings -->
  <add key="REG_SOFTWARE_YourApp_Setting1" value="YourValue1" />
  <add key="REG_SOFTWARE_YourApp_Setting2" value="YourValue2" />
</appSettings>
```

## 📋 **Migration Checklist**

### **Pre-Migration Validation**
- [ ] Verify ISAPI DLL is 64-bit compatible
- [ ] Identify all runtime dependencies
- [ ] Export current IIS configuration
- [ ] Document all registry keys used
- [ ] Identify file system paths used
- [ ] Test database connections from Azure

### **Package Preparation**
- [ ] Create deployment package structure
- [ ] Include all runtime dependencies
- [ ] Configure web.config for Azure App Service
- [ ] Set up environment variables
- [ ] Configure connection strings
- [ ] Include static assets (if any)

### **Azure App Service Setup**
- [ ] Create App Service with Windows plan
- [ ] Configure custom domain (if needed)
- [ ] Set up SSL certificates
- [ ] Configure authentication (if needed)
- [ ] Set up database connections
- [ ] Configure monitoring and logging

### **Deployment Process**
- [ ] Deploy to staging slot first
- [ ] Verify ISAPI DLL loads correctly
- [ ] Test all functionality
- [ ] Check performance metrics
- [ ] Swap to production
- [ ] Monitor for issues

### **Post-Migration Validation**
- [ ] Verify all ISAPI functions work
- [ ] Test database connectivity
- [ ] Validate file operations
- [ ] Check logging and monitoring
- [ ] Perform load testing
- [ ] Document any configuration changes

## 🎯 **Success Criteria**

Your no-code ISAPI migration is successful when:

✅ **ISAPI DLL loads without errors**  
✅ **All HTTP requests process correctly**  
✅ **Database connections work as expected**  
✅ **File operations complete successfully**  
✅ **Performance meets or exceeds current system**  
✅ **No functionality is lost in migration**  
✅ **Monitoring and logging are operational**

## 📞 **Support Resources**

### **Microsoft Documentation**
- [Configure Windows apps in Azure App Service](https://docs.microsoft.com/azure/app-service/configure-common)
- [ISAPI Extensions and Filters](https://docs.microsoft.com/iis/develop/runtime-extensibility/developing-isapi-extensions)

### **Azure App Service Specifics**
- [App Service file system](https://github.com/projectkudu/kudu/wiki/File-system)
- [Environment variables](https://docs.microsoft.com/azure/app-service/reference-app-settings)

### **Troubleshooting Tools**
- Use the dependency checker script for validation
- Monitor Application Insights for runtime issues
- Check Azure App Service logs for detailed errors

---

This guide ensures your existing ISAPI DLL can be migrated to Azure App Service with **zero code changes**, focusing entirely on configuration and environment setup.

```powershell
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates Delphi ISAPI dependencies for Azure deployment
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$DelphiProjectPath
)

Write-Host "🔍 Checking Delphi ISAPI Dependencies..." -ForegroundColor Green

$ProjectDir = Split-Path $DelphiProjectPath -Parent
$ProjectName = [System.IO.Path]::GetFileNameWithoutExtension($DelphiProjectPath)

# Check if compiled for 64-bit
$OutputPath = Join-Path $ProjectDir "Win64\Release\$ProjectName.dll"
if (-not (Test-Path $OutputPath)) {
    $OutputPath = Join-Path $ProjectDir "$ProjectName.dll"
}

if (Test-Path $OutputPath) {
    $FileInfo = Get-ItemProperty $OutputPath
    $PEHeader = [System.IO.File]::ReadAllBytes($OutputPath)[60..63]
    
    # Check PE header for 64-bit signature
    Write-Host "✅ Found compiled DLL: $OutputPath" -ForegroundColor Green
    Write-Host "ℹ️ File size: $([math]::Round($FileInfo.Length / 1MB, 2)) MB" -ForegroundColor Cyan
} else {
    Write-Host "❌ Compiled DLL not found. Ensure project is built for Win64 platform." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Delphi ISAPI validation completed successfully!" -ForegroundColor Green
```

## 📦 **Compilation Automation**

### **Build Script Template**
Save as `scripts\build-delphi-isapi.ps1`:

```powershell
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Automated Delphi ISAPI compilation for Azure deployment
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,
    
    [Parameter(Mandatory = $false)]
    [string]$DelphiPath = "C:\Program Files (x86)\Embarcadero\Studio\22.0\bin\dcc64.exe"
)

if (-not (Test-Path $DelphiPath)) {
    Write-Error "Delphi compiler not found at: $DelphiPath"
    exit 1
}

$ProjectDir = Split-Path $ProjectPath -Parent
$ProjectName = [System.IO.Path]::GetFileNameWithoutExtension($ProjectPath)

Write-Host "🏗️ Building Delphi ISAPI for Azure App Service..." -ForegroundColor Green
Write-Host "Project: $ProjectName" -ForegroundColor Cyan
Write-Host "Path: $ProjectPath" -ForegroundColor Cyan

# Compile for 64-bit
$CompileArgs = @(
    "-B"                    # Build all
    "-Q"                    # Quiet compile
    "-E`"deployment`""      # Output to deployment folder
    "-N`"temp`""            # DCU output path
    "`"$ProjectPath`""      # Project file
)

Write-Host "Executing: $DelphiPath $($CompileArgs -join ' ')" -ForegroundColor Yellow

$Process = Start-Process -FilePath $DelphiPath -ArgumentList $CompileArgs -Wait -PassThru -NoNewWindow

if ($Process.ExitCode -eq 0) {
    Write-Host "✅ Compilation successful!" -ForegroundColor Green
    
    # Verify output
    $OutputDLL = Join-Path "deployment" "$ProjectName.dll"
    if (Test-Path $OutputDLL) {
        $FileSize = (Get-Item $OutputDLL).Length
        Write-Host "✅ Output DLL: $OutputDLL ($([math]::Round($FileSize / 1KB, 2)) KB)" -ForegroundColor Green
    }
} else {
    Write-Host "❌ Compilation failed with exit code: $($Process.ExitCode)" -ForegroundColor Red
    exit $Process.ExitCode
}
```

## 🧪 **Local Testing Framework**

### **Test ISAPI Locally**
```powershell
# Test ISAPI filter locally before Azure deployment
$TestScript = @"
.\scripts\build-delphi-isapi.ps1 -ProjectPath "YourProject.dpr"
.\scripts\check-delphi-dependencies.ps1 -DelphiProjectPath "YourProject.dpr"

# Deploy to local IIS for testing
Import-Module IISAdministration
New-IISSite -Name "ISAPI-Test" -PhysicalPath "deployment" -Port 8080
"@

Write-Output $TestScript | Out-File "scripts\test-locally.ps1" -Encoding UTF8
```

## 📋 **Migration Checklist**

### **Pre-Migration Delphi Code Review**
- [ ] Project compiled for **Win64** platform
- [ ] No **registry dependencies** (use App Settings instead)
- [ ] **File paths** converted to Azure App Service locations
- [ ] **Database connections** use Azure SQL connection strings
- [ ] **No Windows services** dependencies
- [ ] **No COM/DCOM** dependencies
- [ ] **Error handling** includes Azure-specific scenarios
- [ ] **Logging** uses Application Insights instead of Windows Event Log

### **Performance Optimization**
- [ ] **Connection pooling** configured for database access
- [ ] **Static resources** moved to Azure Storage/CDN
- [ ] **Caching strategies** implemented
- [ ] **Memory management** optimized for cloud environment

## 🆘 **Troubleshooting Common Issues**

### **"Module not found" Errors**
- Verify all **dependent DLLs** are included in deployment
- Check **Visual C++ Redistributables** are available
- Ensure **64-bit versions** of all dependencies

### **Database Connection Failures**
- Verify **Azure SQL Database** firewall rules allow App Service
- Check **connection string format** matches Azure requirements
- Test **connection pooling** configuration

### **File System Access Errors**
- Use only **Azure App Service writable directories**
- Implement **Azure Files integration** for shared storage
- Handle **read-only file system** restrictions

---

> 📖 **Next Steps**: After compilation, use the main deployment scripts in the `deployment/` folder to deploy your Delphi ISAPI filter to Azure App Service.
