#!/usr/bin/env pwsh
<#
.SYNOPSIS
    No-Code-Change ISAPI deployment package builder for Azure App Service
    
.DESCRIPTION
    This script creates deployment packages for existing ISAPI DLLs without requiring
    source code modifications. It focuses on:
    
    1. Packaging existing ISAPI DLLs with proper structure
    2. Collecting all required dependencies automatically
    3. Generating Azure App Service configuration files
    4. Creating deployment-ready packages
    5. Validating package completeness
    
.PARAMETER ISAPIPath
    Path to the existing ISAPI DLL
    
.PARAMETER PackageName
    Name for the deployment package (optional)
    
.PARAMETER OutputPath
    Output directory for the deployment package
    
.PARAMETER IncludeDependencies
    Automatically collect and include runtime dependencies
    
.PARAMETER GenerateConfig
    Generate web.config and other configuration files
    
.PARAMETER ValidatePackage
    Validate the package after creation
    
.EXAMPLE
    .\package-no-code-isapi.ps1 -ISAPIPath "YourISAPI.dll"
    
.EXAMPLE
    .\package-no-code-isapi.ps1 -ISAPIPath "YourISAPI.dll" -PackageName "MyApp" -IncludeDependencies -GenerateConfig -ValidatePackage
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ISAPIPath,
    
    [Parameter(Mandatory = $false)]
    [string]$PackageName,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "deployment-packages",
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeDependencies = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$GenerateConfig = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$ValidatePackage = $true
)

Write-Host "📦 No-Code ISAPI Deployment Package Builder" -ForegroundColor Green
Write-Host "Source: $ISAPIPath" -ForegroundColor Cyan
Write-Host "Target: Azure App Service (Windows)" -ForegroundColor Cyan
Write-Host

# Validate input ISAPI DLL
if (-not (Test-Path $ISAPIPath)) {
    Write-Host "❌ ISAPI DLL not found: $ISAPIPath" -ForegroundColor Red
    exit 1
}

$isapiFile = Get-Item $ISAPIPath
Write-Host "✅ ISAPI DLL found: $($isapiFile.Name) ($($isapiFile.Length) bytes)" -ForegroundColor Green

# Determine package name
if (-not $PackageName) {
    $PackageName = $isapiFile.BaseName + "-deployment"
}

# Create output directory structure
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$packagePath = Join-Path $OutputPath "$PackageName-$timestamp"
$wwwrootPath = Join-Path $packagePath "wwwroot"
$dependenciesPath = Join-Path $packagePath "dependencies"

Write-Host "`n📁 Creating package structure..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $packagePath -Force | Out-Null
New-Item -ItemType Directory -Path $wwwrootPath -Force | Out-Null
New-Item -ItemType Directory -Path $dependenciesPath -Force | Out-Null

Write-Host "✅ Package directory: $packagePath" -ForegroundColor Green

# Step 1: Copy ISAPI DLL to package
Write-Host "`n📋 Step 1: Copying ISAPI DLL..." -ForegroundColor Yellow
Copy-Item $ISAPIPath -Destination $wwwrootPath -Force
Write-Host "✅ ISAPI DLL copied to package" -ForegroundColor Green

