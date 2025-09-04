# Production Operations (Optional)

Advanced operational excellence framework for enterprise-grade ISAPI application monitoring, security, and performance optimization in Azure App Service.

**⏱️ Implementation Time**: 4-6 hours  
**👥 Team Involvement**: Operations Team, Security Team, Site Reliability Engineers  
**📋 Prerequisites**: Infrastructure deployed, application running in Azure  
**🔄 Module Status**: **Optional** - Skip if existing monitoring and operational procedures are in place

> 📝 **Optional Module Notice**: This module provides advanced operational capabilities. Organizations with established monitoring and operational procedures can proceed directly to [Module 6: Testing and Validation](06-testing-validation.md). Basic monitoring is already covered in Module 2 (Infrastructure Design).

## Operations Framework Overview

This module implements [Azure Well-Architected Framework - Operational Excellence](https://learn.microsoft.com/azure/architecture/framework/devops/overview) principles and [Azure Monitor best practices](https://learn.microsoft.com/azure/azure-monitor/) for production-ready ISAPI applications.

### Operations Deliverables

- **Comprehensive Monitoring Strategy** with Application Insights and Azure Monitor
- **Security Configuration** following Azure Security Benchmark
- **Performance Optimization** with auto-scaling and resource management
- **Operational Runbooks** for incident response and maintenance
- **Alerting and Notification** framework for proactive monitoring

## 📊 Advanced Monitoring Implementation

### Application Insights Enhanced Configuration

Comprehensive monitoring beyond basic infrastructure setup:

```powershell
# enhanced-monitoring-setup.ps1 - Advanced Application Insights configuration
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$AppServiceName,
    
    [Parameter(Mandatory=$true)]
    [string]$ApplicationInsightsName,
    
    [Parameter(Mandatory=$false)]
    [string]$LogAnalyticsWorkspace,
    
    [Parameter(Mandatory=$false)]
    [int]$RetentionDays = 90
)

Write-Host "=== Enhanced Application Insights Configuration ===" -ForegroundColor Green

# Configure Application Insights with custom telemetry
Write-Host "Configuring Application Insights telemetry..." -ForegroundColor Cyan

# Set up custom performance counters
$PerformanceCounters = @(
    "\\Processor(_Total)\\% Processor Time",
    "\\Memory\\Available Bytes",
    "\\Web Service(_Total)\\Current Connections",
    "\\Web Service(_Total)\\Bytes Total/Sec",
    "\\ASP.NET Applications(__Total__)\\Requests/Sec",
    "\\ASP.NET Applications(__Total__)\\Request Execution Time"
)

foreach ($Counter in $PerformanceCounters) {
    Write-Host "  Adding performance counter: $Counter" -ForegroundColor Gray
    az monitor app-insights component update \
        --app $ApplicationInsightsName \
        --resource-group $ResourceGroupName \
        --performance-counters $Counter
}

# Configure custom dimensions for ISAPI tracking
$CustomDimensions = @{
    "ISAPI_Filter_Name" = "Delphi ISAPI Filter"
    "Application_Version" = "1.0.0"
    "Deployment_Environment" = "Production"
    "Migration_Framework" = "Azure Migration Toolkit"
}

Write-Host "Setting up custom tracking dimensions..." -ForegroundColor Cyan
foreach ($Dimension in $CustomDimensions.GetEnumerator()) {
    az webapp config appsettings set \
        --resource-group $ResourceGroupName \
        --name $AppServiceName \
        --settings "APPINSIGHTS_CUSTOM_$($Dimension.Key)"="$($Dimension.Value)"
}

# Configure availability tests
Write-Host "Setting up availability tests..." -ForegroundColor Cyan

$AvailabilityTest = @{
    name = "$AppServiceName-availability-test"
    location = "East US"
    frequency = 300  # 5 minutes
    timeout = 30
    enabled = $true
    url = "https://$AppServiceName.azurewebsites.net/health"
}

$AvailabilityTestJson = $AvailabilityTest | ConvertTo-Json -Depth 10

# Create availability test using REST API
az rest --method PUT \
    --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.Insights/webtests/$($AvailabilityTest.name)?api-version=2022-06-15" \
    --body "$AvailabilityTestJson"

Write-Host "✅ Enhanced Application Insights configuration completed" -ForegroundColor Green
```

### Custom Monitoring Dashboard

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "dashboardName": {
      "type": "string",
      "defaultValue": "ISAPI-Production-Dashboard"
    },
    "applicationInsightsName": {
      "type": "string"
    },
    "appServiceName": {
      "type": "string"
    }
  },
  "resources": [
    {
      "type": "Microsoft.Portal/dashboards",
      "apiVersion": "2020-09-01-preview",
      "name": "[parameters('dashboardName')]",
      "location": "[resourceGroup().location]",
      "properties": {
        "lenses": [
          {
            "order": 0,
            "parts": [
              {
                "position": { "x": 0, "y": 0, "colSpan": 6, "rowSpan": 4 },
                "metadata": {
                  "inputs": [
                    {
                      "name": "ComponentId",
                      "value": "[resourceId('Microsoft.Insights/components', parameters('applicationInsightsName'))]"
                    }
                  ],
                  "type": "Extension/AppInsightsExtension/PartType/AppMapPart"
                }
              },
              {
                "position": { "x": 6, "y": 0, "colSpan": 6, "rowSpan": 4 },
                "metadata": {
                  "inputs": [
                    {
                      "name": "ComponentId", 
                      "value": "[resourceId('Microsoft.Insights/components', parameters('applicationInsightsName'))]"
                    }
                  ],
                  "type": "Extension/AppInsightsExtension/PartType/FailuresTimelinePart"
                }
              },
              {
                "position": { "x": 0, "y": 4, "colSpan": 12, "rowSpan": 4 },
                "metadata": {
                  "inputs": [
                    {
                      "name": "ComponentId",
                      "value": "[resourceId('Microsoft.Insights/components', parameters('applicationInsightsName'))]"
                    }
                  ],
                  "type": "Extension/AppInsightsExtension/PartType/RequestsTimelinePart"
                }
              }
            ]
          }
        ],
        "metadata": {
          "model": {
            "timeRange": {
              "value": {
                "relative": {
                  "duration": 24,
                  "timeUnit": 1
                }
              },
              "type": "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
            }
          }
        }
      },
      "tags": {
        "Application": "ISAPI Migration",
        "Environment": "Production",
        "ManagedBy": "Azure Migration Toolkit"
      }
    }
  ]
}
```

## 🔒 Security Configuration and Hardening

### Azure Security Center Integration

```powershell
# security-hardening.ps1 - Production security configuration
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$AppServiceName,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableAdvancedThreatProtection = $true
)

