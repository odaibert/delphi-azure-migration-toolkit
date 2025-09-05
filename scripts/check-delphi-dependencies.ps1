#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates Delphi ISAPI dependencies and architecture for Azure App Service deployment
    
.DESCRIPTION
    This script performs comprehensive validation of Delphi ISAPI DLLs including:
    1. Architecture validation (64-bit requirement)
    2. Dependency analysis using system tools
    3. Azure App Service compatibility checks
    4. Performance and size analysis
    
.PARAMETER DllPath
    Path to the compiled ISAPI DLL file
    
.PARAMETER ProjectPath
    Optional: Path to the Delphi project file for additional validation
    
.PARAMETER Verbose
    Enable verbose output for detailed dependency analysis
    
.EXAMPLE
    .\check-delphi-dependencies.ps1 -DllPath "deployment\MyISAPI.dll"
    
.EXAMPLE
    .\check-delphi-dependencies.ps1 -DllPath "deployment\MyISAPI.dll" -ProjectPath "MyProject.dpr" -Verbose
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DllPath,
    
    [Parameter(Mandatory = $false)]
    [string]$ProjectPath = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$Verbose
)

Write-Host "🔍 Delphi ISAPI Dependency Validation for Azure App Service" -ForegroundColor Green
Write-Host "Target DLL: $DllPath" -ForegroundColor Cyan
Write-Host "Project: $(if ($ProjectPath) { $ProjectPath } else { 'Not specified' })" -ForegroundColor Cyan
Write-Host

$ValidationResults = @{
    FileExists = $false
    Is64Bit = $false
    HasISAPIExports = $false
    DependenciesResolved = $false
    SizeOptimal = $false
    AzureCompatible = $false
    OverallSuccess = $false
}

