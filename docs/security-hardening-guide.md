# ISAPI Azure Security Hardening Guide

This guide provides comprehensive security hardening recommendations for ISAPI applications running on Azure App Service, focusing on **no-code-change migration** with configuration-based security enhancements.

## 🛡️ Security Architecture Overview

### Multi-Layer Security Approach for No-Code Migration
```
┌─────────────────────────────────────┐
│            Azure Front Door         │  ← DDoS Protection, WAF
├─────────────────────────────────────┤
│          Application Gateway        │  ← SSL Termination, WAF Rules  
├─────────────────────────────────────┤
│            App Service              │  ← Your Existing ISAPI DLL
│  ┌─────────────────────────────┐   │
│  │        Key Vault            │   │  ← Secrets Management
│  └─────────────────────────────┘   │
├─────────────────────────────────────┤
│         Managed Identity            │  ← Secure Authentication
├─────────────────────────────────────┤
│          Azure SQL Database         │  ← Encrypted Data Storage
└─────────────────────────────────────┘
```

## 🔐 Configuration-Based Security (No Code Changes Required)

### 1. Azure App Service Configuration Security

Configure your existing ISAPI DLL securely through web.config and Azure portal settings:

#### Web.config Security Configuration
```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <!-- ISAPI Handler (your existing DLL) -->
    <handlers>
      <add name="YourISAPIHandler" 
           path="*" 
           verb="GET,POST,PUT,DELETE" 
           modules="IsapiModule" 
           scriptProcessor="YourISAPI.dll" 
           resourceType="Unspecified" 
           preCondition="bitness64" />
    </handlers>
    
    <!-- Security Headers -->
    <httpProtocol>
      <customHeaders>
        <add name="X-Frame-Options" value="DENY" />
        <add name="X-Content-Type-Options" value="nosniff" />
        <add name="X-XSS-Protection" value="1; mode=block" />
        <add name="Strict-Transport-Security" value="max-age=31536000; includeSubDomains" />
        <add name="Content-Security-Policy" value="default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'; connect-src 'self'; frame-ancestors 'none';" />
        <add name="Referrer-Policy" value="strict-origin-when-cross-origin" />
        <add name="Permissions-Policy" value="geolocation=(), camera=(), microphone=()" />
      </customHeaders>
    </httpProtocol>
    
    <!-- Request Filtering and Size Limits -->
    <security>
      <requestFiltering removeServerHeader="true">
        <requestLimits maxAllowedContentLength="10485760" /> <!-- 10MB limit -->
        <fileExtensions>
          <add fileExtension=".dll" allowed="true" />
          <!-- Block potentially dangerous file types -->
          <add fileExtension=".exe" allowed="false" />
          <add fileExtension=".bat" allowed="false" />
          <add fileExtension=".cmd" allowed="false" />
        </fileExtensions>
      </requestFiltering>
    </security>
    
    <!-- Force HTTPS -->
    <rewrite>
      <rules>
        <rule name="Redirect to HTTPS" stopProcessing="true">
          <match url=".*" />
          <conditions>
            <add input="{HTTPS}" pattern="off" ignoreCase="true" />
            <add input="{HTTP_HOST}" pattern="localhost" negate="true" />
          </conditions>
          <action type="Redirect" url="https://{HTTP_HOST}/{R:0}" 
                  redirectType="Permanent" />
        </rule>
      </rules>
    </rewrite>
    
    <!-- Environment Variable Security -->
    <environmentVariables>
      <!-- Secure path mappings -->
      <add name="SHARED_FOLDER" value="D:\home\shared" />
      <add name="TEMP_FOLDER" value="D:\local\Temp" />
      <add name="DATA_FOLDER" value="D:\home\data" />
      <add name="LOG_FOLDER" value="D:\home\LogFiles" />
      <!-- Database connection will use Managed Identity -->
      <add name="USE_MANAGED_IDENTITY" value="true" />
    </environmentVariables>
  </system.webServer>
  
  <!-- Secure Connection Strings (No Code Changes) -->
  <connectionStrings>
    <!-- Use Managed Identity for Azure SQL Database -->
    <add name="DefaultConnection" 
         connectionString="Server=tcp:your-server.database.windows.net,1433;Database=YourDB;Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;" />
  </connectionStrings>
  
  <!-- Application Settings Security -->
  <appSettings>
    <!-- Replace registry-based configuration -->
    <add key="YourApp.Setting1" value="SecureValue1" />
    <add key="YourApp.Setting2" value="SecureValue2" />
    <!-- Use Key Vault references for sensitive data -->
    <add key="YourApp.ApiKey" value="@Microsoft.KeyVault(SecretUri=https://your-vault.vault.azure.net/secrets/api-key/)" />
  </appSettings>
</configuration>
```