Write-Host "=== Security Hardening Configuration ===" -ForegroundColor Green

# Configure security headers
Write-Host "Configuring security headers..." -ForegroundColor Cyan

$SecurityHeaders = @{
    "X-Content-Type-Options" = "nosniff"
    "X-Frame-Options" = "DENY"
    "X-XSS-Protection" = "1; mode=block"
    "Strict-Transport-Security" = "max-age=31536000; includeSubDomains"
    "Content-Security-Policy" = "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'"
    "Referrer-Policy" = "strict-origin-when-cross-origin"
}

foreach ($Header in $SecurityHeaders.GetEnumerator()) {
    Write-Host "  Setting header: $($Header.Key)" -ForegroundColor Gray
    az webapp config set \
        --resource-group $ResourceGroupName \
        --name $AppServiceName \
        --generic-configurations "{\"$($Header.Key)\": \"$($Header.Value)\"}"
}

# Configure HTTPS only
Write-Host "Enforcing HTTPS only..." -ForegroundColor Cyan
az webapp update \
    --resource-group $ResourceGroupName \
    --name $AppServiceName \
    --https-only true

# Configure minimum TLS version
Write-Host "Setting minimum TLS version to 1.2..." -ForegroundColor Cyan
az webapp config set \
    --resource-group $ResourceGroupName \
    --name $AppServiceName \
    --min-tls-version 1.2

# Configure IP restrictions (if needed)
Write-Host "Configuring IP access restrictions..." -ForegroundColor Cyan
# Example: Restrict to corporate IP ranges
$CorporateIpRanges = @(
    "203.0.113.0/24",  # Replace with your corporate IP ranges
    "198.51.100.0/24"  # Replace with your corporate IP ranges
)

$Priority = 100
foreach ($IpRange in $CorporateIpRanges) {
    az webapp config access-restriction add \
        --resource-group $ResourceGroupName \
        --name $AppServiceName \
        --rule-name "Corporate-Access-$Priority" \
        --action Allow \
        --ip-address $IpRange \
        --priority $Priority
    $Priority += 10
}

# Enable Advanced Threat Protection
if ($EnableAdvancedThreatProtection) {
    Write-Host "Enabling Advanced Threat Protection..." -ForegroundColor Cyan
    az security atp storage update \
        --resource-group $ResourceGroupName \
        --storage-account $(az storage account list --resource-group $ResourceGroupName --query "[0].name" -o tsv) \
        --is-enabled true
}

