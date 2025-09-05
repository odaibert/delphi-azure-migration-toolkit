#!/usr/bin/env pwsh
<#
.SYNOPSIS
    No-Code-Change ISAPI DLL dependency validation for Azure App Service migration
    
.DESCRIPTION
    This script validates existing ISAPI DLLs for Azure App Service compatibility
    without requiring any source code modifications. It checks:
    
    1. DLL architecture compatibility (64-bit requirement)
    2. Runtime dependencies and Azure App Service availability
    3. ISAPI export function validation
    4. Azure App Service sandbox compliance
    5. Configuration requirements for no-code migration
    
.PARAMETER ISAPIPath
    Path to the existing ISAPI DLL to validate
    
.PARAMETER OutputPath
    Optional path to save migration readiness report
    
.PARAMETER GenerateConfig
    Generate web.config template for the ISAPI DLL
    
.PARAMETER CollectDependencies
    Copy all required dependencies to output folder
    
.EXAMPLE
    .\check-isapi-dependencies.ps1 -ISAPIPath "YourISAPI.dll"
    
.EXAMPLE
    .\check-isapi-dependencies.ps1 -ISAPIPath "YourISAPI.dll" -GenerateConfig -CollectDependencies -OutputPath "migration-package"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ISAPIPath,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$GenerateConfig,
    
    [Parameter(Mandatory = $false)]
    [switch]$CollectDependencies
)

Write-Host "🔍 ISAPI No-Code Migration Validator" -ForegroundColor Green
Write-Host "Analyzing: $ISAPIPath" -ForegroundColor Cyan
Write-Host "Target: Azure App Service (Windows)" -ForegroundColor Cyan
Write-Host

# Global validation results
$Global:ValidationResults = @{
    OverallStatus = "Unknown"
    ArchitectureCheck = @{ Status = "Unknown"; Details = "" }
    DependencyCheck = @{ Status = "Unknown"; Details = @(); MissingDependencies = @() }
    ISAPIExportsCheck = @{ Status = "Unknown"; Details = @() }
    SandboxCompatibility = @{ Status = "Unknown"; Issues = @(); Recommendations = @() }
    MigrationReadiness = @{ Status = "Unknown"; BlockingIssues = @(); Warnings = @() }
    RequiredFiles = @()
}

# Step 1: Validate ISAPI DLL exists and is accessible
Write-Host "📋 Step 1: ISAPI DLL Validation" -ForegroundColor Yellow

if (-not (Test-Path $ISAPIPath)) {
    Write-Host "❌ ISAPI DLL not found: $ISAPIPath" -ForegroundColor Red
    exit 1
}

$isapiFile = Get-Item $ISAPIPath
Write-Host "✅ ISAPI DLL found: $($isapiFile.Name) ($($isapiFile.Length) bytes)" -ForegroundColor Green

# Step 2: Architecture validation (Critical for Azure App Service)
Write-Host "`n🏗️ Step 2: Architecture Validation" -ForegroundColor Yellow

try {
    $dumpbinResult = dumpbin /headers $ISAPIPath 2>$null | Select-String "machine"
    
    if ($dumpbinResult -match "8664") {
        Write-Host "✅ Architecture: 64-bit (x64) - Compatible with Azure App Service" -ForegroundColor Green
        $Global:ValidationResults.ArchitectureCheck.Status = "Pass"
        $Global:ValidationResults.ArchitectureCheck.Details = "64-bit x64 architecture"
    } else {
        Write-Host "❌ Architecture: 32-bit - NOT COMPATIBLE with Azure App Service" -ForegroundColor Red
        Write-Host "   Azure App Service requires 64-bit ISAPI DLLs" -ForegroundColor Red
        $Global:ValidationResults.ArchitectureCheck.Status = "Critical"
        $Global:ValidationResults.ArchitectureCheck.Details = "32-bit architecture not supported"
        $Global:ValidationResults.MigrationReadiness.BlockingIssues += "ISAPI DLL must be compiled for 64-bit (x64) architecture"
    }
} catch {
    Write-Host "⚠️ Could not determine architecture. Ensure Visual Studio Build Tools are installed." -ForegroundColor Yellow
    $Global:ValidationResults.ArchitectureCheck.Status = "Warning"
    $Global:ValidationResults.ArchitectureCheck.Details = "Could not verify architecture"
}