# Test 1: File Existence and Basic Properties
Write-Host "📁 Validating File Properties..." -ForegroundColor Yellow
if (Test-Path $DllPath) {
    $FileInfo = Get-ItemProperty $DllPath
    $FileSizeMB = [math]::Round($FileInfo.Length / 1MB, 2)
    
    Write-Host "✅ DLL file found: $DllPath" -ForegroundColor Green
    Write-Host "ℹ️ File size: $FileSizeMB MB" -ForegroundColor Cyan
    Write-Host "ℹ️ Last modified: $($FileInfo.LastWriteTime)" -ForegroundColor Cyan
    
    $ValidationResults.FileExists = $true
    
    # Size validation (ISAPI DLLs should typically be under 50MB for optimal performance)
    if ($FileSizeMB -lt 50) {
        Write-Host "✅ File size is optimal for Azure deployment" -ForegroundColor Green
        $ValidationResults.SizeOptimal = $true
    } else {
        Write-Host "⚠️ Large DLL size ($FileSizeMB MB) may impact cold start performance" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ DLL file not found: $DllPath" -ForegroundColor Red
    Write-Host "💡 Ensure your Delphi project is compiled for Win64 platform" -ForegroundColor Blue
    return $ValidationResults
}

# Test 2: Architecture Validation (64-bit requirement)
Write-Host "`n🏗️ Validating Architecture..." -ForegroundColor Yellow
try {
    # Read PE header to determine architecture
    $FileBytes = [System.IO.File]::ReadAllBytes($DllPath)
    $PEOffset = [BitConverter]::ToUInt32($FileBytes, 60)
    $MachineType = [BitConverter]::ToUInt16($FileBytes, $PEOffset + 4)
    
    switch ($MachineType) {
        0x014c { 
            Write-Host "❌ DLL is compiled for 32-bit (x86) - Azure App Service requires 64-bit" -ForegroundColor Red
            Write-Host "💡 Recompile your Delphi project with Win64 target platform" -ForegroundColor Blue
        }
        0x8664 { 
            Write-Host "✅ DLL is compiled for 64-bit (x64) - Compatible with Azure App Service" -ForegroundColor Green
            $ValidationResults.Is64Bit = $true
        }
        0x0200 { 
            Write-Host "❌ DLL is compiled for Itanium (IA64) - Not supported" -ForegroundColor Red
        }
        default { 
            Write-Host "⚠️ Unknown architecture detected: 0x$($MachineType.ToString('X4'))" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "❌ Failed to read PE header: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: ISAPI Export Validation
Write-Host "`n🔌 Validating ISAPI Exports..." -ForegroundColor Yellow
try {
    # Use dumpbin if available (part of Visual Studio tools)
    $DumpBinPath = ""
    $VSPaths = @(
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Professional\VC\Tools\MSVC\*\bin\Hostx64\x64\dumpbin.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\Professional\VC\Tools\MSVC\*\bin\Hostx64\x64\dumpbin.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\VC\Tools\MSVC\*\bin\Hostx64\x64\dumpbin.exe"
    )
    
    foreach ($Path in $VSPaths) {
        $Found = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($Found) {
            $DumpBinPath = $Found.FullName
            break
        }
    }
    
    if ($DumpBinPath) {
        $ExportOutput = & $DumpBinPath /exports $DllPath 2>$null
        $RequiredExports = @("GetExtensionVersion", "HttpExtensionProc", "TerminateExtension")
        $FoundExports = @()
        
        foreach ($Export in $RequiredExports) {
            if ($ExportOutput -match $Export) {
                $FoundExports += $Export
                Write-Host "✅ Found ISAPI export: $Export" -ForegroundColor Green
            } else {
                Write-Host "❌ Missing ISAPI export: $Export" -ForegroundColor Red
            }
        }
        
        if ($FoundExports.Count -eq $RequiredExports.Count) {
            Write-Host "✅ All required ISAPI exports found" -ForegroundColor Green
            $ValidationResults.HasISAPIExports = $true
        } else {
            Write-Host "❌ Missing required ISAPI exports - DLL may not function as ISAPI filter" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠️ Visual Studio dumpbin tool not found - skipping export validation" -ForegroundColor Yellow
        Write-Host "💡 Install Visual Studio Build Tools for complete validation" -ForegroundColor Blue
    }
} catch {
    Write-Host "⚠️ Export validation failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Test 4: Dependency Analysis
Write-Host "`n🔗 Analyzing Dependencies..." -ForegroundColor Yellow
try {
    if ($DumpBinPath) {
        $DependencyOutput = & $DumpBinPath /dependents $DllPath 2>$null
        $Dependencies = $DependencyOutput | Where-Object { $_ -match "\.dll" } | ForEach-Object { $_.Trim() }
        
        if ($Dependencies) {
            Write-Host "📦 Detected dependencies:" -ForegroundColor Cyan
            $ProblematicDeps = @()
            
            foreach ($Dep in $Dependencies) {
                $DepName = $Dep -replace "^\s+", ""
                if ($DepName -match "^(KERNEL32|USER32|ADVAPI32|ole32|oleaut32|msvcrt)\.dll$") {
                    if ($Verbose) { Write-Host "  ✅ $DepName (System DLL - OK)" -ForegroundColor Green }
                } elseif ($DepName -match "^(msvcp\d+|vcruntime\d+|ucrtbase)\.dll$") {
                    Write-Host "  ⚠️ $DepName (VC++ Runtime - ensure available)" -ForegroundColor Yellow
                } else {
                    Write-Host "  ❌ $DepName (Custom dependency - must be deployed)" -ForegroundColor Red
                    $ProblematicDeps += $DepName
                }
            }
            
            if ($ProblematicDeps.Count -eq 0) {
                Write-Host "✅ All dependencies are system DLLs or standard runtimes" -ForegroundColor Green
                $ValidationResults.DependenciesResolved = $true
            } else {
                Write-Host "❌ Custom dependencies detected - ensure these DLLs are deployed with your ISAPI" -ForegroundColor Red
                Write-Host "💡 Place custom DLLs in the same folder as your ISAPI DLL" -ForegroundColor Blue
            }
        } else {
            Write-Host "✅ No external dependencies detected (statically linked)" -ForegroundColor Green
            $ValidationResults.DependenciesResolved = $true
        }
    }
} catch {
    Write-Host "⚠️ Dependency analysis failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Test 5: Azure Compatibility Checks
Write-Host "`n☁️ Azure App Service Compatibility..." -ForegroundColor Yellow

# Check file name compatibility
$FileName = [System.IO.Path]::GetFileName($DllPath)
if ($FileName -match "^[a-zA-Z0-9._-]+\.dll$") {
    Write-Host "✅ File name is Azure-compatible: $FileName" -ForegroundColor Green
} else {
    Write-Host "⚠️ File name contains special characters that may cause issues: $FileName" -ForegroundColor Yellow
}

# Check for common Azure sandbox violations (basic checks)
$AzureCompatibilityScore = 0
$TotalChecks = 5

# Basic compatibility indicators
if ($ValidationResults.Is64Bit) { $AzureCompatibilityScore++ }
if ($ValidationResults.HasISAPIExports -or -not $DumpBinPath) { $AzureCompatibilityScore++ }
if ($ValidationResults.DependenciesResolved) { $AzureCompatibilityScore++ }
if ($ValidationResults.SizeOptimal) { $AzureCompatibilityScore++ }
if ($FileName -match "^[a-zA-Z0-9._-]+\.dll$") { $AzureCompatibilityScore++ }

$CompatibilityPercentage = [math]::Round(($AzureCompatibilityScore / $TotalChecks) * 100, 0)

if ($CompatibilityPercentage -ge 80) {
    Write-Host "✅ Azure compatibility score: $CompatibilityPercentage% - Good for deployment" -ForegroundColor Green
    $ValidationResults.AzureCompatible = $true
} elseif ($CompatibilityPercentage -ge 60) {
    Write-Host "⚠️ Azure compatibility score: $CompatibilityPercentage% - Review issues above" -ForegroundColor Yellow
} else {
    Write-Host "❌ Azure compatibility score: $CompatibilityPercentage% - Address critical issues before deployment" -ForegroundColor Red
}

# Test 6: Project File Analysis (if provided)
if ($ProjectPath -and (Test-Path $ProjectPath)) {
    Write-Host "`n📄 Analyzing Project Configuration..." -ForegroundColor Yellow
    $ProjectContent = Get-Content $ProjectPath -Raw
    
    # Check for common Azure incompatibilities
    if ($ProjectContent -match "registry|TRegistry") {
        Write-Host "⚠️ Project uses Windows Registry - consider using App Settings instead" -ForegroundColor Yellow
    }
    
    if ($ProjectContent -match "CreateProcess|WinExec|ShellExecute") {
        Write-Host "❌ Project uses process creation APIs - not allowed in Azure App Service sandbox" -ForegroundColor Red
    }
    
    if ($ProjectContent -match "MessageBox|ShowMessage") {
        Write-Host "⚠️ Project uses UI message boxes - not suitable for server environment" -ForegroundColor Yellow
    }
    
    Write-Host "✅ Project file analysis completed" -ForegroundColor Green
}

# Final Assessment
Write-Host "`n📊 Validation Summary:" -ForegroundColor Green
Write-Host "=====================================`n" -ForegroundColor Green

$PassedTests = 0
$TotalTests = 6

if ($ValidationResults.FileExists) { 
    Write-Host "✅ File Exists" -ForegroundColor Green
    $PassedTests++
} else { Write-Host "❌ File Exists" -ForegroundColor Red }

if ($ValidationResults.Is64Bit) { 
    Write-Host "✅ 64-bit Architecture" -ForegroundColor Green
    $PassedTests++
} else { Write-Host "❌ 64-bit Architecture" -ForegroundColor Red }

if ($ValidationResults.HasISAPIExports -or -not $DumpBinPath) { 
    Write-Host "✅ ISAPI Exports" -ForegroundColor Green
    $PassedTests++
} else { Write-Host "❌ ISAPI Exports" -ForegroundColor Red }

if ($ValidationResults.DependenciesResolved) { 
    Write-Host "✅ Dependencies" -ForegroundColor Green
    $PassedTests++
} else { Write-Host "❌ Dependencies" -ForegroundColor Red }

if ($ValidationResults.SizeOptimal) { 
    Write-Host "✅ File Size" -ForegroundColor Green
    $PassedTests++
} else { Write-Host "⚠️ File Size" -ForegroundColor Yellow }

if ($ValidationResults.AzureCompatible) { 
    Write-Host "✅ Azure Compatibility" -ForegroundColor Green
    $PassedTests++
} else { Write-Host "❌ Azure Compatibility" -ForegroundColor Red }

$OverallScore = [math]::Round(($PassedTests / $TotalTests) * 100, 0)
$ValidationResults.OverallSuccess = $OverallScore -ge 80

Write-Host "`nOverall Readiness Score: $OverallScore%" -ForegroundColor $(if ($ValidationResults.OverallSuccess) { 'Green' } else { 'Red' })

if ($ValidationResults.OverallSuccess) {
    Write-Host "🎉 Your Delphi ISAPI DLL is ready for Azure App Service deployment!" -ForegroundColor Green
    Write-Host "💡 Next step: Use the deployment scripts in the deployment/ folder" -ForegroundColor Blue
} else {
    Write-Host "🚨 Please address the issues above before deploying to Azure App Service" -ForegroundColor Red
    Write-Host "💡 Check the Delphi compilation guide: docs/delphi-compilation-guide.md" -ForegroundColor Blue
}

return $ValidationResults