### 2. Key Vault Secret Management Script

```powershell
# scripts/manage-secrets.ps1

#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Manage secrets in Azure Key Vault for ISAPI applications
    
.PARAMETER KeyVaultName
    The name of the Key Vault
    
.PARAMETER Action
    The action to perform (Set, Get, List, Delete)
    
.PARAMETER SecretName
    The name of the secret
    
.PARAMETER SecretValue
    The value of the secret (for Set action)
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName,
    
    [Parameter(Mandatory = $true)]
    [ValidateSet("Set", "Get", "List", "Delete")]
    [string]$Action,
    
    [Parameter(Mandatory = $false)]
    [string]$SecretName,
    
    [Parameter(Mandatory = $false)]
    [string]$SecretValue
)

function Set-KeyVaultSecrets {
    Write-Host "🔐 Setting up standard ISAPI secrets in Key Vault: $KeyVaultName" -ForegroundColor Green
    
    # Standard secrets for ISAPI applications
    $secrets = @{
        "database-connection-string" = "Server=tcp:your-server.database.windows.net,1433;Initial Catalog=YourDB;Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
        "storage-account-key" = "DefaultEndpointsProtocol=https;AccountName=yourstorageaccount;AccountKey=your-key;EndpointSuffix=core.windows.net"
        "application-insights-key" = "your-application-insights-instrumentation-key"
        "third-party-api-key" = "your-third-party-api-key"
        "jwt-signing-key" = "your-jwt-signing-secret"
        "encryption-key" = "your-application-encryption-key"
        "admin-password" = "your-admin-interface-password"
        "session-encryption-key" = "your-session-encryption-key"
    }
    
    foreach ($secret in $secrets.GetEnumerator()) {
        Write-Host "  Setting secret: $($secret.Key)" -ForegroundColor Cyan
        
        az keyvault secret set `
            --vault-name $KeyVaultName `
            --name $secret.Key `
            --value $secret.Value `
            --content-type "text/plain" `
            --output none
            
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ Secret set: $($secret.Key)" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Failed to set secret: $($secret.Key)" -ForegroundColor Red
        }
    }
}

switch ($Action) {
    "Set" {
        if ($SecretName -and $SecretValue) {
            Write-Host "Setting secret: $SecretName" -ForegroundColor Yellow
            az keyvault secret set --vault-name $KeyVaultName --name $SecretName --value $SecretValue
        } else {
            Set-KeyVaultSecrets
        }
    }
    "Get" {
        if (-not $SecretName) {
            Write-Host "SecretName parameter is required for Get action" -ForegroundColor Red
            exit 1
        }
        Write-Host "Getting secret: $SecretName" -ForegroundColor Yellow
        az keyvault secret show --vault-name $KeyVaultName --name $SecretName --query value --output tsv
    }
    "List" {
        Write-Host "Listing secrets in Key Vault: $KeyVaultName" -ForegroundColor Yellow
        az keyvault secret list --vault-name $KeyVaultName --output table
    }
    "Delete" {
        if (-not $SecretName) {
            Write-Host "SecretName parameter is required for Delete action" -ForegroundColor Red
            exit 1
        }
        Write-Host "Deleting secret: $SecretName" -ForegroundColor Yellow
        az keyvault secret delete --vault-name $KeyVaultName --name $SecretName
    }
}
```

## 🛡️ Security Hardening Checklist

### Application-Level Security

#### 1. Input Validation and Sanitization
```pascal
function SanitizeInput(const Input: string): string;
var
  i: Integer;
  AllowedChars: set of Char;