# Configure diagnostic logging
Write-Host "Configuring diagnostic logging..." -ForegroundColor Cyan
az webapp log config \
    --resource-group $ResourceGroupName \
    --name $AppServiceName \
    --application-logging true \
    --level information \
    --web-server-logging filesystem

Write-Host "✅ Security hardening completed" -ForegroundColor Green
```

## ⚡ Performance Optimization and Auto-Scaling

### Auto-Scaling Configuration

```powershell
# auto-scaling-setup.ps1 - Configure auto-scaling rules
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$AppServicePlanName,
    
    [Parameter(Mandatory=$false)]
    [int]$MinInstances = 2,
    
    [Parameter(Mandatory=$false)]
    [int]$MaxInstances = 10,
    
    [Parameter(Mandatory=$false)]
    [int]$CpuThresholdUp = 70,
    
    [Parameter(Mandatory=$false)]
    [int]$CpuThresholdDown = 30
)

Write-Host "=== Configuring Auto-Scaling Rules ===" -ForegroundColor Green

# Create scale-out rule (CPU > 70%)
Write-Host "Creating scale-out rule..." -ForegroundColor Cyan
az monitor autoscale rule create \
    --resource-group $ResourceGroupName \
    --autoscale-name "$AppServicePlanName-autoscale" \
    --condition "Percentage CPU > $CpuThresholdUp avg 5m" \
    --scale out 1 \
    --cooldown 5

# Create scale-in rule (CPU < 30%)
Write-Host "Creating scale-in rule..." -ForegroundColor Cyan
az monitor autoscale rule create \
    --resource-group $ResourceGroupName \
    --autoscale-name "$AppServicePlanName-autoscale" \
    --condition "Percentage CPU < $CpuThresholdDown avg 10m" \
    --scale in 1 \
    --cooldown 10

# Set instance limits
Write-Host "Setting instance limits ($MinInstances-$MaxInstances)..." -ForegroundColor Cyan
az monitor autoscale update \
    --resource-group $ResourceGroupName \
    --name "$AppServicePlanName-autoscale" \
    --min-count $MinInstances \
    --max-count $MaxInstances

# Configure memory-based scaling rule
Write-Host "Creating memory-based scaling rule..." -ForegroundColor Cyan
az monitor autoscale rule create \
    --resource-group $ResourceGroupName \
    --autoscale-name "$AppServicePlanName-autoscale" \
    --condition "Memory Percentage > 80 avg 5m" \
    --scale out 2 \
    --cooldown 5

Write-Host "✅ Auto-scaling configuration completed" -ForegroundColor Green
```

## 🚨 Alerting and Incident Response

### Comprehensive Alert Rules

```powershell
# alert-configuration.ps1 - Set up production alerts
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$AppServiceName,
    
    [Parameter(Mandatory=$true)]
    [string]$ApplicationInsightsName,
    
    [Parameter(Mandatory=$true)]
    [string]$NotificationEmail
)

Write-Host "=== Configuring Production Alerts ===" -ForegroundColor Green

# Create action group for notifications
Write-Host "Creating action group..." -ForegroundColor Cyan
az monitor action-group create \
    --resource-group $ResourceGroupName \
    --name "isapi-production-alerts" \
    --short-name "ISAPI-Prod" \
    --email "production-team" $NotificationEmail

# High CPU alert
Write-Host "Creating high CPU alert..." -ForegroundColor Cyan
az monitor metrics alert create \
    --name "High CPU Usage - $AppServiceName" \
    --resource-group $ResourceGroupName \
    --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$AppServiceName" \
    --condition "avg Percentage CPU > 80" \
    --window-size 5m \
    --evaluation-frequency 1m \
    --action "isapi-production-alerts" \
    --severity 2

# High memory alert
Write-Host "Creating high memory alert..." -ForegroundColor Cyan
az monitor metrics alert create \
    --name "High Memory Usage - $AppServiceName" \
    --resource-group $ResourceGroupName \
    --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$AppServiceName" \
    --condition "avg Memory Percentage > 85" \
    --window-size 5m \
    --evaluation-frequency 1m \
    --action "isapi-production-alerts" \
    --severity 2

# Application failure rate alert
Write-Host "Creating failure rate alert..." -ForegroundColor Cyan
az monitor metrics alert create \
    --name "High Failure Rate - $AppServiceName" \
    --resource-group $ResourceGroupName \
    --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.Insights/components/$ApplicationInsightsName" \
    --condition "avg Failed Requests > 5" \
    --window-size 5m \
    --evaluation-frequency 1m \
    --action "isapi-production-alerts" \
    --severity 1

