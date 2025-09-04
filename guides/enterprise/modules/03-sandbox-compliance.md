# Azure Platform Compliance

Enterprise-grade compliance framework ensuring Delphi ISAPI applications meet Azure App Service sandbox requirements with comprehensive testing and validation.

**⏱️ Implementation Time**: 4-6 hours  
**� Team Involvement**: Developers, Security Team, QA Engineers  
**📋 Prerequisites**: Infrastructure design completed, source code access available

## Compliance Framework Overview

This module implements [Azure App Service sandbox security model](https://learn.microsoft.com/azure/app-service/overview-app-service-sandbox) compliance, ensuring applications operate within platform constraints while maintaining functionality and security.

### Compliance Deliverables

- **Sandbox Compatibility Assessment** with automated code analysis
- **Code Modification Strategy** for platform compliance
- **Testing Framework** for validation and compatibility verification
- **Performance Impact Analysis** with optimization recommendations
- **Compliance Documentation** for security and audit requirements

## 🔒 Azure App Service Sandbox Architecture

### Platform Security Model

Azure App Service implements multi-layered security through sandbox isolation:

```
🏗️ Azure App Service Security Layers:
┌─────────────────────────────────────┐
│     ISAPI Application Layer         │ ← Your Delphi Application
├─────────────────────────────────────┤
│       IIS/ASP.NET Runtime          │ ← Managed Runtime Environment
├─────────────────────────────────────┤
│      Azure Sandbox Layer           │ ← Security Policy Enforcement
├─────────────────────────────────────┤
│    Azure Platform Services         │ ← Infrastructure and Monitoring
└─────────────────────────────────────┘
```

> 📖 **Reference**: [App Service sandbox overview](https://learn.microsoft.com/azure/app-service/overview-app-service-sandbox)

### **Critical Platform Restrictions**

| Operation Category | Status | Impact Level | Enterprise Alternative |
|-------------------|--------|--------------|----------------------|
| **Registry Operations** | ❌ Blocked | High | Azure Key Vault, App Settings |
| **System File Access** | ❌ Blocked | High | Azure Blob Storage, Files |
| **Process Creation** | ❌ Blocked | High | Azure Functions, Logic Apps |
| **COM Out-of-Process** | ❌ Blocked | Medium | In-process COM, Azure Services |
| **Event Log Access** | ❌ Blocked | Medium | Application Insights, Monitor |
| **Network Socket Access** | ⚠️ Limited | Medium | HTTP/HTTPS endpoints only |
| **User Interface APIs** | ❌ Blocked | Low | Server-side processing only |

## 🔍 Automated Compliance Assessment

### PowerShell Code Analysis Framework

Comprehensive source code analysis for sandbox compliance:

```powershell
# sandbox-compliance-analyzer.ps1 - Enterprise code compliance scanner
param(
    [Parameter(Mandatory=$true)]
    [string]$SourcePath,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputReport = "sandbox-compliance-report.html",
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeRecommendations = $true
)
Write-Host "=== Azure App Service Sandbox Compliance Analysis ===" -ForegroundColor Green

$ComplianceIssues = @()
$AnalysisResults = @{
    TotalFiles = 0
    FilesScanned = 0
    IssuesFound = 0
    HighSeverityIssues = 0
    MediumSeverityIssues = 0
    LowSeverityIssues = 0
}

# Define sandbox violation patterns with enterprise-grade detection
$ViolationPatterns = @{
    'Registry' = @{
        Pattern = '(TRegistry|RegOpenKey|RegQueryValue|RegSetValue|TRegIniFile|HKEY_)'
        Severity = 'High'
        Category = 'Registry Access'
        Impact = 'Application will fail to start or function'
        Solution = 'Migrate to Azure App Settings or Azure Key Vault'
        Documentation = 'https://learn.microsoft.com/azure/app-service/configure-common'
    }
    'SystemPaths' = @{
        Pattern = '(C:\\\\|D:\\\\|Program Files|Windows\\\\|System32|%SystemRoot%)'
        Severity = 'High'
        Category = 'Hard-coded System Paths'
        Impact = 'File operations will fail in sandbox environment'
        Solution = 'Use application directory or Azure Blob Storage'
        Documentation = 'https://learn.microsoft.com/azure/app-service/overview-app-service-sandbox'
    }
    'ProcessCreation' = @{
        Pattern = '(CreateProcess|ShellExecute|WinExec|CreateProcessAsUser|system\()'
        Severity = 'High'
        Category = 'Process Creation'
        Impact = 'Process creation operations are blocked'
        Solution = 'Implement using Azure Functions or Logic Apps'
        Documentation = 'https://learn.microsoft.com/azure/azure-functions/'
    }
    'OutOfProcessCOM' = @{
        Pattern = '(CreateOleObject.*Excel|CreateOleObject.*Word|CreateOleObject.*Outlook|CreateActiveXObject)'
        Severity = 'High'
        Category = 'Out-of-Process COM'
        Impact = 'COM server creation will fail'
        Solution = 'Use Azure services or in-process libraries'
        Documentation = 'https://learn.microsoft.com/azure/app-service/overview-app-service-sandbox'
    }
    'Win32UI' = @{
        Pattern = '(User32\.dll|GDI32\.dll|CreateWindow|MessageBox|FindWindow|GetDesktopWindow)'
        Severity = 'Medium'
        Category = 'Win32 UI APIs'
        Impact = 'UI operations not supported in server environment'
        Solution = 'Remove UI code or implement web-based interface'
        Documentation = 'https://learn.microsoft.com/azure/app-service/overview-app-service-sandbox'
    }
    'EventLog' = @{
        Pattern = '(EventLog|ReportEvent|RegisterEventSource|OpenEventLog)'
        Severity = 'Medium'
        Category = 'Event Log Access'
        Impact = 'Event log operations are restricted'
        Solution = 'Implement logging with Application Insights'
        Documentation = 'https://learn.microsoft.com/azure/azure-monitor/app/asp-net'
    }
    'NetworkSockets' = @{
        Pattern = '(Winsock|socket\(|bind\(|listen\(|accept\(|WSAStartup)'
        Severity = 'Medium'
        Category = 'Low-level Network Operations'
        Impact = 'Direct socket operations are restricted'
        Solution = 'Use HTTP/HTTPS client libraries'
        Documentation = 'https://learn.microsoft.com/azure/app-service/overview-app-service-sandbox'
    }
}

function Add-ComplianceIssue {
    param(
        [string]$FilePath,
        [int]$LineNumber,
        [string]$LineContent,
        [string]$Category,
        [string]$Severity,
        [string]$Impact,
        [string]$Solution,
        [string]$Documentation
    )
    
    $script:ComplianceIssues += [PSCustomObject]@{
        File = Split-Path $FilePath -Leaf
        FullPath = $FilePath
        Line = $LineNumber
        Content = $LineContent.Trim()
        Category = $Category
        Severity = $Severity
        Impact = $Impact
        Solution = $Solution
        Documentation = $Documentation
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    # Update counters
    switch ($Severity) {
        'High' { $script:AnalysisResults.HighSeverityIssues++ }
        'Medium' { $script:AnalysisResults.MediumSeverityIssues++ }
        'Low' { $script:AnalysisResults.LowSeverityIssues++ }
    }
    $script:AnalysisResults.IssuesFound++
}

function Scan-SourceFiles {
    param([string]$Path)
    
    Write-Host "Scanning source files in: $Path" -ForegroundColor Cyan
    
    # Get all relevant source files
    $SourceFiles = Get-ChildItem -Path $Path -Recurse -Include "*.pas", "*.dpr", "*.dpk", "*.cpp", "*.c", "*.h" -ErrorAction SilentlyContinue
    $script:AnalysisResults.TotalFiles = $SourceFiles.Count
    
    if ($SourceFiles.Count -eq 0) {
        Write-Warning "No source files found in specified path"
        return
    }
    
    foreach ($File in $SourceFiles) {
        Write-Host "  Analyzing: $($File.Name)" -ForegroundColor Gray
        $script:AnalysisResults.FilesScanned++
        
        try {
            $Content = Get-Content $File.FullName -ErrorAction Stop
            $LineNumber = 0
            
            foreach ($Line in $Content) {
                $LineNumber++
                
                # Check each violation pattern
                foreach ($PatternName in $ViolationPatterns.Keys) {
                    $Pattern = $ViolationPatterns[$PatternName]
                    
                    if ($Line -match $Pattern.Pattern) {
                        Add-ComplianceIssue -FilePath $File.FullName -LineNumber $LineNumber -LineContent $Line -Category $Pattern.Category -Severity $Pattern.Severity -Impact $Pattern.Impact -Solution $Pattern.Solution -Documentation $Pattern.Documentation
                    }
                }
            }
        }
        catch {
            Write-Warning "Could not analyze file: $($File.FullName) - $($_.Exception.Message)"
        }
    }
}

# Execute analysis
Scan-SourceFiles -Path $SourcePath

# Generate comprehensive HTML report
Write-Host "Generating compliance report..." -ForegroundColor Cyan

$HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Azure App Service Sandbox Compliance Report</title>
    <meta charset="UTF-8">
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 0; 
            padding: 20px; 
            background-color: #f5f5f5; 
        }
        .container { 
            max-width: 1200px; 
            margin: 0 auto; 
            background-color: white; 
            padding: 30px; 
            border-radius: 8px; 
            box-shadow: 0 2px 10px rgba(0,0,0,0.1); 
        }
        h1 { 
            color: #0078d4; 
            border-bottom: 3px solid #0078d4; 
            padding-bottom: 10px; 
        }
        h2 { 
            color: #323130; 
            margin-top: 30px; 
        }
        .summary { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); 
            gap: 20px; 
            margin: 20px 0; 
        }
        .metric { 
            background: linear-gradient(135deg, #0078d4, #106ebe); 
            color: white; 
            padding: 20px; 
            border-radius: 8px; 
            text-align: center; 
        }
        .metric.high { background: linear-gradient(135deg, #d13438, #b71c1c); }
        .metric.medium { background: linear-gradient(135deg, #ff8c00, #e67700); }
        .metric.low { background: linear-gradient(135deg, #107c10, #0e6e0e); }
        .metric-value { font-size: 2em; font-weight: bold; }
        .metric-label { font-size: 0.9em; margin-top: 5px; }
        table { 
            border-collapse: collapse; 
            width: 100%; 
            margin: 20px 0; 
            font-size: 14px;
        }
        th { 
            background-color: #0078d4; 
            color: white; 
            padding: 12px; 
            text-align: left; 
            font-weight: 600;
        }
        td { 
            border: 1px solid #ddd; 
            padding: 10px; 
            vertical-align: top; 
        }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .severity-high { 
            background-color: #ffeae6 !important; 
            border-left: 4px solid #d13438; 
        }
        .severity-medium { 
            background-color: #fff4e6 !important; 
            border-left: 4px solid #ff8c00; 
        }
        .severity-low { 
            background-color: #e6f7e6 !important; 
            border-left: 4px solid #107c10; 
        }
        .code { 
            font-family: 'Courier New', monospace; 
            background-color: #f8f8f8; 
            padding: 2px 6px; 
            border-radius: 3px; 
            font-size: 12px;
        }
        .recommendation { 
            font-weight: 600; 
            color: #0078d4; 
        }
        .documentation-link { 
            color: #0078d4; 
            text-decoration: none; 
        }
        .documentation-link:hover { 
            text-decoration: underline; 
        }
        .no-issues { 
            text-align: center; 
            padding: 40px; 
            color: #107c10; 
            font-size: 18px; 
            font-weight: 600; 
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔒 Azure App Service Sandbox Compliance Report</h1>
        <p><strong>Analysis Date:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')</p>
        <p><strong>Source Path:</strong> $SourcePath</p>
        
        <h2>📊 Analysis Summary</h2>
        <div class="summary">
            <div class="metric">
                <div class="metric-value">$($AnalysisResults.TotalFiles)</div>
                <div class="metric-label">Total Files</div>
            </div>
            <div class="metric">
                <div class="metric-value">$($AnalysisResults.FilesScanned)</div>
                <div class="metric-label">Files Scanned</div>
            </div>
            <div class="metric high">
                <div class="metric-value">$($AnalysisResults.HighSeverityIssues)</div>
                <div class="metric-label">High Severity</div>
            </div>
            <div class="metric medium">
                <div class="metric-value">$($AnalysisResults.MediumSeverityIssues)</div>
                <div class="metric-label">Medium Severity</div>
            </div>
            <div class="metric low">
                <div class="metric-value">$($AnalysisResults.LowSeverityIssues)</div>
                <div class="metric-label">Low Severity</div>
            </div>
        </div>
"@

if ($ComplianceIssues.Count -eq 0) {
    $HtmlReport += @"
        <div class="no-issues">
            ✅ No sandbox compliance issues detected!<br>
            Your application appears to be compatible with Azure App Service sandbox restrictions.
        </div>
"@
} else {
    $HtmlReport += @"
        <h2>🚨 Compliance Issues Detected</h2>
        <table>
            <tr>
                <th>File</th>
                <th>Line</th>
                <th>Category</th>
                <th>Severity</th>
                <th>Code</th>
                <th>Impact</th>
                <th>Recommended Solution</th>
                <th>Documentation</th>
            </tr>
"@

    foreach ($Issue in ($ComplianceIssues | Sort-Object Severity, File, Line)) {
        $SeverityClass = "severity-$($Issue.Severity.ToLower())"
        $HtmlReport += @"
            <tr class="$SeverityClass">
                <td>$($Issue.File)</td>
                <td>$($Issue.Line)</td>
                <td>$($Issue.Category)</td>
                <td>$($Issue.Severity)</td>
                <td class="code">$([System.Web.HttpUtility]::HtmlEncode($Issue.Content))</td>
                <td>$($Issue.Impact)</td>
                <td class="recommendation">$($Issue.Solution)</td>
                <td><a href="$($Issue.Documentation)" class="documentation-link" target="_blank">Learn more</a></td>
            </tr>
"@
    }
    $HtmlReport += "</table>"
}

$HtmlReport += @"
        <h2>📋 Next Steps</h2>
        <ol>
            <li><strong>Address High Severity Issues:</strong> These must be resolved before deployment to Azure App Service</li>
            <li><strong>Review Medium Severity Issues:</strong> These may cause runtime failures or reduced functionality</li>
            <li><strong>Test Modifications:</strong> Validate all changes in a development environment</li>
            <li><strong>Update Documentation:</strong> Document all architectural changes made for compliance</li>
        </ol>
        
        <h2>📚 Additional Resources</h2>
        <ul>
            <li><a href="https://learn.microsoft.com/azure/app-service/overview-app-service-sandbox" target="_blank">Azure App Service Sandbox Overview</a></li>
            <li><a href="https://learn.microsoft.com/azure/app-service/configure-common" target="_blank">Configure App Settings</a></li>
            <li><a href="https://learn.microsoft.com/azure/azure-monitor/app/asp-net" target="_blank">Application Insights for .NET</a></li>
            <li><a href="https://learn.microsoft.com/azure/storage/blobs/" target="_blank">Azure Blob Storage</a></li>
        </ul>
    </div>
</body>
</html>
"@

# Save report
$HtmlReport | Out-File -FilePath $OutputReport -Encoding UTF8

# Display summary
Write-Host "`n=== Compliance Analysis Complete ===" -ForegroundColor Green
Write-Host "Files Analyzed: $($AnalysisResults.FilesScanned) of $($AnalysisResults.TotalFiles)" -ForegroundColor White
Write-Host "Issues Found: $($AnalysisResults.IssuesFound)" -ForegroundColor White
Write-Host "  - High Severity: $($AnalysisResults.HighSeverityIssues)" -ForegroundColor Red
Write-Host "  - Medium Severity: $($AnalysisResults.MediumSeverityIssues)" -ForegroundColor Yellow  
Write-Host "  - Low Severity: $($AnalysisResults.LowSeverityIssues)" -ForegroundColor Green
Write-Host "Report saved to: $OutputReport" -ForegroundColor Cyan

if ($IncludeRecommendations -and $ComplianceIssues.Count -gt 0) {
    Write-Host "`n💡 Priority Recommendations:" -ForegroundColor Yellow
    
    $HighSeverityIssues = $ComplianceIssues | Where-Object { $_.Severity -eq 'High' } | Group-Object Category
    foreach ($Group in $HighSeverityIssues) {
        Write-Host "  ⚠️  $($Group.Name): $($Group.Count) occurrences" -ForegroundColor Red
    }
}
```
        .high { background-color: #ffebee; }
        .medium { background-color: #fff3e0; }
        .low { background-color: #f3e5f5; }
    </style>
</head>
<body>
    <h1>Azure Sandbox Violation Report</h1>
    <p>Generated on: $(Get-Date)</p>
    <p>Total violations found: $($violations.Count)</p>
    
    <h2>Summary by Severity</h2>
    <ul>
        <li>High: $($violations | Where-Object {$_.Severity -eq "High"} | Measure-Object | Select-Object -ExpandProperty Count)</li>
        <li>Medium: $($violations | Where-Object {$_.Severity -eq "Medium"} | Measure-Object | Select-Object -ExpandProperty Count)</li>
        <li>Low: $($violations | Where-Object {$_.Severity -eq "Low"} | Measure-Object | Select-Object -ExpandProperty Count)</li>
    </ul>
    
    <h2>Detailed Violations</h2>
    <table>
        <tr>
            <th>Type</th>
            <th>File</th>
            <th>Line</th>
            <th>Code</th>
            <th>Severity</th>
            <th>Recommendation</th>
        </tr>
"@

foreach ($violation in $violations) {
    $cssClass = $violation.Severity.ToLower()
    $html += @"
        <tr class="$cssClass">
            <td>$($violation.Type)</td>
            <td>$($violation.File)</td>
            <td>$($violation.Line)</td>
            <td><code>$($violation.Code)</code></td>
            <td>$($violation.Severity)</td>
            <td>$($violation.Recommendation)</td>
        </tr>
"@
}

$html += @"
    </table>
</body>
</html>
"@

$html | Out-File -FilePath $OutputReport -Encoding UTF8
Write-Host "Report generated: $OutputReport" -ForegroundColor Green
```

### 3.4 Manual Code Review Checklist

Use this checklist for thorough manual review:

#### High-Priority Issues ⚠️
```delphi
{
  HIGH PRIORITY SANDBOX VIOLATIONS:
  
  ❌ Registry Operations:
  - TRegistry.OpenKey()
  - TRegIniFile access
  - RegOpenKeyEx, RegQueryValueEx calls
  
  ❌ System File Access:
  - Hard-coded paths: C:\, D:\, %SystemRoot%
  - Program Files, Windows, System32 directories
  - Temp directory outside app context
  
  ❌ Process Management:
  - CreateProcess, ShellExecute
  - WinExec calls
  - Process enumeration
  
  ❌ External COM Servers:
  - CreateOleObject('Excel.Application')
  - CreateOleObject('Word.Application')  
  - Out-of-process COM objects
}
```

#### Medium-Priority Issues ⚠️
```delphi
{
  MEDIUM PRIORITY SANDBOX VIOLATIONS:
  
  ⚠️ Windows UI APIs:
  - MessageBox, ShowMessage
  - CreateWindow, FindWindow
  - User32.dll, GDI32.dll calls
  
  ⚠️ Event Logging:
  - Windows Event Log writes
  - EventLog component usage
  
  ⚠️ Service Operations:
  - Windows Service control
  - Service enumeration
}
```

## 🔧 Code Remediation Strategies

### 3.5 Registry to App Settings Migration

Transform registry access to use Azure App Settings:

#### Before (Registry Access)
```delphi
// ❌ This will fail in Azure sandbox
procedure ReadSettings;
var
  Registry: TRegistry;
  DatabaseServer: string;
begin
  Registry := TRegistry.Create;
  try
    Registry.RootKey := HKEY_LOCAL_MACHINE;
    if Registry.OpenKey('\SOFTWARE\MyApp\Settings', False) then
    begin
      DatabaseServer := Registry.ReadString('DatabaseServer');
      Registry.CloseKey;
    end;
  finally
    Registry.Free;
  end;
end;
```

#### After (App Settings)
```delphi
// ✅ Azure-compatible approach
function GetAppSetting(const SettingName: string; const DefaultValue: string = ''): string;
var
  EnvironmentVar: string;
begin
  // Read from environment variables (Azure App Settings)
  EnvironmentVar := GetEnvironmentVariable(PChar(SettingName));
  if EnvironmentVar <> '' then
    Result := EnvironmentVar
  else
    Result := DefaultValue;
end;

procedure ReadSettings;
var
  DatabaseServer: string;
begin
  // ✅ Read from Azure App Settings
  DatabaseServer := GetAppSetting('DatabaseServer', 'localhost');
end;
```

### 3.6 File Operations Migration

Transform file system access to use Azure Storage:

#### Before (Local File System)
```delphi
// ❌ Hard-coded paths will fail
procedure SaveDocument(const Content: string; const FileName: string);
var
  FileStream: TFileStream;
  FilePath: string;
begin
  FilePath := 'C:\MyApp\Documents\' + FileName;
  FileStream := TFileStream.Create(FilePath, fmCreate);
  try
    // Save content
  finally
    FileStream.Free;
  end;
end;
```

#### After (Azure Blob Storage)
```delphi
// ✅ Azure Storage compatible
uses
  Azure.Storage.Blobs;

procedure SaveDocumentToAzure(const Content: string; const FileName: string);
var
  BlobClient: TAzureBlobClient;
  ConnectionString: string;
begin
  ConnectionString := GetAppSetting('AzureStorageConnectionString');
  BlobClient := TAzureBlobClient.Create(ConnectionString, 'documents');
  try
    BlobClient.UploadText(FileName, Content);
  finally
    BlobClient.Free;
  end;
end;
```

### 3.7 Logging Migration

Transform Windows Event Log to Application Insights:

#### Before (Event Log)
```delphi
// ❌ Event Log access blocked
procedure LogError(const ErrorMessage: string);
var
  EventLog: TEventLog;
begin
  EventLog := TEventLog.Create(nil);
  try
    EventLog.LogType := ltSystem;
    EventLog.ReportEvent(etError, 0, 0, ErrorMessage, nil);
  finally
    EventLog.Free;
  end;
end;
```

#### After (Application Insights)
```delphi
// ✅ Application Insights compatible
uses
  IdHTTP, IdSSLOpenSSL;

procedure LogToApplicationInsights(const EventType: string; const Message: string);
var
  HTTP: TIdHTTP;
  SSL: TIdSSLIOHandlerSocketOpenSSL;
  InstrumentationKey: string;
  JsonPayload: string;
  Response: string;
begin
  InstrumentationKey := GetAppSetting('APPINSIGHTS_INSTRUMENTATIONKEY');
  if InstrumentationKey = '' then Exit;
  
  HTTP := TIdHTTP.Create;
  SSL := TIdSSLIOHandlerSocketOpenSSL.Create;
  try
    HTTP.IOHandler := SSL;
    
    JsonPayload := Format(
      '{"name":"Microsoft.ApplicationInsights.Event","time":"%s","data":{"baseType":"EventData","baseData":{"name":"%s","properties":{"message":"%s"}}}}',
      [FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"Z"', Now), EventType, Message]
    );
    
    HTTP.Request.ContentType := 'application/json';
    Response := HTTP.Post('https://dc.services.visualstudio.com/v2/track', JsonPayload);
  finally
    SSL.Free;
    HTTP.Free;
  end;
end;
```

## 🧪 Sandbox Compatibility Testing

### 3.8 Local Testing Strategy

Test sandbox compatibility before Azure deployment:

#### Create Sandbox Simulation Environment
```powershell
# Sandbox simulation script
param(
    [string]$ISAPIDllPath,
    [string]$TestDirectory = "C:\SandboxTest"
)

# Create restricted test environment
New-Item -Path $TestDirectory -ItemType Directory -Force
New-Item -Path "$TestDirectory\wwwroot" -ItemType Directory -Force
New-Item -Path "$TestDirectory\App_Data" -ItemType Directory -Force

# Copy ISAPI DLL
Copy-Item $ISAPIDllPath "$TestDirectory\wwwroot\"

# Create web.config for testing
$webConfig = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <handlers>
      <add name="ISAPIHandler" path="*" verb="*" modules="IsapiModule" scriptProcessor="$TestDirectory\wwwroot\$(Split-Path $ISAPIDllPath -Leaf)" resourceType="Unspecified" />
    </handlers>
  </system.webServer>
  <appSettings>
    <!-- Simulate Azure App Settings -->
    <add key="DatabaseServer" value="test-server" />
    <add key="AzureStorageConnectionString" value="test-connection" />
  </appSettings>
</configuration>
"@

$webConfig | Out-File "$TestDirectory\wwwroot\web.config"

# Simulate restricted registry access
Write-Host "Testing registry access simulation..." -ForegroundColor Yellow
# Add registry access tests here

Write-Host "Sandbox test environment created at: $TestDirectory" -ForegroundColor Green
Write-Host "Test your ISAPI DLL in this restricted environment" -ForegroundColor Blue
```

### 3.9 Azure Deployment Testing

Test in a development Azure environment:

```powershell
# Azure sandbox testing script
param(
    [string]$ResourceGroupName,
    [string]$AppServiceName,
    [string]$ISAPIDllPath
)

# Deploy to Azure development slot
az webapp deployment slot create --resource-group $ResourceGroupName --name $AppServiceName --slot "sandbox-test"

# Upload ISAPI DLL
az webapp deploy --resource-group $ResourceGroupName --name $AppServiceName --slot "sandbox-test" --src-path $ISAPIDllPath --type "lib"

# Configure test app settings
az webapp config appsettings set --resource-group $ResourceGroupName --name $AppServiceName --slot "sandbox-test" --settings @'
{
  "TEST_MODE": "true",
  "DatabaseServer": "test-server.database.windows.net",
  "AzureStorageConnectionString": "DefaultEndpointsProtocol=https;AccountName=teststorage;AccountKey=testkey"
}
'@

# Run sandbox compatibility tests
Write-Host "Testing sandbox compatibility..." -ForegroundColor Blue
$testUrl = "https://$AppServiceName-sandbox-test.azurewebsites.net"
$response = Invoke-WebRequest -Uri $testUrl -Method GET -ErrorAction SilentlyContinue

if ($response.StatusCode -eq 200) {
    Write-Host "✅ Basic functionality test passed" -ForegroundColor Green
} else {
    Write-Host "❌ Basic functionality test failed" -ForegroundColor Red
    Write-Host "Status Code: $($response.StatusCode)" -ForegroundColor Yellow
}
```

## 📋 Compliance Checklist

### 3.10 Pre-Deployment Verification

Complete this checklist before Azure deployment:

```text
🔍 Sandbox Compliance Checklist:

Code Analysis:
□ Automated scan completed with zero high-severity violations
□ Manual code review completed
□ All registry access replaced with app settings
□ File paths updated to use app directory or Azure Storage
□ Process creation calls removed or replaced
□ COM objects verified as in-process only
□ Windows UI calls removed (MessageBox, etc.)
□ Event logging replaced with Application Insights

Testing:
□ Local sandbox simulation tests passed
□ Azure development slot testing completed
□ Performance impact of changes measured
□ Error handling updated for new patterns

Documentation:
□ Code changes documented
□ New configuration requirements listed
□ Deployment steps updated
□ Troubleshooting guide enhanced
```

## ⚡ Performance Considerations

### 3.11 Impact Assessment

Measure performance impact of sandbox compliance changes:

```delphi
// Performance measurement helper
type
  TPerformanceTimer = class
  private
    FStartTime: TDateTime;
    FOperationName: string;
  public
    constructor Create(const OperationName: string);
    destructor Destroy; override;
  end;

constructor TPerformanceTimer.Create(const OperationName: string);
begin
  inherited Create;
  FOperationName := OperationName;
  FStartTime := Now;
end;

destructor TPerformanceTimer.Destroy;
var
  Duration: Double;
begin
  Duration := (Now - FStartTime) * 24 * 60 * 60 * 1000; // Convert to milliseconds
  LogToApplicationInsights('Performance', Format('%s completed in %.2f ms', [FOperationName, Duration]));
  inherited Destroy;
end;

// Usage example
procedure SomeOperation;
var
  Timer: TPerformanceTimer;
begin
  Timer := TPerformanceTimer.Create('Database Query');
  try
    // Your operation here
  finally
    Timer.Free; // Automatically logs performance
  end;
end;
```

## ✅ Module 3 Completion

### Knowledge Check
- [ ] I understand Azure sandbox restrictions
- [ ] I've identified all violations in my code
- [ ] I've implemented compliant alternatives
- [ ] I've tested sandbox compatibility
- [ ] I've measured performance impact

### Deliverables
- [ ] **Violation Report**: Automated scan results
- [ ] **Remediated Code**: Updated ISAPI filter code
- [ ] **Test Results**: Sandbox compatibility verification
- [ ] **Performance Report**: Impact analysis of changes

## 🔄 Next Steps

Proceed to **[Module 4: Automated Deployment](04-automated-deployment.md)** to learn how to deploy your compliant ISAPI filter to Azure App Service.

---

### 📚 Additional Resources
- [Azure Web App Sandbox](https://github.com/projectkudu/kudu/wiki/Azure-Web-App-sandbox)
- [App Service Security](https://docs.microsoft.com/azure/app-service/overview-security)
- [Application Insights for .NET](https://docs.microsoft.com/azure/azure-monitor/app/asp-net)
- [Azure Storage SDK for Delphi](https://github.com/azure/azure-storage-net)