begin
  // Define allowed characters based on your requirements
  AllowedChars := ['a'..'z', 'A'..'Z', '0'..'9', '@', '.', '-', '_'];
  
  Result := '';
  for i := 1 to Length(Input) do
  begin
    if CharInSet(Input[i], AllowedChars) then
      Result := Result + Input[i];
  end;
  
  // Limit length to prevent buffer overflow attacks
  if Length(Result) > 255 then
    Result := Copy(Result, 1, 255);
end;

function ValidateEmail(const Email: string): Boolean;
var
  EmailRegex: TRegEx;
begin
  EmailRegex := TRegEx.Create('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  Result := EmailRegex.IsMatch(Email);
end;
```

#### 2. SQL Injection Prevention
```pascal
function ExecuteSecureQuery(const SQL: string; const Params: array of Variant): TDataSet;
var
  Query: TADOQuery;
  i: Integer;
begin
  Query := TADOQuery.Create(nil);
  try
    Query.Connection := DatabaseConnection;
    Query.SQL.Text := SQL;
    
    // Use parameterized queries
    for i := 0 to High(Params) do
      Query.Parameters[i].Value := Params[i];
    
    Query.Open;
    Result := Query;
  except
    Query.Free;
    raise;
  end;
end;

// Example usage:
procedure GetUserByEmail(const Email: string);
var
  Query: TDataSet;
begin
  // Safe parameterized query
  Query := ExecuteSecureQuery(
    'SELECT * FROM Users WHERE Email = ?', 
    [SanitizeInput(Email)]
  );
  try
    // Process results
  finally
    Query.Free;
  end;
end;
```

#### 3. Session Management
```pascal
unit SecureSession;

interface

type
  TSecureSession = class
  private
    FSessionId: string;
    FCreationTime: TDateTime;
    FLastAccess: TDateTime;
    FUserData: TStringList;
    function GenerateSecureSessionId: string;
    function IsSessionExpired: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RefreshSession;
    function GetValue(const Key: string): string;
    procedure SetValue(const Key, Value: string);
    property SessionId: string read FSessionId;
    property IsExpired: Boolean read IsSessionExpired;
  end;

implementation

uses
  System.DateUtils, System.Hash;

constructor TSecureSession.Create;
begin
  inherited;
  FUserData := TStringList.Create;
  FSessionId := GenerateSecureSessionId;
  FCreationTime := Now;
  FLastAccess := Now;
end;

function TSecureSession.GenerateSecureSessionId: string;
var
  RandomBytes: TBytes;
  i: Integer;
begin
  SetLength(RandomBytes, 32);
  
  // Generate cryptographically secure random bytes
  for i := 0 to High(RandomBytes) do
    RandomBytes[i] := Random(256);
  
  Result := THashSHA2.GetHashString(RandomBytes, THashSHA2.TSHA2Version.SHA256);
end;

function TSecureSession.IsSessionExpired: Boolean;
const
  SESSION_TIMEOUT_MINUTES = 30;
begin
  Result := MinutesBetween(Now, FLastAccess) > SESSION_TIMEOUT_MINUTES;
end;

procedure TSecureSession.RefreshSession;
begin
  FLastAccess := Now;
end;
```

### Infrastructure Security

#### 1. Web.config Security Headers
```xml
<!-- Enhanced security headers in web.config -->
<system.web>
  <httpCookies httpOnlyCookies="true" requireSSL="true" lockItem="true" />
  <machineKey 
    validationKey="[Generate 128 hex chars]"
    decryptionKey="[Generate 48 hex chars]" 
    validation="HMACSHA256" 
    decryption="AES" />
</system.web>

<system.webServer>
  <httpProtocol>
    <customHeaders>
      <!-- Security headers -->
      <add name="X-Frame-Options" value="DENY" />
      <add name="X-Content-Type-Options" value="nosniff" />
      <add name="X-XSS-Protection" value="1; mode=block" />
      <add name="Strict-Transport-Security" value="max-age=31536000; includeSubDomains" />
      <add name="Content-Security-Policy" value="default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'; connect-src 'self'; frame-ancestors 'none';" />
      <add name="Referrer-Policy" value="strict-origin-when-cross-origin" />
      <add name="Permissions-Policy" value="geolocation=(), camera=(), microphone=()" />
    </customHeaders>
  </httpProtocol>
  
  <!-- Remove server information -->
  <security>
    <requestFiltering removeServerHeader="true">
      <requestLimits maxAllowedContentLength="10485760" /> <!-- 10MB limit -->
    </requestFiltering>
  </security>
  
  <!-- URL rewrite for HTTPS enforcement -->
  <rewrite>
    <rules>
      <rule name="Redirect to HTTPS" stopProcessing="true">
        <match url=".*" />
        <conditions>
          <add input="{HTTPS}" pattern="off" ignoreCase="true" />
          <add input="{HTTP_HOST}" pattern="localhost" negate="true" />
        </conditions>
        <action type="Redirect" url="https://{HTTP_HOST}/{R:0}" 
                redirectType="Permanent" />
      </rule>
    </rules>
  </rewrite>
</system.webServer>
```

#### 2. Network Security Configuration Script
```powershell
# scripts/configure-network-security.ps1

#!/usr/bin/env pwsh

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$AppServiceName
)