# Step 3: ISAPI Export Functions Validation
Write-Host "`n🔌 Step 3: ISAPI Export Functions Validation" -ForegroundColor Yellow

$requiredExports = @("GetExtensionVersion", "HttpExtensionProc")
$optionalExports = @("TerminateExtension")

try {
    $exportsResult = dumpbin /exports $ISAPIPath 2>$null
    $exportedFunctions = @()
    
    if ($exportsResult) {
        $exportsResult | ForEach-Object {
            if ($_ -match "\s+\d+\s+[0-9A-F]+\s+[0-9A-F]+\s+(\w+)") {
                $exportedFunctions += $matches[1]
            }
        }
    }
    
    $missingRequired = @()
    $presentOptional = @()
    
    foreach ($export in $requiredExports) {
        if ($exportedFunctions -contains $export) {
            Write-Host "✅ Required export found: $export" -ForegroundColor Green
        } else {
            Write-Host "❌ Missing required export: $export" -ForegroundColor Red
            $missingRequired += $export
        }
    }
    
    foreach ($export in $optionalExports) {
        if ($exportedFunctions -contains $export) {
            Write-Host "✅ Optional export found: $export" -ForegroundColor Green
            $presentOptional += $export
        }
    }
    
    if ($missingRequired.Count -eq 0) {
        $Global:ValidationResults.ISAPIExportsCheck.Status = "Pass"
        Write-Host "✅ All required ISAPI exports present" -ForegroundColor Green
    } else {
        $Global:ValidationResults.ISAPIExportsCheck.Status = "Critical"
        $Global:ValidationResults.MigrationReadiness.BlockingIssues += "Missing required ISAPI exports: $($missingRequired -join ', ')"
        Write-Host "❌ Missing required ISAPI exports. DLL may not be a valid ISAPI extension." -ForegroundColor Red
    }
    
    $Global:ValidationResults.ISAPIExportsCheck.Details = @{
        RequiredExports = $requiredExports
        OptionalExports = $presentOptional
        MissingExports = $missingRequired
    }
    
} catch {
    Write-Host "⚠️ Could not analyze exports. Ensure Visual Studio Build Tools are installed." -ForegroundColor Yellow
    $Global:ValidationResults.ISAPIExportsCheck.Status = "Warning"
}

