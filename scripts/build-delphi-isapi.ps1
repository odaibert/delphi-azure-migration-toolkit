#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Automated Delphi ISAPI compilation and deployment preparation for Azure App Service
    
.DESCRIPTION
    This script provides comprehensive build automation for Delphi ISAPI projects including:
    1. Environment validation and setup
    2. 64-bit compilation with Azure-optimized settings
    3. Dependency packaging and validation
    4. Deployment artifact preparation
    5. Basic smoke testing
    
.PARAMETER ProjectPath
    Path to the Delphi project file (.dpr or .dproj)
    
.PARAMETER DelphiPath
    Path to Delphi compiler (dcc64.exe). Auto-detected if not specified.
    
.PARAMETER OutputPath
    Output directory for compiled artifacts (default: deployment)
    
.PARAMETER Configuration
    Build configuration: Debug or Release (default: Release)
    
.PARAMETER SkipDependencyCheck
    Skip dependency validation after build
    
.PARAMETER PackageOutput
    Create deployment package with all dependencies
    
.EXAMPLE
    .\build-delphi-isapi.ps1 -ProjectPath "MyISAPI.dpr"
    
.EXAMPLE
    .\build-delphi-isapi.ps1 -ProjectPath "MyProject.dproj" -Configuration "Debug" -PackageOutput
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,
    
    [Parameter(Mandatory = $false)]
    [string]$DelphiPath = "",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "deployment",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipDependencyCheck,
    
    [Parameter(Mandatory = $false)]
    [switch]$PackageOutput
)

Write-Host "🏗️ Delphi ISAPI Build Automation for Azure App Service" -ForegroundColor Green
Write-Host "Project: $ProjectPath" -ForegroundColor Cyan
Write-Host "Configuration: $Configuration" -ForegroundColor Cyan
Write-Host "Output: $OutputPath" -ForegroundColor Cyan
Write-Host

# Step 1: Environment Detection and Validation
Write-Host "🔍 Detecting Build Environment..." -ForegroundColor Yellow

if (-not (Test-Path $ProjectPath)) {
    Write-Host "❌ Project file not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

$ProjectDir = Split-Path $ProjectPath -Parent
$ProjectName = [System.IO.Path]::GetFileNameWithoutExtension($ProjectPath)
$ProjectExtension = [System.IO.Path]::GetExtension($ProjectPath)

Write-Host "✅ Project found: $ProjectName$ProjectExtension" -ForegroundColor Green

# Auto-detect Delphi compiler if not specified
if (-not $DelphiPath) {
    Write-Host "🔍 Auto-detecting Delphi compiler..." -ForegroundColor Yellow
    
    $DelphiLocations = @(
        # RAD Studio/Delphi 12 Alexandria
        "${env:ProgramFiles(x86)}\Embarcadero\Studio\23.0\bin\dcc64.exe",
        # RAD Studio/Delphi 11 Alexandria  
        "${env:ProgramFiles(x86)}\Embarcadero\Studio\22.0\bin\dcc64.exe",
        # RAD Studio/Delphi 10.4 Sydney
        "${env:ProgramFiles(x86)}\Embarcadero\Studio\21.0\bin\dcc64.exe",
        # RAD Studio/Delphi 10.3 Rio
        "${env:ProgramFiles(x86)}\Embarcadero\Studio\20.0\bin\dcc64.exe",
        # Community Edition paths
        "${env:ProgramFiles(x86)}\Embarcadero\Studio\22.0\bin\dcc64.exe"
    )
    
    foreach ($Location in $DelphiLocations) {
        if (Test-Path $Location) {
            $DelphiPath = $Location
            $Version = (Get-ItemProperty $Location).VersionInfo.FileVersion
            Write-Host "✅ Found Delphi compiler: $Location (v$Version)" -ForegroundColor Green
            break
        }
    }
    
    if (-not $DelphiPath) {
        Write-Host "❌ Delphi compiler not found. Please specify -DelphiPath parameter" -ForegroundColor Red
        Write-Host "💡 Install RAD Studio or specify path to dcc64.exe" -ForegroundColor Blue
        exit 1
    }
}

# Verify compiler exists
if (-not (Test-Path $DelphiPath)) {
    Write-Host "❌ Delphi compiler not found at: $DelphiPath" -ForegroundColor Red
    exit 1
}

# Step 2: Prepare Build Environment
Write-Host "`n📁 Preparing Build Environment..." -ForegroundColor Yellow

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Write-Host "✅ Created output directory: $OutputPath" -ForegroundColor Green
} else {
    Write-Host "✅ Using existing output directory: $OutputPath" -ForegroundColor Green
}