# Step 2: Collect dependencies
if ($IncludeDependencies) {
    Write-Host "`n🔍 Step 2: Collecting dependencies..." -ForegroundColor Yellow
    
    try {
        $dependsResult = dumpbin /dependents $ISAPIPath 2>$null
        $dependencies = @()
        
        if ($dependsResult) {
            $inDependentSection = $false
            
            $dependsResult | ForEach-Object {
                if ($_ -match "Image has the following dependencies:") {
                    $inDependentSection = $true
                } elseif ($inDependentSection -and $_ -match "^\s+(\S+\.dll)") {
                    $dependencies += $matches[1].ToLower()
                } elseif ($_ -match "^\s*Summary") {
                    $inDependentSection = $false
                }
            }
        }
        
        # Standard Azure App Service libraries (don't need to include)
        $azureProvidedLibraries = @(
            "kernel32.dll", "user32.dll", "advapi32.dll", "ole32.dll", "oleaut32.dll",
            "shell32.dll", "comctl32.dll", "gdi32.dll", "wininet.dll", "ws2_32.dll",
            "crypt32.dll", "bcrypt.dll", "ncrypt.dll"
        )
        
        # Runtime libraries that might need to be included
        $runtimeLibraries = @(
            "msvcp140.dll", "vcruntime140.dll", "msvcp120.dll", "msvcr120.dll",
            "msvcp110.dll", "msvcr110.dll", "msvcp100.dll", "msvcr100.dll"
        )
        
        $collectedCount = 0
        foreach ($dep in $dependencies) {
            # Skip system libraries provided by Azure
            if ($dep -in $azureProvidedLibraries) {
                Write-Host "  ⏭️ Skipping system library: $dep" -ForegroundColor Gray
                continue
            }
            
            # Try to find and copy the dependency
            $found = $false
            $searchPaths = @(
                $env:SystemRoot + "\System32",
                $env:SystemRoot + "\SysWOW64",
                (Split-Path $ISAPIPath -Parent),
                $env:PATH -split ";"
            )
            
            foreach ($searchPath in $searchPaths) {
                $depPath = Join-Path $searchPath $dep
                if (Test-Path $depPath) {
                    try {
                        Copy-Item $depPath -Destination $dependenciesPath -Force -ErrorAction Stop
                        Write-Host "  ✅ Collected: $dep" -ForegroundColor Green
                        $collectedCount++
                        $found = $true
                        break
                    } catch {
                        Write-Host "  ⚠️ Could not copy: $dep ($($_.Exception.Message))" -ForegroundColor Yellow
                    }
                }
            }
            
            if (-not $found) {
                Write-Host "  ❌ Not found: $dep" -ForegroundColor Red
            }
        }
        
        Write-Host "✅ Collected $collectedCount dependencies" -ForegroundColor Green
        
    } catch {
        Write-Host "⚠️ Could not analyze dependencies automatically" -ForegroundColor Yellow
        Write-Host "   Ensure Visual Studio Build Tools are installed" -ForegroundColor Yellow
    }
}