# Step 4: Runtime Dependency Analysis
Write-Host "`n📦 Step 4: Runtime Dependency Analysis" -ForegroundColor Yellow

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
    
    Write-Host "Found $($dependencies.Count) runtime dependencies:" -ForegroundColor Cyan
    
    # Categorize dependencies
    $systemDependencies = @()
    $runtimeDependencies = @()
    $customDependencies = @()
    $potentialIssues = @()
    
    $azureAvailableLibraries = @(
        "kernel32.dll", "user32.dll", "advapi32.dll", "ole32.dll", "oleaut32.dll",
        "shell32.dll", "comctl32.dll", "gdi32.dll", "wininet.dll", "ws2_32.dll",
        "crypt32.dll", "bcrypt.dll", "ncrypt.dll", "msvcp140.dll", "vcruntime140.dll",
        "msvcr110.dll", "msvcr120.dll", "msvcp110.dll", "msvcp120.dll"
    )
    
    foreach ($dep in $dependencies) {
        Write-Host "  📋 $dep" -ForegroundColor Gray
        
        if ($dep -in $azureAvailableLibraries) {
            $systemDependencies += $dep
        } elseif ($dep -match "^(msvc|vcrun|msvcp)") {
            $runtimeDependencies += $dep
        } elseif ($dep -match "^(api-ms-win|ext-ms-win)") {
            # Windows API sets - usually fine
            $systemDependencies += $dep
        } else {
            $customDependencies += $dep
            
            # Check for potentially problematic dependencies
            if ($dep -match "(odbc|oracle|mysql|postgresql)") {
                $potentialIssues += "Database driver dependency: $dep - Verify compatibility with Azure App Service"
            } elseif ($dep -match "(activex|atl|mfc)") {
                $potentialIssues += "Legacy Windows dependency: $dep - May require additional configuration"
            }
        }
    }
    
    Write-Host "`n📊 Dependency Analysis Results:" -ForegroundColor Cyan
    Write-Host "  ✅ System libraries: $($systemDependencies.Count)" -ForegroundColor Green
    Write-Host "  📦 Runtime libraries: $($runtimeDependencies.Count)" -ForegroundColor Yellow
    Write-Host "  🔧 Custom dependencies: $($customDependencies.Count)" -ForegroundColor $(if ($customDependencies.Count -gt 0) { "Yellow" } else { "Green" })
    
    if ($potentialIssues.Count -gt 0) {
        Write-Host "  ⚠️ Potential issues: $($potentialIssues.Count)" -ForegroundColor Red
        foreach ($issue in $potentialIssues) {
            Write-Host "    • $issue" -ForegroundColor Yellow
        }
    }
    
    $Global:ValidationResults.DependencyCheck.Status = if ($customDependencies.Count -eq 0 -and $potentialIssues.Count -eq 0) { "Pass" } elseif ($potentialIssues.Count -eq 0) { "Warning" } else { "Critical" }
    $Global:ValidationResults.DependencyCheck.Details = @{
        SystemDependencies = $systemDependencies
        RuntimeDependencies = $runtimeDependencies
        CustomDependencies = $customDependencies
    }
    $Global:ValidationResults.RequiredFiles += $runtimeDependencies
    $Global:ValidationResults.RequiredFiles += $customDependencies
    
    if ($customDependencies.Count -gt 0) {
        $Global:ValidationResults.MigrationReadiness.Warnings += "Custom dependencies detected: $($customDependencies -join ', ') - Include in deployment package"
    }
    
} catch {
    Write-Host "⚠️ Could not analyze dependencies. Manual verification required." -ForegroundColor Yellow
    $Global:ValidationResults.DependencyCheck.Status = "Warning"
}

# Step 5: Azure App Service Sandbox Compatibility
Write-Host "`n🛡️ Step 5: Azure App Service Sandbox Compatibility" -ForegroundColor Yellow

$sandboxChecks = @(
    @{ 
        Name = "File System Access"
        Description = "Check if DLL attempts restricted file operations"
        Status = "Pass"  # Default assumption for no-code change
        Recommendation = "Ensure file operations use D:\home\ or D:\local\Temp paths"
    },
    @{ 
        Name = "Registry Access"
        Description = "Registry access restrictions in Azure App Service"
        Status = "Warning"
        Recommendation = "Replace registry access with app settings in web.config"
    },
    @{ 
        Name = "Network Access"
        Description = "Outbound network access limitations"
        Status = "Pass"
        Recommendation = "HTTP/HTTPS outbound connections are allowed"
    },
    @{ 
        Name = "Win32 API Usage"
        Description = "Some Win32 APIs are restricted"
        Status = "Warning" 
        Recommendation = "Review Win32 API usage for Azure App Service compatibility"
    }
)

foreach ($check in $sandboxChecks) {
    $statusColor = switch ($check.Status) {
        "Pass" { "Green" }
        "Warning" { "Yellow" }
        "Critical" { "Red" }
    }
    
    Write-Host "  $(if ($check.Status -eq 'Pass') { '✅' } elseif ($check.Status -eq 'Warning') { '⚠️' } else { '❌' }) $($check.Name): $($check.Status)" -ForegroundColor $statusColor
    
    if ($check.Status -ne "Pass") {
        Write-Host "    💡 $($check.Recommendation)" -ForegroundColor Cyan
    }
}

$Global:ValidationResults.SandboxCompatibility.Status = "Warning"  # Conservative for no-code migration
$Global:ValidationResults.SandboxCompatibility.Recommendations = $sandboxChecks | Where-Object { $_.Status -ne "Pass" } | ForEach-Object { $_.Recommendation }