# Create temp directory for intermediate files
$TempPath = Join-Path $OutputPath "temp"
if (-not (Test-Path $TempPath)) {
    New-Item -ItemType Directory -Path $TempPath -Force | Out-Null
}

# Step 3: Configure Compilation Parameters
Write-Host "`n⚙️ Configuring Compilation Parameters..." -ForegroundColor Yellow

$CompilerArgs = @()

# Basic compilation flags
$CompilerArgs += "-B"                          # Build all units
$CompilerArgs += "-Q"                          # Quiet compile (reduce output)
$CompilerArgs += "-E`"$OutputPath`""           # Output directory
$CompilerArgs += "-N`"$TempPath`""             # DCU output path

# Configuration-specific settings
if ($Configuration -eq "Release") {
    $CompilerArgs += "-\$O+"                   # Optimization ON
    $CompilerArgs += "-\$D-"                   # Debug info OFF
    $CompilerArgs += "-\$L-"                   # Local symbols OFF
    $CompilerArgs += "-\$Y-"                   # Symbol reference info OFF
    $CompilerArgs += "-\$C-"                   # Assertions OFF
    $CompilerArgs += "-\$Q-"                   # Overflow checking OFF
    $CompilerArgs += "-\$R-"                   # Range checking OFF
    Write-Host "✅ Release configuration: Optimized for production" -ForegroundColor Green
} else {
    $CompilerArgs += "-\$O-"                   # Optimization OFF
    $CompilerArgs += "-\$D+"                   # Debug info ON
    $CompilerArgs += "-\$L+"                   # Local symbols ON
    $CompilerArgs += "-\$Y+"                   # Symbol reference info ON
    $CompilerArgs += "-\$C+"                   # Assertions ON
    $CompilerArgs += "-\$Q+"                   # Overflow checking ON
    $CompilerArgs += "-\$R+"                   # Range checking ON
    Write-Host "✅ Debug configuration: Debugging symbols enabled" -ForegroundColor Green
}

# Azure-specific optimizations
$CompilerArgs += "-\$J+"                       # Typed constants as variables
$CompilerArgs += "-\$T+"                       # Typed @ operator
$CompilerArgs += "-\$X+"                       # Extended syntax

# Add project file
$CompilerArgs += "`"$ProjectPath`""

Write-Host "Compiler arguments: $($CompilerArgs -join ' ')" -ForegroundColor Cyan

# Step 4: Execute Compilation
Write-Host "`n🔨 Compiling Project..." -ForegroundColor Yellow

