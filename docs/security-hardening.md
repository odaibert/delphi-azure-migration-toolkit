# Azure App Service Security Hardening Guide

This guide provides comprehensive security hardening recommendations for ISAPI applications deployed to Azure App Service.

## 🔒 Core Security Configuration

### 1. HTTPS Enforcement
```powershell
# Enable HTTPS only
az webapp update --resource-group myResourceGroup --name myAppName --https-only true

# Configure custom domain with SSL certificate
az webapp config ssl bind --certificate-thumbprint {thumbprint} --ssl-type SNI --name myAppName --resource-group myResourceGroup
```

### 2. Authentication and Authorization
```json
{
  "auth": {
    "enabled": true,
    "unauthenticatedClientAction": "RedirectToLoginPage",
    "tokenStore": {
      "enabled": true
    },
    "identityProviders": {
      "azureActiveDirectory": {
        "enabled": true,
        "registration": {
          "openIdIssuer": "https://login.microsoftonline.com/{tenant-id}/v2.0",
          "clientId": "{client-id}",
          "clientSecretSettingName": "AAD_CLIENT_SECRET"
        }
      }
    }
  }
}
```

## 🛡️ Network Security

### 1. VNet Integration
```bicep
resource vnetIntegration 'Microsoft.Web/sites/virtualNetworkConnections@2023-01-01' = {
  parent: appService
  name: 'vnet-integration'
  properties: {
    vnetResourceId: virtualNetwork.id
    isSwift: true
  }
}
```

### 2. Access Restrictions
```powershell
# Restrict access to specific IP ranges
az webapp config access-restriction add --resource-group myResourceGroup --name myAppName --rule-name "Office Network" --action Allow --ip-address 203.0.113.0/24 --priority 100

# Block access from specific countries
az webapp config access-restriction add --resource-group myResourceGroup --name myAppName --rule-name "Block Country" --action Deny --ip-address 198.51.100.0/24 --priority 200
```

## 🔐 Application Security

### 1. Key Vault Integration
```bicep
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'kv-${appName}'
  location: location
  properties: {
    enabledForTemplateDeployment: true
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: appService.identity.principalId
        permissions: {
          secrets: ['get', 'list']
        }
      }
    ]
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
}
```

### 2. Managed Identity Configuration
```bicep
resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: appName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // ... other properties
    siteConfig: {
      appSettings: [
        {
          name: 'DATABASE_CONNECTION_STRING'
          value: '@Microsoft.KeyVault(SecretUri=https://kv-${appName}.vault.azure.net/secrets/database-connection/)'
        }
      ]
    }
  }
}
```

## 📊 Security Monitoring

### 1. Application Insights Security Events
```json
{
  "customEvents": [
    {
      "name": "Security.LoginAttempt",
      "properties": {
        "userId": "{user-id}",
        "ipAddress": "{client-ip}",
        "userAgent": "{user-agent}",
        "success": true
      }
    },
    {
      "name": "Security.UnauthorizedAccess",
      "properties": {
        "resource": "{protected-resource}",
        "ipAddress": "{client-ip}",
        "timestamp": "{iso-timestamp}"
      }
    }
  ]
}
```

### 2. Security Headers Configuration
```xml
<!-- web.config security headers -->
<configuration>
  <system.webServer>
    <httpProtocol>
      <customHeaders>
        <add name="X-Content-Type-Options" value="nosniff" />
        <add name="X-Frame-Options" value="DENY" />
        <add name="X-XSS-Protection" value="1; mode=block" />
        <add name="Strict-Transport-Security" value="max-age=31536000; includeSubDomains" />
        <add name="Content-Security-Policy" value="default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'" />
        <add name="Referrer-Policy" value="strict-origin-when-cross-origin" />
      </customHeaders>
    </httpProtocol>
  </system.webServer>
</configuration>
```

## 🔍 Security Validation