Write-Host "🔒 Configuring network security for $AppServiceName" -ForegroundColor Green

# 1. Configure IP restrictions (whitelist approach)
Write-Host "Setting up IP restrictions..." -ForegroundColor Yellow

# Allow only specific IP ranges (customize based on your requirements)
$ipRestrictions = @(
    @{ name = "AllowOfficeNetwork"; ipAddress = "203.0.113.0/24"; priority = 100; action = "Allow" }
    @{ name = "AllowDataCenter"; ipAddress = "198.51.100.0/24"; priority = 200; action = "Allow" }
    @{ name = "AllowAzureServices"; ipAddress = "0.0.0.0/0"; priority = 300; action = "Deny" }
)

foreach ($restriction in $ipRestrictions) {
    az webapp config access-restriction add `
        --resource-group $ResourceGroupName `
        --name $AppServiceName `
        --rule-name $restriction.name `
        --action $restriction.action `
        --ip-address $restriction.ipAddress `
        --priority $restriction.priority
}

# 2. Enable HTTPS only
Write-Host "Enabling HTTPS only..." -ForegroundColor Yellow
az webapp update --resource-group $ResourceGroupName --name $AppServiceName --https-only true

# 3. Configure minimum TLS version
Write-Host "Setting minimum TLS version to 1.2..." -ForegroundColor Yellow
az webapp config set --resource-group $ResourceGroupName --name $AppServiceName --min-tls-version 1.2

# 4. Enable client certificate authentication (optional for high security)
Write-Host "Configuring client certificate settings..." -ForegroundColor Yellow
az webapp update --resource-group $ResourceGroupName --name $AppServiceName --client-cert-enabled true

# 5. Configure custom domain with SSL (if you have a custom domain)
# az webapp config hostname add --webapp-name $AppServiceName --resource-group $ResourceGroupName --hostname yourdomain.com
# az webapp config ssl bind --certificate-thumbprint [THUMBPRINT] --ssl-type SNI --name $AppServiceName --resource-group $ResourceGroupName