# Response time alert
Write-Host "Creating response time alert..." -ForegroundColor Cyan
az monitor metrics alert create \
    --name "High Response Time - $AppServiceName" \
    --resource-group $ResourceGroupName \
    --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$AppServiceName" \
    --condition "avg Response Time > 5000" \
    --window-size 5m \
    --evaluation-frequency 1m \
    --action "isapi-production-alerts" \
    --severity 2

# Availability alert
Write-Host "Creating availability alert..." -ForegroundColor Cyan
az monitor metrics alert create \
    --name "Low Availability - $AppServiceName" \
    --resource-group $ResourceGroupName \
    --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.Insights/components/$ApplicationInsightsName" \
    --condition "avg Availability < 99" \
    --window-size 5m \
    --evaluation-frequency 1m \
    --action "isapi-production-alerts" \
    --severity 1

Write-Host "✅ Alert configuration completed" -ForegroundColor Green
```

## 📚 Operational Runbooks

### Incident Response Procedures

#### **High CPU Usage Response**

1. **Immediate Actions** (0-5 minutes):
   ```powershell
   # Check current CPU metrics
   az monitor metrics list --resource /subscriptions/{subscription}/resourceGroups/{rg}/providers/Microsoft.Web/sites/{app} --metric "CpuTime" --interval PT1M
   
   # Scale out immediately if needed
   az appservice plan update --resource-group {rg} --name {plan} --number-of-workers 3
   ```

2. **Investigation** (5-15 minutes):
   - Review Application Insights performance data
   - Check for unusual request patterns
   - Analyze slow requests and dependencies

3. **Resolution** (15+ minutes):
   - Implement code optimizations if identified
   - Adjust auto-scaling thresholds if appropriate
   - Consider upgrading App Service Plan tier

#### **Application Failure Response**

1. **Immediate Actions**:
   ```powershell
   # Check application logs
   az webapp log tail --resource-group {rg} --name {app}
   
   # Check health endpoint
   Invoke-WebRequest -Uri "https://{app}.azurewebsites.net/health" -UseBasicParsing
   ```

2. **Rollback Procedure** (if needed):
   ```powershell
   # Swap back to previous deployment slot
   az webapp deployment slot swap --resource-group {rg} --name {app} --slot production --target-slot staging
   ```

#### **Database Connection Issues**

1. **Check database connectivity**:
   ```powershell
   # Test database connection
   az sql db show --resource-group {rg} --server {server} --name {database}
   
   # Check firewall rules
   az sql server firewall-rule list --resource-group {rg} --server {server}
   ```

2. **Connection string validation**:
   ```powershell
   # Verify app settings
   az webapp config appsettings list --resource-group {rg} --name {app} --query "[?name=='ConnectionStrings:DefaultConnection']"
   ```

## 📋 Advanced Operations Checklist

- [ ] **Enhanced Application Insights** configured with custom telemetry
- [ ] **Security hardening** implemented with proper headers and HTTPS
- [ ] **Auto-scaling rules** configured for CPU and memory thresholds
- [ ] **Comprehensive alerting** set up for critical metrics
- [ ] **Monitoring dashboard** deployed for operations team
- [ ] **Incident response runbooks** documented and tested
- [ ] **Log retention policies** configured according to compliance requirements
- [ ] **Backup and disaster recovery** procedures validated
- [ ] **Performance baseline** established for comparison
- [ ] **Cost monitoring** alerts configured for budget management

## 📚 Reference Documentation

- [Azure Well-Architected Framework - Operational Excellence](https://learn.microsoft.com/azure/architecture/framework/devops/overview)
- [Azure Monitor best practices](https://learn.microsoft.com/azure/azure-monitor/best-practices)
- [App Service monitoring](https://learn.microsoft.com/azure/app-service/web-sites-monitor)
- [Azure Security Benchmark](https://learn.microsoft.com/security/benchmark/azure/)

---

## 🚀 Next Steps

With advanced operations configured, proceed to **[Module 6: Testing and Validation](06-testing-validation.md)** to implement comprehensive testing strategies for your ISAPI migration.

### Navigation
- **← Previous**: [Deployment Automation](04-automated-deployment.md)
- **→ Next**: [Testing and Validation](06-testing-validation.md)
- **🔧 Troubleshooting**: [Operations Issues](../../../docs/troubleshooting.md#operations-issues)