### 1. Automated Security Scanning
```powershell
# PowerShell security validation script
function Test-SecurityConfiguration {
    param(
        [string]$AppServiceUrl,
        [string]$ResourceGroupName,
        [string]$AppServiceName
    )
    
    $securityChecks = @{
        'HTTPS Enforcement' = $false
        'Security Headers' = $false
        'Authentication' = $false
        'VNet Integration' = $false
    }
    
    # Test HTTPS enforcement
    try {
        $httpResponse = Invoke-WebRequest -Uri $AppServiceUrl.Replace('https://', 'http://') -UseBasicParsing
        if ($httpResponse.StatusCode -eq 301 -or $httpResponse.StatusCode -eq 302) {
            $securityChecks['HTTPS Enforcement'] = $true
        }
    } catch {
        # Expected if HTTPS is properly enforced
        $securityChecks['HTTPS Enforcement'] = $true
    }
    
    # Test security headers
    try {
        $response = Invoke-WebRequest -Uri $AppServiceUrl -UseBasicParsing
        $requiredHeaders = @('X-Content-Type-Options', 'X-Frame-Options', 'Strict-Transport-Security')
        $headersPresent = 0
        
        foreach ($header in $requiredHeaders) {
            if ($response.Headers.ContainsKey($header)) {
                $headersPresent++
            }
        }
        
        $securityChecks['Security Headers'] = ($headersPresent -ge 2)
    } catch {
        Write-Warning "Could not test security headers"
    }
    
    return $securityChecks
}
```

### 2. Compliance Validation
```powershell
# Azure Policy compliance check
az policy state list --resource-group $ResourceGroupName --query "[?policyAssignmentName=='security-baseline'].[complianceState,resourceId]" -o table
```

## 🚨 Incident Response

### 1. Security Alert Configuration
```bicep
resource securityAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'security-alert-unauthorized-access'
  location: 'global'
  properties: {
    description: 'Alert on suspicious authentication patterns'
    severity: 1
    enabled: true
    scopes: [appService.id]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'UnauthorizedRequests'
          metricName: 'Http4xx'
          operator: 'GreaterThan'
          threshold: 10
          timeAggregation: 'Total'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}
```

### 2. Automated Response Actions
```powershell
# Emergency lockdown script
function Start-EmergencyLockdown {
    param(
        [string]$ResourceGroupName,
        [string]$AppServiceName
    )
    
    Write-Host "🚨 EMERGENCY SECURITY LOCKDOWN INITIATED" -ForegroundColor Red
    
    # Enable access restrictions to block all traffic
    az webapp config access-restriction add --resource-group $ResourceGroupName --name $AppServiceName --rule-name "Emergency Block" --action Deny --ip-address "0.0.0.0/0" --priority 1
    
    # Disable FTPS
    az webapp config set --resource-group $ResourceGroupName --name $AppServiceName --ftps-state Disabled
    
    # Rotate sensitive keys
    az webapp auth update --resource-group $ResourceGroupName --name $AppServiceName --enabled false
    
    Write-Host "✅ Emergency lockdown completed" -ForegroundColor Green
    Write-Host "🔍 Review security logs and investigate the incident" -ForegroundColor Yellow
}
```

## 📋 Security Checklist

### Pre-Deployment Security Review
- [ ] HTTPS-only configuration enabled
- [ ] Custom domain with valid SSL certificate
- [ ] Azure AD authentication configured
- [ ] Key Vault integration for secrets
- [ ] Network access restrictions defined
- [ ] Security headers implemented
- [ ] Managed identity configured
- [ ] Application Insights monitoring enabled
- [ ] Security alerting configured
- [ ] Backup and disaster recovery tested

### Regular Security Maintenance
- [ ] Security patches applied monthly
- [ ] Access logs reviewed weekly
- [ ] SSL certificates renewed before expiration
- [ ] Key Vault secrets rotated quarterly
- [ ] Security policies updated per compliance requirements
- [ ] Incident response procedures tested quarterly
- [ ] Vulnerability scanning performed monthly
- [ ] Security training completed by team members

### Compliance Frameworks
- **SOC 2**: Implement logging, monitoring, and access controls
- **ISO 27001**: Document security processes and conduct regular audits
- **GDPR**: Ensure data protection and privacy controls
- **HIPAA**: Implement healthcare-specific security requirements
- **PCI DSS**: Follow payment card industry security standards

## 📚 Additional Resources

- [Azure Security Baseline for App Service](https://learn.microsoft.com/security/benchmark/azure/baselines/app-service-security-baseline)
- [Azure App Service Security Best Practices](https://learn.microsoft.com/azure/app-service/security-recommendations)
- [Azure Key Vault Best Practices](https://learn.microsoft.com/azure/key-vault/general/best-practices)
- [Azure Active Directory Security](https://learn.microsoft.com/azure/active-directory/fundamentals/security-operations-introduction)

---

**⚠️ Security Notice**: This guide provides baseline security recommendations. Additional security measures may be required based on your specific compliance, regulatory, and business requirements.