Write-Host "✅ Network security configuration completed" -ForegroundColor Green
```

### 3. Database Security Configuration

#### Azure SQL Database Security
```sql
-- Create dedicated database user for the application
CREATE USER [your-app-service-name] FROM EXTERNAL PROVIDER;

-- Grant minimal required permissions
ALTER ROLE db_datareader ADD MEMBER [your-app-service-name];
ALTER ROLE db_datawriter ADD MEMBER [your-app-service-name];

-- Create application-specific schema
CREATE SCHEMA app_data;

-- Grant schema-level permissions instead of database-wide
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::app_data TO [your-app-service-name];

-- Enable auditing
ALTER DATABASE SCOPED CONFIGURATION SET QUERY_STORE = ON;

-- Configure row-level security if needed
CREATE FUNCTION dbo.fn_securitypredicate(@UserId int)  
RETURNS TABLE  
WITH SCHEMABINDING  
AS  
RETURN SELECT 1 AS fn_securitypredicate_result   
WHERE @UserId = USER_ID();

-- Apply the security policy
CREATE SECURITY POLICY dbo.UserSecurityPolicy  
ADD FILTER PREDICATE dbo.fn_securitypredicate(UserId) ON dbo.UserData  
WITH (STATE = ON);
```

### 4. Monitoring and Alerting Security Events

```powershell
# Add security-specific alerts to your monitoring setup

# Failed authentication attempts
az monitor metrics alert create `
    --name "ISAPI-SecurityAlert-FailedAuth-$AppServiceName" `
    --resource-group $ResourceGroupName `
    --scopes $appInsights.id `
    --condition "avg requests/failed > 10" `
    --description "High number of failed authentication attempts detected" `
    --evaluation-frequency 1m `
    --window-size 5m `
    --severity 1 `
    --action $actionGroupId

# Unusual traffic patterns
az monitor metrics alert create `
    --name "ISAPI-SecurityAlert-UnusualTraffic-$AppServiceName" `
    --resource-group $ResourceGroupName `
    --scopes $appService.id `
    --condition "avg Http2xx > 1000" `
    --description "Unusual traffic pattern detected (potential DDoS)" `
    --evaluation-frequency 1m `
    --window-size 5m `
    --severity 2 `
    --action $actionGroupId
```

### 5. Security Testing Script

```powershell
# scripts/security-test.ps1

#!/usr/bin/env pwsh

param(
    [Parameter(Mandatory = $true)]
    [string]$TargetUrl
)

Write-Host "🔍 Running security tests against: $TargetUrl" -ForegroundColor Green

$securityTests = @(
    @{
        Name = "HTTPS Enforcement"
        Test = {
            $httpUrl = $TargetUrl.Replace("https://", "http://")
            try {
                $response = Invoke-WebRequest -Uri $httpUrl -MaximumRedirection 0 -ErrorAction Stop
                return @{ Passed = $false; Message = "HTTP request not redirected to HTTPS" }
            } catch {
                if ($_.Exception.Response.StatusCode -eq "MovedPermanently" -or 
                    $_.Exception.Response.StatusCode -eq "Found") {
                    return @{ Passed = $true; Message = "HTTP properly redirected to HTTPS" }
                }
                return @{ Passed = $false; Message = "Unexpected response to HTTP request" }
            }
        }
    },
    @{
        Name = "Security Headers"
        Test = {
            $response = Invoke-WebRequest -Uri $TargetUrl
            $requiredHeaders = @("X-Frame-Options", "X-Content-Type-Options", "X-XSS-Protection", "Strict-Transport-Security")
            $missingHeaders = @()
            
            foreach ($header in $requiredHeaders) {
                if (-not $response.Headers.ContainsKey($header)) {
                    $missingHeaders += $header
                }
            }
            
            if ($missingHeaders.Count -eq 0) {
                return @{ Passed = $true; Message = "All required security headers present" }
            } else {
                return @{ Passed = $false; Message = "Missing headers: $($missingHeaders -join ', ')" }
            }
        }
    },
    @{
        Name = "TLS Version"
        Test = {
            try {
                # Test with TLS 1.0 (should fail)
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls
                $response = Invoke-WebRequest -Uri $TargetUrl -ErrorAction Stop
                return @{ Passed = $false; Message = "Server accepts TLS 1.0 (security risk)" }
            } catch {
                # Test with TLS 1.2 (should succeed)
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
                try {
                    $response = Invoke-WebRequest -Uri $TargetUrl -ErrorAction Stop
                    return @{ Passed = $true; Message = "Server properly enforces TLS 1.2+" }
                } catch {
                    return @{ Passed = $false; Message = "Server not accessible with TLS 1.2" }
                }
            }
        }
    }
)