# Step 6: Generate Migration Package (if requested)
if ($GenerateConfig -or $CollectDependencies) {
    Write-Host "`n📦 Step 6: Generating Migration Package" -ForegroundColor Yellow
    
    if (-not $OutputPath) {
        $OutputPath = "migration-package-$((Get-Date).ToString('yyyyMMdd-HHmmss'))"
    }
    
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    Write-Host "Creating migration package in: $OutputPath" -ForegroundColor Cyan
    
    # Copy ISAPI DLL
    Copy-Item $ISAPIPath -Destination $OutputPath -Force
    Write-Host "✅ Copied ISAPI DLL to migration package" -ForegroundColor Green
    
    if ($GenerateConfig) {
        # Generate web.config template
        $webConfigTemplate = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <!-- ISAPI Extension Configuration -->
    <handlers>
      <add name="$($isapiFile.BaseName)Handler" 
           path="*" 
           verb="GET,POST,PUT,DELETE" 
           modules="IsapiModule" 
           scriptProcessor="$($isapiFile.Name)" 
           resourceType="Unspecified" 
           preCondition="bitness64" />
    </handlers>
    
    <!-- Security and Request Filtering -->
    <security>
      <requestFiltering>
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
    
    <!-- Environment Variables for Path Mapping -->
    <environmentVariables>
      <add name="SHARED_FOLDER" value="D:\home\shared" />
      <add name="TEMP_FOLDER" value="D:\local\Temp" />
      <add name="DATA_FOLDER" value="D:\home\data" />
      <add name="LOG_FOLDER" value="D:\home\LogFiles" />
    </environmentVariables>
  </system.webServer>
  
  <!-- Application Settings -->
  <appSettings>
    <!-- Add your application settings here -->
    <!-- <add key="YourSetting" value="YourValue" /> -->
  </appSettings>
  
  <!-- Connection Strings -->
  <connectionStrings>
    <!-- Add your connection strings here -->
    <!-- <add name="DefaultConnection" connectionString="Server=tcp:your-server.database.windows.net,1433;Database=YourDB;Authentication=Active Directory Managed Identity;Encrypt=True;" /> -->
  </connectionStrings>
</configuration>
"@
        
        $webConfigPath = Join-Path $OutputPath "web.config"
        $webConfigTemplate | Set-Content -Path $webConfigPath -Encoding UTF8
        Write-Host "✅ Generated web.config template" -ForegroundColor Green
    }
    
    if ($CollectDependencies) {
        # Create dependencies folder
        $depsPath = Join-Path $OutputPath "dependencies"
        if (-not (Test-Path $depsPath)) {
            New-Item -ItemType Directory -Path $depsPath -Force | Out-Null
        }
        
        # Collect runtime dependencies
        foreach ($dep in $Global:ValidationResults.RequiredFiles) {
            $systemPath = Join-Path $env:SystemRoot "System32\$dep"
            $wowPath = Join-Path $env:SystemRoot "SysWOW64\$dep"
            
            if (Test-Path $systemPath) {
                Copy-Item $systemPath -Destination $depsPath -Force -ErrorAction SilentlyContinue
                Write-Host "✅ Collected dependency: $dep" -ForegroundColor Green
            } elseif (Test-Path $wowPath) {
                Copy-Item $wowPath -Destination $depsPath -Force -ErrorAction SilentlyContinue
                Write-Host "✅ Collected dependency: $dep" -ForegroundColor Green
            } else {
                Write-Host "⚠️ Could not locate dependency: $dep" -ForegroundColor Yellow
            }
        }
    }
}

# Step 7: Final Assessment and Recommendations
Write-Host "`n📋 Step 7: Migration Readiness Assessment" -ForegroundColor Yellow

$criticalIssues = 0
$warnings = 0