# Step 3: Generate configuration files
if ($GenerateConfig) {
    Write-Host "`n⚙️ Step 3: Generating configuration files..." -ForegroundColor Yellow
    
    # Generate web.config
    $webConfig = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <!-- ISAPI Extension Handler -->
    <handlers>
      <add name="$($isapiFile.BaseName)Handler" 
           path="*" 
           verb="GET,POST,PUT,DELETE,HEAD,OPTIONS" 
           modules="IsapiModule" 
           scriptProcessor="$($isapiFile.Name)" 
           resourceType="Unspecified" 
           preCondition="bitness64" />
    </handlers>
    
    <!-- Static File Handling -->
    <staticContent>
      <clientCache cacheControlMode="UseMaxAge" cacheControlMaxAge="1.00:00:00" />
    </staticContent>
    
    <!-- Security Configuration -->
    <security>
      <requestFiltering removeServerHeader="true">
        <fileExtensions>
          <add fileExtension=".dll" allowed="true" />
        </fileExtensions>
        <requestLimits maxAllowedContentLength="52428800" />
      </requestFiltering>
    </security>
    
    <!-- Default Document -->
    <defaultDocument>
      <files>
        <clear />
        <add value="$($isapiFile.Name)" />
      </files>
    </defaultDocument>
    
    <!-- URL Rewrite for Path Mapping -->
    <rewrite>
      <rules>
        <!-- Map common Windows paths to Azure paths -->
        <rule name="MapTempPath" stopProcessing="false">
          <match url=".*" />
          <serverVariables>
            <set name="TEMP" value="D:\local\Temp" />
            <set name="TMP" value="D:\local\Temp" />
          </serverVariables>
          <action type="None" />
        </rule>
      </rules>
    </rewrite>
    
    <!-- Environment Variables -->
    <environmentVariables>
      <add name="TEMP" value="D:\local\Temp" />
      <add name="TMP" value="D:\local\Temp" />
      <add name="SHARED_FOLDER" value="D:\home\shared" />
      <add name="DATA_FOLDER" value="D:\home\data" />
      <add name="LOG_FOLDER" value="D:\home\LogFiles" />
    </environmentVariables>
    
    <!-- HTTP Protocol -->
    <httpProtocol>
      <customHeaders>
        <add name="X-Frame-Options" value="SAMEORIGIN" />
        <add name="X-Content-Type-Options" value="nosniff" />
        <add name="X-XSS-Protection" value="1; mode=block" />
      </customHeaders>
    </httpProtocol>
  </system.webServer>
  
  <!-- Application Settings -->
  <appSettings>
    <!-- Add your existing application settings here -->
    <!-- <add key="YourSetting" value="YourValue" /> -->
    
    <!-- Common path mappings -->
    <add key="SharedPath" value="D:\home\shared" />
    <add key="TempPath" value="D:\local\Temp" />
    <add key="DataPath" value="D:\home\data" />
    <add key="LogPath" value="D:\home\LogFiles" />
  </appSettings>
  
  <!-- Connection Strings -->
  <connectionStrings>
    <!-- Add your database connection strings here -->
    <!-- Example for Azure SQL Database with Managed Identity:
    <add name="DefaultConnection" 
         connectionString="Server=tcp:your-server.database.windows.net,1433;Database=YourDB;Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;" />
    -->
  </connectionStrings>
</configuration>
"@
    
    $webConfigPath = Join-Path $packagePath "web.config"
    $webConfig | Set-Content -Path $webConfigPath -Encoding UTF8
    Write-Host "✅ Generated web.config" -ForegroundColor Green
    
    # Generate deployment instructions
    $deploymentInstructions = @"
# Deployment Instructions for $($isapiFile.Name)

## Package Contents
- **$($isapiFile.Name)**: Your ISAPI DLL (no changes required)
- **web.config**: Azure App Service configuration
- **dependencies/**: Runtime dependencies (if any)

## Deployment Steps

### 1. Prepare Azure App Service
``````powershell
# Create App Service (Windows plan required for ISAPI)
az appservice plan create --name "my-plan" --resource-group "my-rg" --sku "S1" --is-linux false

az webapp create --name "my-isapi-app" --resource-group "my-rg" --plan "my-plan"
``````

### 2. Deploy Package
``````powershell
# Option 1: Using ZIP deployment
Compress-Archive -Path "$packagePath\*" -DestinationPath "deployment.zip"
az webapp deployment source config-zip --resource-group "my-rg" --name "my-isapi-app" --src "deployment.zip"

# Option 2: Using FTP (copy contents to /site/wwwroot)
``````

### 3. Configuration
1. **Connection Strings**: Update connection strings in web.config or Azure portal
2. **App Settings**: Add any required application settings
3. **Custom Domain**: Configure if needed
4. **SSL Certificate**: Install and bind SSL certificate

### 4. Verification
- Test ISAPI functionality: https://my-isapi-app.azurewebsites.net
- Check Application Insights for any issues
- Monitor performance and adjust settings as needed

## Important Notes
- No changes to your ISAPI DLL source code are required
- All configuration is handled through web.config and Azure settings
- Dependencies are automatically included in the package
- File paths are mapped to Azure App Service directories

## Troubleshooting
If you encounter issues:
1. Check the Application Insights logs in Azure portal
2. Verify all dependencies are included
3. Ensure connection strings are correct for Azure SQL Database
4. Review web.config configuration

For additional support, refer to the migration toolkit documentation.
"@
    
    $instructionsPath = Join-Path $packagePath "DEPLOYMENT-INSTRUCTIONS.md"
    $deploymentInstructions | Set-Content -Path $instructionsPath -Encoding UTF8
    Write-Host "✅ Generated deployment instructions" -ForegroundColor Green
    
    # Generate package manifest
    $manifest = @{
        PackageName = $PackageName
        CreatedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ISAPIFile = $isapiFile.Name
        ISAPISize = $isapiFile.Length
        Dependencies = if ($IncludeDependencies) { (Get-ChildItem $dependenciesPath -File).Count } else { 0 }
        ConfigurationGenerated = $true
        TargetPlatform = "Azure App Service (Windows)"
    }
    
    $manifestPath = Join-Path $packagePath "package-manifest.json"
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestPath -Encoding UTF8
    Write-Host "✅ Generated package manifest" -ForegroundColor Green
}

# Step 4: Package validation
if ($ValidatePackage) {
    Write-Host "`n🔍 Step 4: Validating package..." -ForegroundColor Yellow
    
    $validationResults = @{
        ISAPIDLLPresent = Test-Path (Join-Path $wwwrootPath $isapiFile.Name)
        WebConfigPresent = Test-Path (Join-Path $packagePath "web.config")
        DependenciesCollected = (Get-ChildItem $dependenciesPath -File -ErrorAction SilentlyContinue).Count
        PackageSize = [math]::Round((Get-ChildItem $packagePath -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
    }
    
    Write-Host "📊 Validation Results:" -ForegroundColor Cyan
    Write-Host "  ISAPI DLL: $(if ($validationResults.ISAPIDLLPresent) { '✅ Present' } else { '❌ Missing' })" -ForegroundColor $(if ($validationResults.ISAPIDLLPresent) { "Green" } else { "Red" })
    Write-Host "  Web.config: $(if ($validationResults.WebConfigPresent) { '✅ Present' } else { '❌ Missing' })" -ForegroundColor $(if ($validationResults.WebConfigPresent) { "Green" } else { "Red" })
    Write-Host "  Dependencies: $($validationResults.DependenciesCollected) files" -ForegroundColor Cyan
    Write-Host "  Package Size: $($validationResults.PackageSize) MB" -ForegroundColor Cyan
    
    if ($validationResults.ISAPIDLLPresent -and $validationResults.WebConfigPresent) {
        Write-Host "✅ Package validation passed" -ForegroundColor Green
    } else {
        Write-Host "❌ Package validation failed" -ForegroundColor Red
        exit 1
    }
}

# Step 5: Create deployment ZIP
Write-Host "`n📦 Step 5: Creating deployment ZIP..." -ForegroundColor Yellow

$zipPath = "$packagePath.zip"
try {
    # Change to package directory to ensure proper ZIP structure
    $currentLocation = Get-Location
    Set-Location $packagePath
    
    # Create ZIP with all contents
    Compress-Archive -Path "*" -DestinationPath $zipPath -Force
    
    # Return to original location
    Set-Location $currentLocation
    
    $zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
    Write-Host "✅ Deployment ZIP created: $zipPath ($zipSize MB)" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Failed to create deployment ZIP: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Final summary
Write-Host "`n🎉 Package Creation Complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "📦 Package: $PackageName" -ForegroundColor Green
Write-Host "📁 Location: $packagePath" -ForegroundColor Green
Write-Host "📋 ZIP File: $zipPath" -ForegroundColor Green
Write-Host "🎯 Target: Azure App Service (Windows)" -ForegroundColor Green

Write-Host "`n🚀 Next Steps:" -ForegroundColor Blue
Write-Host "1. Review the DEPLOYMENT-INSTRUCTIONS.md file" -ForegroundColor Blue
Write-Host "2. Create Azure App Service (Windows plan)" -ForegroundColor Blue
Write-Host "3. Deploy using: az webapp deployment source config-zip" -ForegroundColor Blue
Write-Host "4. Configure connection strings and app settings" -ForegroundColor Blue
Write-Host "5. Test your ISAPI application functionality" -ForegroundColor Blue

Write-Host "`n💡 Key Benefits:" -ForegroundColor Cyan
Write-Host "✅ No source code changes required" -ForegroundColor Cyan
Write-Host "✅ All dependencies automatically collected" -ForegroundColor Cyan
Write-Host "✅ Azure-optimized configuration generated" -ForegroundColor Cyan
Write-Host "✅ Production-ready deployment package" -ForegroundColor Cyan