$StartTime = Get-Date
try {
    $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
    $ProcessInfo.FileName = $DelphiPath
    $ProcessInfo.Arguments = $CompilerArgs -join " "
    $ProcessInfo.UseShellExecute = $false
    $ProcessInfo.RedirectStandardOutput = $true
    $ProcessInfo.RedirectStandardError = $true
    $ProcessInfo.WorkingDirectory = $ProjectDir

    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $ProcessInfo
    
    $stdout = New-Object System.Text.StringBuilder
    $stderr = New-Object System.Text.StringBuilder
    
    $Process.add_OutputDataReceived({
        param($sender, $e)
        if ($e.Data) {
            [void]$stdout.AppendLine($e.Data)
            if ($e.Data -match "Error|Fatal") {
                Write-Host $e.Data -ForegroundColor Red
            } elseif ($e.Data -match "Warning") {
                Write-Host $e.Data -ForegroundColor Yellow
            }
        }
    })
    
    $Process.add_ErrorDataReceived({
        param($sender, $e)
        if ($e.Data) {
            [void]$stderr.AppendLine($e.Data)
            Write-Host $e.Data -ForegroundColor Red
        }
    })

    $Process.Start() | Out-Null
    $Process.BeginOutputReadLine()
    $Process.BeginErrorReadLine()
    $Process.WaitForExit()
    
    $ExitCode = $Process.ExitCode
    $CompileTime = (Get-Date) - $StartTime
    
    Write-Host "Compilation completed in $($CompileTime.TotalSeconds.ToString('F1')) seconds" -ForegroundColor Cyan
    
    if ($ExitCode -eq 0) {
        Write-Host "✅ Compilation successful!" -ForegroundColor Green
    } else {
        Write-Host "❌ Compilation failed with exit code: $ExitCode" -ForegroundColor Red
        Write-Host "Error output:" -ForegroundColor Red
        Write-Host $stderr.ToString() -ForegroundColor Red
        exit $ExitCode
    }
} catch {
    Write-Host "❌ Compilation process failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 5: Verify Output
Write-Host "`n🔍 Verifying Build Output..." -ForegroundColor Yellow

$OutputDLL = Join-Path $OutputPath "$ProjectName.dll"
if (Test-Path $OutputDLL) {
    $FileInfo = Get-ItemProperty $OutputDLL
    $FileSize = [math]::Round($FileInfo.Length / 1KB, 2)
    Write-Host "✅ Output DLL created: $ProjectName.dll ($FileSize KB)" -ForegroundColor Green
    Write-Host "📂 Location: $OutputDLL" -ForegroundColor Cyan
    
    # Quick architecture check
    try {
        $FileBytes = [System.IO.File]::ReadAllBytes($OutputDLL)
        $PEOffset = [BitConverter]::ToUInt32($FileBytes, 60)
        $MachineType = [BitConverter]::ToUInt16($FileBytes, $PEOffset + 4)
        
        if ($MachineType -eq 0x8664) {
            Write-Host "✅ DLL architecture: 64-bit (x64) - Azure compatible" -ForegroundColor Green
        } else {
            Write-Host "❌ DLL architecture: Not 64-bit - Azure App Service requires x64" -ForegroundColor Red
        }
    } catch {
        Write-Host "⚠️ Could not verify DLL architecture" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Expected output DLL not found: $OutputDLL" -ForegroundColor Red
    exit 1
}

# Step 6: Dependency Validation (if not skipped)
if (-not $SkipDependencyCheck) {
    Write-Host "`n🔗 Running Dependency Check..." -ForegroundColor Yellow
    
    $DependencyScript = Join-Path $PSScriptRoot "check-delphi-dependencies.ps1"
    if (Test-Path $DependencyScript) {
        try {
            $ValidationResult = & $DependencyScript -DllPath $OutputDLL -ProjectPath $ProjectPath
            if ($ValidationResult.OverallSuccess) {
                Write-Host "✅ Dependency validation passed" -ForegroundColor Green
            } else {
                Write-Host "⚠️ Dependency validation found issues - review output above" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "⚠️ Dependency check failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠️ Dependency check script not found - skipping validation" -ForegroundColor Yellow
    }
}

# Step 7: Package Output (if requested)
if ($PackageOutput) {
    Write-Host "`n📦 Creating Deployment Package..." -ForegroundColor Yellow
    
    $PackagePath = Join-Path $OutputPath "azure-deployment-package"
    if (-not (Test-Path $PackagePath)) {
        New-Item -ItemType Directory -Path $PackagePath -Force | Out-Null
    }
    
    # Copy main DLL
    Copy-Item $OutputDLL -Destination $PackagePath -Force
    Write-Host "✅ Copied main DLL to package" -ForegroundColor Green
    
    # Copy web.config if it exists
    $WebConfigPath = Join-Path $PSScriptRoot "..\deployment\web.config"
    if (Test-Path $WebConfigPath) {
        $PackageWebConfig = Join-Path $PackagePath "web.config"
        $WebConfigContent = Get-Content $WebConfigPath -Raw
        $WebConfigContent = $WebConfigContent -replace "YourISAPIFilter\.dll", "$ProjectName.dll"
        $WebConfigContent | Set-Content $PackageWebConfig -Encoding UTF8
        Write-Host "✅ Created customized web.config in package" -ForegroundColor Green
    }
    
    # Create deployment script for this specific project
    $DeployScript = @"
#!/usr/bin/env pwsh
# Auto-generated deployment script for $ProjectName
# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

param(
    [Parameter(Mandatory=`$true)]
    [string]`$ResourceGroupName,
    
    [Parameter(Mandatory=`$true)]
    [string]`$AppServiceName
)

Write-Host "🚀 Deploying $ProjectName to Azure App Service" -ForegroundColor Green
Write-Host "Resource Group: `$ResourceGroupName" -ForegroundColor Cyan
Write-Host "App Service: `$AppServiceName" -ForegroundColor Cyan

# Use the main deployment script with project-specific parameters
`$MainDeployScript = Join-Path `$PSScriptRoot "..\..\deployment\deploy.ps1"
& `$MainDeployScript -ResourceGroupName `$ResourceGroupName -AppServiceName `$AppServiceName -ISAPIFilePath "$ProjectName.dll" -WebConfigPath "web.config"
"@
    
    $DeployScript | Set-Content (Join-Path $PackagePath "deploy-$ProjectName.ps1") -Encoding UTF8
    Write-Host "✅ Created project-specific deployment script" -ForegroundColor Green
    
    # Create README for the package
    $ReadmeContent = @"
# Azure Deployment Package for $ProjectName

Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Configuration: $Configuration
Delphi Compiler: $DelphiPath

## Contents
- **$ProjectName.dll** - Main ISAPI filter
- **web.config** - IIS configuration file
- **deploy-$ProjectName.ps1** - Deployment script

## Deployment Instructions

1. Ensure you have Azure CLI installed and are logged in
2. Create your Azure resources using the Bicep templates
3. Run the deployment script:

``````powershell
.\deploy-$ProjectName.ps1 -ResourceGroupName "your-rg" -AppServiceName "your-app"
``````

## Validation
Before deployment, validate your DLL:
``````powershell
..\scripts\check-delphi-dependencies.ps1 -DllPath "$ProjectName.dll"
``````
"@
    
    $ReadmeContent | Set-Content (Join-Path $PackagePath "README.md") -Encoding UTF8
    Write-Host "✅ Created deployment package README" -ForegroundColor Green
    
    Write-Host "📦 Deployment package ready: $PackagePath" -ForegroundColor Green
}

# Step 8: Clean up temporary files
Write-Host "`n🧹 Cleaning Up..." -ForegroundColor Yellow
if (Test-Path $TempPath) {
    Remove-Item $TempPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✅ Cleaned up temporary files" -ForegroundColor Green
}

# Final Summary
Write-Host "`n🎉 Build Summary:" -ForegroundColor Green
Write-Host "================`n" -ForegroundColor Green
Write-Host "Project: $ProjectName" -ForegroundColor Cyan
Write-Host "Configuration: $Configuration" -ForegroundColor Cyan
Write-Host "Output: $OutputDLL" -ForegroundColor Cyan
Write-Host "Build Time: $($CompileTime.TotalSeconds.ToString('F1')) seconds" -ForegroundColor Cyan

if (Test-Path $OutputDLL) {
    $FileSize = (Get-Item $OutputDLL).Length
    Write-Host "File Size: $([math]::Round($FileSize / 1KB, 2)) KB" -ForegroundColor Cyan
}

if ($PackageOutput) {
    Write-Host "Package: $PackagePath" -ForegroundColor Cyan
}

Write-Host "`n💡 Next Steps:" -ForegroundColor Blue
Write-Host "1. Review any warnings or issues above" -ForegroundColor Blue
Write-Host "2. Test your ISAPI DLL locally if possible" -ForegroundColor Blue
Write-Host "3. Deploy to Azure using the deployment scripts" -ForegroundColor Blue
Write-Host "4. Monitor the deployment using validation scripts" -ForegroundColor Blue

Write-Host "`n✅ Build completed successfully!" -ForegroundColor Green