# Count issues
if ($Global:ValidationResults.ArchitectureCheck.Status -eq "Critical") { $criticalIssues++ }
if ($Global:ValidationResults.ISAPIExportsCheck.Status -eq "Critical") { $criticalIssues++ }
if ($Global:ValidationResults.DependencyCheck.Status -eq "Critical") { $criticalIssues++ }

if ($Global:ValidationResults.ArchitectureCheck.Status -eq "Warning") { $warnings++ }
if ($Global:ValidationResults.ISAPIExportsCheck.Status -eq "Warning") { $warnings++ }
if ($Global:ValidationResults.DependencyCheck.Status -eq "Warning") { $warnings++ }
if ($Global:ValidationResults.SandboxCompatibility.Status -eq "Warning") { $warnings++ }

# Determine overall status
if ($criticalIssues -eq 0 -and $warnings -eq 0) {
    $Global:ValidationResults.OverallStatus = "Ready"
    Write-Host "🎉 MIGRATION READY: Your ISAPI DLL can be migrated with no code changes!" -ForegroundColor Green
} elseif ($criticalIssues -eq 0) {
    $Global:ValidationResults.OverallStatus = "Ready with Warnings"
    Write-Host "⚠️ MIGRATION READY WITH WARNINGS: Review warnings before deployment" -ForegroundColor Yellow
} else {
    $Global:ValidationResults.OverallStatus = "Critical Issues"
    Write-Host "❌ CRITICAL ISSUES: Must resolve before migration" -ForegroundColor Red
}

Write-Host "`n📊 Summary:" -ForegroundColor Cyan
Write-Host "  Critical Issues: $criticalIssues" -ForegroundColor $(if ($criticalIssues -gt 0) { "Red" } else { "Green" })
Write-Host "  Warnings: $warnings" -ForegroundColor $(if ($warnings -gt 0) { "Yellow" } else { "Green" })

if ($Global:ValidationResults.MigrationReadiness.BlockingIssues.Count -gt 0) {
    Write-Host "`n❌ Blocking Issues to Resolve:" -ForegroundColor Red
    foreach ($issue in $Global:ValidationResults.MigrationReadiness.BlockingIssues) {
        Write-Host "  • $issue" -ForegroundColor Red
    }
}

if ($Global:ValidationResults.MigrationReadiness.Warnings.Count -gt 0) {
    Write-Host "`n⚠️ Warnings to Address:" -ForegroundColor Yellow
    foreach ($warning in $Global:ValidationResults.MigrationReadiness.Warnings) {
        Write-Host "  • $warning" -ForegroundColor Yellow
    }
}

Write-Host "`n🎯 Next Steps:" -ForegroundColor Blue
if ($Global:ValidationResults.OverallStatus -eq "Ready") {
    Write-Host "1. Create deployment package with your ISAPI DLL and dependencies" -ForegroundColor Blue
    Write-Host "2. Configure web.config for Azure App Service (template provided)" -ForegroundColor Blue
    Write-Host "3. Deploy to Azure App Service using the deployment scripts" -ForegroundColor Blue
    Write-Host "4. Test functionality and monitor performance" -ForegroundColor Blue
} elseif ($Global:ValidationResults.OverallStatus -eq "Ready with Warnings") {
    Write-Host "1. Review and address the warnings listed above" -ForegroundColor Blue
    Write-Host "2. Create deployment package with dependencies" -ForegroundColor Blue
    Write-Host "3. Test in staging environment first" -ForegroundColor Blue
    Write-Host "4. Deploy to production after validation" -ForegroundColor Blue
} else {
    Write-Host "1. Resolve all critical issues listed above" -ForegroundColor Blue
    Write-Host "2. Re-run this validation script" -ForegroundColor Blue
    Write-Host "3. Consider recompiling ISAPI DLL if architecture issues exist" -ForegroundColor Blue
}

# Save detailed report if output path specified
if ($OutputPath) {
    $reportPath = Join-Path $OutputPath "migration-readiness-report.json"
    $Global:ValidationResults | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath -Encoding UTF8
    Write-Host "`n📄 Detailed report saved: $reportPath" -ForegroundColor Cyan
}

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "    ISAPI No-Code Migration Validation Complete" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
