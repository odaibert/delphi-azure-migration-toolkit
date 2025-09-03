# Module 3: Azure Sandbox Compliance

⏱️ **Duration**: 25 minutes  
🎯 **Learning Objectives**: Ensure ISAPI filter compliance with Azure App Service sandbox  
📋 **Prerequisites**: Module 1 assessment completed, code access available  

## Introduction

Azure App Service operates in a secure sandbox environment that restricts certain operations for security and stability. This module provides a comprehensive guide to identifying and resolving sandbox compatibility issues in your Delphi ISAPI filter.

## 🔒 Understanding Azure Sandbox Restrictions

### 3.1 Sandbox Architecture Overview

Azure App Service sandbox provides isolation through multiple layers:

```text
🏗️ Azure Sandbox Layers:
┌─────────────────────────────────────┐
│        Application Layer            │ ← Your ISAPI Filter
├─────────────────────────────────────┤
│         Runtime Layer              │ ← .NET/IIS Runtime
├─────────────────────────────────────┤
│        Sandbox Layer               │ ← Security Restrictions
├─────────────────────────────────────┤
│      Azure Platform Layer         │ ← Azure Infrastructure
└─────────────────────────────────────┘
```

### 3.2 Critical Restrictions Matrix

| Operation | Allowed | Restriction Level | Alternative |
|-----------|---------|-------------------|-------------|
| **Registry Access** | ❌ | Complete Block | App Settings |
| **File System (System)** | ❌ | Complete Block | Azure Storage |
| **File System (App)** | ✅ | Limited | App Directory Only |
| **Process Creation** | ❌ | Complete Block | Azure Functions |
| **COM (Out-of-process)** | ❌ | Complete Block | In-process Only |
| **Event Log** | ❌ | Complete Block | Application Insights |
| **Win32k.sys APIs** | ❌ | Complete Block | Server-side Only |
| **Network Sockets** | ⚠️ | Restricted | HTTP/HTTPS Only |

## 🔍 Code Analysis and Detection

### 3.3 Automated Sandbox Violation Detection

Create a PowerShell script to scan your Delphi source code:

```powershell
# Sandbox Violation Scanner
param(
    [string]$SourcePath,
    [string]$OutputReport = "sandbox-violations.html"
)

$violations = @()

function Add-Violation {
    param($Type, $File, $Line, $Code, $Severity, $Recommendation)
    $violations += [PSCustomObject]@{
        Type = $Type
        File = $File
        Line = $Line
        Code = $Code
        Severity = $Severity
        Recommendation = $Recommendation
    }
}

function Scan-DelphiFiles {
    param([string]$Path)
    
    $delphiFiles = Get-ChildItem -Path $Path -Recurse -Include "*.pas", "*.dpr", "*.dpk" -ErrorAction SilentlyContinue
    
    foreach ($file in $delphiFiles) {
        $content = Get-Content $file.FullName
        $lineNumber = 0
        
        foreach ($line in $content) {
            $lineNumber++
            
            # Registry violations
            if ($line -match "(TRegistry|RegOpenKey|RegQueryValue|RegSetValue|TRegIniFile)") {
                Add-Violation "Registry Access" $file.Name $lineNumber $line.Trim() "High" "Use Application Settings"
            }
            
            # File system violations
            if ($line -match "(C:\\|D:\\|Program Files|Windows\\|System32)") {
                Add-Violation "Hard-coded Paths" $file.Name $lineNumber $line.Trim() "High" "Use relative paths or Azure Storage"
            }
            
            # Process creation violations
            if ($line -match "(CreateProcess|ShellExecute|WinExec|CreateProcessAsUser)") {
                Add-Violation "Process Creation" $file.Name $lineNumber $line.Trim() "High" "Use Azure Functions or Logic Apps"
            }
            
            # COM violations
            if ($line -match "(CreateOleObject|CreateComObject).*Excel|Word|Outlook") {
                Add-Violation "Out-of-process COM" $file.Name $lineNumber $line.Trim() "High" "Use in-process alternatives"
            }
            
            # Win32 API violations
            if ($line -match "(User32|GDI32|CreateWindow|MessageBox|FindWindow)") {
                Add-Violation "Win32k.sys APIs" $file.Name $lineNumber $line.Trim() "Medium" "Remove UI operations"
            }
            
            # Event log violations
            if ($line -match "(EventLog|ReportEvent|RegisterEventSource)") {
                Add-Violation "Event Log Access" $file.Name $lineNumber $line.Trim() "Medium" "Use Application Insights logging"
            }
        }
    }
}

# Scan all files
Write-Host "Scanning Delphi source files for sandbox violations..." -ForegroundColor Blue
Scan-DelphiFiles -Path $SourcePath

# Generate HTML report
$html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Azure Sandbox Violation Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
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