$testResults = @{
    Passed = 0
    Failed = 0
    Details = @()
}

foreach ($test in $securityTests) {
    Write-Host "Testing: $($test.Name)..." -ForegroundColor Yellow
    
    try {
        $result = & $test.Test
        
        if ($result.Passed) {
            $testResults.Passed++
            Write-Host "✅ $($test.Name): $($result.Message)" -ForegroundColor Green
        } else {
            $testResults.Failed++
            Write-Host "❌ $($test.Name): $($result.Message)" -ForegroundColor Red
        }
        
        $testResults.Details += @{
            Test = $test.Name
            Passed = $result.Passed
            Message = $result.Message
        }
        
    } catch {
        $testResults.Failed++
        $errorMessage = "Test execution failed: $($_.Exception.Message)"
        Write-Host "❌ $($test.Name): $errorMessage" -ForegroundColor Red
        
        $testResults.Details += @{
            Test = $test.Name
            Passed = $false
            Message = $errorMessage
        }
    }
}

Write-Host "`n📊 Security Test Summary:" -ForegroundColor Cyan
Write-Host "Passed: $($testResults.Passed)" -ForegroundColor Green
Write-Host "Failed: $($testResults.Failed)" -ForegroundColor Red

if ($testResults.Failed -gt 0) {
    Write-Host "`n⚠️ Security issues detected. Please review and address the failed tests." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "`n✅ All security tests passed!" -ForegroundColor Green
}
```

## 🎯 Production Deployment Security Checklist

### Pre-Deployment Security Validation

- [ ] **Secrets Management**
  - [ ] All sensitive data stored in Key Vault
  - [ ] No hardcoded credentials in code
  - [ ] Managed Identity properly configured
  - [ ] Secret rotation policy defined

- [ ] **Code Security**
  - [ ] Static code analysis completed
  - [ ] Dependency vulnerability scan performed
  - [ ] Input validation implemented
  - [ ] SQL injection protection verified

- [ ] **Infrastructure Security**
  - [ ] HTTPS-only enforcement enabled
  - [ ] TLS 1.2+ minimum version set
  - [ ] Security headers configured
  - [ ] IP restrictions configured (if applicable)
  - [ ] Client certificate authentication (if required)

- [ ] **Database Security**
  - [ ] Managed Identity database authentication
  - [ ] Minimal permission model applied
  - [ ] Database firewall rules configured
  - [ ] Audit logging enabled

- [ ] **Monitoring & Alerting**
  - [ ] Security event monitoring configured
  - [ ] Failed authentication alerts set up
  - [ ] Unusual traffic pattern detection
  - [ ] Security incident response plan documented

### Post-Deployment Security Verification

- [ ] **Security Testing**
  - [ ] Automated security tests passed
  - [ ] Penetration testing completed (for production)
  - [ ] Vulnerability assessment performed
  - [ ] Security configuration verified

- [ ] **Access Control**
  - [ ] Admin access restricted
  - [ ] Service accounts properly configured
  - [ ] Audit trails enabled
  - [ ] Access reviews scheduled

This comprehensive security guide provides the foundation for deploying secure ISAPI applications on Azure App Service. Always follow your organization's specific security policies and consider professional security assessments for production deployments.
