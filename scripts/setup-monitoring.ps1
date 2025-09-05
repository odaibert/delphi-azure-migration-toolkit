#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Set up comprehensive monitoring and alerting for ISAPI applications on Azure App Service
    
.DESCRIPTION
    This script configures production-ready monitoring including:
    1. Application Insights custom dashboards
    2. Performance alerts and thresholds
    3. Error rate monitoring
    4. Availability monitoring
    5. Custom ISAPI-specific metrics
    6. Log Analytics queries
    
.PARAMETER ResourceGroupName
    The Azure resource group name
    
.PARAMETER AppServiceName
    The App Service name
    
.PARAMETER ApplicationInsightsName
    The Application Insights resource name
    
.PARAMETER NotificationEmail
    Email address for alert notifications
    
.PARAMETER Environment
    Environment name (Dev, Test, Prod) for different alert thresholds
    
.EXAMPLE
    .\setup-monitoring.ps1 -ResourceGroupName "rg-isapi" -AppServiceName "my-isapi-app" -ApplicationInsightsName "ai-my-app" -NotificationEmail "admin@company.com"
    
.EXAMPLE
    .\setup-monitoring.ps1 -ResourceGroupName "rg-prod" -AppServiceName "prod-isapi" -ApplicationInsightsName "ai-prod" -NotificationEmail "alerts@company.com" -Environment "Prod"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$AppServiceName,
    
    [Parameter(Mandatory = $true)]
    [string]$ApplicationInsightsName,
    
    [Parameter(Mandatory = $true)]
    [string]$NotificationEmail,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Dev", "Test", "Prod")]
    [string]$Environment = "Prod"
)

Write-Host "📊 Setting up ISAPI Monitoring and Alerting" -ForegroundColor Green
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Cyan
Write-Host "App Service: $AppServiceName" -ForegroundColor Cyan
Write-Host "Application Insights: $ApplicationInsightsName" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Cyan
Write-Host

# Configure alert thresholds based on environment
$AlertThresholds = @{}
switch ($Environment) {
    "Dev" {
        $AlertThresholds = @{
            ResponseTime = 5000        # 5 seconds
            ErrorRate = 20             # 20%
            AvailabilityThreshold = 90 # 90%
            CPUThreshold = 90          # 90%
            MemoryThreshold = 90       # 90%
        }
    }
    "Test" {
        $AlertThresholds = @{
            ResponseTime = 3000        # 3 seconds
            ErrorRate = 10             # 10%
            AvailabilityThreshold = 95 # 95%
            CPUThreshold = 85          # 85%
            MemoryThreshold = 85       # 85%
        }
    }
    "Prod" {
        $AlertThresholds = @{
            ResponseTime = 2000        # 2 seconds
            ErrorRate = 5              # 5%
            AvailabilityThreshold = 99 # 99%
            CPUThreshold = 80          # 80%
            MemoryThreshold = 80       # 80%
        }
    }
}

Write-Host "Alert Thresholds for $Environment environment:" -ForegroundColor Yellow
Write-Host "  Response Time: $($AlertThresholds.ResponseTime)ms" -ForegroundColor Cyan
Write-Host "  Error Rate: $($AlertThresholds.ErrorRate)%" -ForegroundColor Cyan
Write-Host "  Availability: $($AlertThresholds.AvailabilityThreshold)%" -ForegroundColor Cyan
Write-Host "  CPU Usage: $($AlertThresholds.CPUThreshold)%" -ForegroundColor Cyan
Write-Host "  Memory Usage: $($AlertThresholds.MemoryThreshold)%" -ForegroundColor Cyan
Write-Host

# Step 1: Verify resources exist
Write-Host "🔍 Step 1: Verifying Azure resources..." -ForegroundColor Yellow

try {
    $appService = az webapp show --name $AppServiceName --resource-group $ResourceGroupName --output json | ConvertFrom-Json
    if (-not $appService) {
        throw "App Service not found"
    }
    Write-Host "✅ App Service found: $AppServiceName" -ForegroundColor Green
} catch {
    Write-Host "❌ App Service not found: $AppServiceName" -ForegroundColor Red
    exit 1
}

try {
    $appInsights = az monitor app-insights component show --app $ApplicationInsightsName --resource-group $ResourceGroupName --output json | ConvertFrom-Json
    if (-not $appInsights) {
        throw "Application Insights not found"
    }
    Write-Host "✅ Application Insights found: $ApplicationInsightsName" -ForegroundColor Green
} catch {
    Write-Host "❌ Application Insights not found: $ApplicationInsightsName" -ForegroundColor Red
    exit 1
}

# Step 2: Create Action Group for notifications
Write-Host "`n📧 Step 2: Creating notification action group..." -ForegroundColor Yellow

$actionGroupName = "ag-$AppServiceName-alerts"

$actionGroupJson = @{
    groupShortName = "ISAPIAlerts"
    enabled = $true
    emailReceivers = @(
        @{
            name = "AdminEmail"
            emailAddress = $NotificationEmail
            useCommonAlertSchema = $true
        }
    )
    smsReceivers = @()
    webhookReceivers = @()
    itsmReceivers = @()
    azureAppPushReceivers = @()
    automationRunbookReceivers = @()
    voiceReceivers = @()
    logicAppReceivers = @()
    azureFunctionReceivers = @()
    armRoleReceivers = @()
} | ConvertTo-Json -Depth 10

$actionGroupJson | Out-File -FilePath "temp-action-group.json" -Encoding UTF8

try {
    az monitor action-group create `
        --resource-group $ResourceGroupName `
        --name $actionGroupName `
        --action-group $actionGroupJson

    Write-Host "✅ Action group created: $actionGroupName" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Action group creation failed, it may already exist" -ForegroundColor Yellow
}

Remove-Item "temp-action-group.json" -Force -ErrorAction SilentlyContinue

# Get action group resource ID
$actionGroupId = az monitor action-group show --name $actionGroupName --resource-group $ResourceGroupName --query id --output tsv

# Step 3: Create Application Insights Alerts
Write-Host "`n🚨 Step 3: Creating Application Insights alerts..." -ForegroundColor Yellow

# Alert 1: High Response Time
Write-Host "  Creating high response time alert..." -ForegroundColor Cyan
az monitor metrics alert create `
    --name "ISAPI-HighResponseTime-$AppServiceName" `
    --resource-group $ResourceGroupName `
    --scopes $appInsights.id `
    --condition "avg requests/duration > $($AlertThresholds.ResponseTime)" `
    --description "ISAPI application response time is higher than $($AlertThresholds.ResponseTime)ms" `
    --evaluation-frequency 1m `
    --window-size 5m `
    --severity 2 `
    --action $actionGroupId

# Alert 2: High Error Rate
Write-Host "  Creating high error rate alert..." -ForegroundColor Cyan
az monitor metrics alert create `
    --name "ISAPI-HighErrorRate-$AppServiceName" `
    --resource-group $ResourceGroupName `
    --scopes $appInsights.id `
    --condition "avg requests/failed > $($AlertThresholds.ErrorRate)" `
    --description "ISAPI application error rate is higher than $($AlertThresholds.ErrorRate)%" `
    --evaluation-frequency 1m `
    --window-size 5m `
    --severity 1 `
    --action $actionGroupId

# Alert 3: Low Availability
Write-Host "  Creating low availability alert..." -ForegroundColor Cyan
az monitor metrics alert create `
    --name "ISAPI-LowAvailability-$AppServiceName" `
    --resource-group $ResourceGroupName `
    --scopes $appInsights.id `
    --condition "avg availabilityResults/availabilityPercentage < $($AlertThresholds.AvailabilityThreshold)" `
    --description "ISAPI application availability is lower than $($AlertThresholds.AvailabilityThreshold)%" `
    --evaluation-frequency 1m `
    --window-size 5m `
    --severity 0 `
    --action $actionGroupId

# Step 4: Create App Service Alerts
Write-Host "`n🖥️ Step 4: Creating App Service infrastructure alerts..." -ForegroundColor Yellow

# Alert 4: High CPU Usage
Write-Host "  Creating high CPU usage alert..." -ForegroundColor Cyan
az monitor metrics alert create `
    --name "ISAPI-HighCPU-$AppServiceName" `
    --resource-group $ResourceGroupName `
    --scopes $appService.id `
    --condition "avg CpuPercentage > $($AlertThresholds.CPUThreshold)" `
    --description "App Service CPU usage is higher than $($AlertThresholds.CPUThreshold)%" `
    --evaluation-frequency 1m `
    --window-size 5m `
    --severity 2 `
    --action $actionGroupId

# Alert 5: High Memory Usage
Write-Host "  Creating high memory usage alert..." -ForegroundColor Cyan
az monitor metrics alert create `
    --name "ISAPI-HighMemory-$AppServiceName" `
    --resource-group $ResourceGroupName `
    --scopes $appService.id `
    --condition "avg MemoryPercentage > $($AlertThresholds.MemoryThreshold)" `
    --description "App Service memory usage is higher than $($AlertThresholds.MemoryThreshold)%" `
    --evaluation-frequency 1m `
    --window-size 10m `
    --severity 2 `
    --action $actionGroupId

# Step 5: Set up Availability Testing
Write-Host "`n🌐 Step 5: Creating availability test..." -ForegroundColor Yellow

$availabilityTestName = "ISAPI-AvailabilityTest-$AppServiceName"
$testUrl = "https://$($appService.defaultHostName)"

# Create availability test XML configuration
$availabilityTestXml = @"
<WebTest Name="$availabilityTestName" Id="" Enabled="True" CssProjectStructure="" CssIteration="" Timeout="120" WorkItemIds="" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010" Description="" CredentialUserName="" CredentialPassword="" PreAuthenticate="True" Proxy="default" StopOnError="False" RecordedResultFile="" ResultsLocale="">
  <Items>
    <Request Method="GET" Guid="a5f10126-e4cd-570d-961c-cea43999a200" Version="1.1" Url="$testUrl" ThinkTime="0" Timeout="120" ParseDependentRequests="False" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" ExpectedResponseUrl="" ReportingName="" IgnoreHttpStatusCode="False" />
  </Items>
</WebTest>
"@

$availabilityTestXml | Out-File -FilePath "temp-availability-test.xml" -Encoding UTF8

try {
    az monitor app-insights web-test create `
        --resource-group $ResourceGroupName `
        --app-insights $ApplicationInsightsName `
        --name $availabilityTestName `
        --location "West US 2" `
        --test-locations "us-west-2" `
        --frequency 300 `
        --timeout 120 `
        --enabled true `
        --configuration-file "temp-availability-test.xml"

    Write-Host "✅ Availability test created: $availabilityTestName" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Availability test creation failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

Remove-Item "temp-availability-test.xml" -Force -ErrorAction SilentlyContinue

# Step 6: Create Custom Dashboard
Write-Host "`n📈 Step 6: Creating custom monitoring dashboard..." -ForegroundColor Yellow

$dashboardName = "ISAPI-Dashboard-$AppServiceName"
$dashboardJson = @{
    lenses = @{
        "0" = @{
            order = 0
            parts = @{
                "0" = @{
                    position = @{ x = 0; y = 0; colSpan = 6; rowSpan = 4 }
                    metadata = @{
                        inputs = @(
                            @{
                                name = "ComponentId"
                                value = @{ Name = $ApplicationInsightsName; SubscriptionId = (az account show --query id --output tsv); ResourceGroup = $ResourceGroupName }
                            }
                        )
                        type = "Extension/AppInsightsExtension/PartType/AppMapGallerizedPart"
                    }
                }
                "1" = @{
                    position = @{ x = 6; y = 0; colSpan = 6; rowSpan = 4 }
                    metadata = @{
                        inputs = @(
                            @{
                                name = "ComponentId"
                                value = @{ Name = $ApplicationInsightsName; SubscriptionId = (az account show --query id --output tsv); ResourceGroup = $ResourceGroupName }
                            }
                        )
                        type = "Extension/AppInsightsExtension/PartType/PerformanceCountersPart"
                    }
                }
                "2" = @{
                    position = @{ x = 0; y = 4; colSpan = 12; rowSpan = 4 }
                    metadata = @{
                        inputs = @(
                            @{
                                name = "ComponentId"
                                value = @{ Name = $ApplicationInsightsName; SubscriptionId = (az account show --query id --output tsv); ResourceGroup = $ResourceGroupName }
                            }
                        )
                        type = "Extension/AppInsightsExtension/PartType/RequestsTablePart"
                    }
                }
            }
        }
    }
    metadata = @{
        model = @{
            timeRange = @{
                value = @{ relative = @{ duration = 24; timeUnit = 1 } }
                type = "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
            }
        }
    }
} | ConvertTo-Json -Depth 20

$dashboardJson | Out-File -FilePath "temp-dashboard.json" -Encoding UTF8

try {
    az portal dashboard create `
        --resource-group $ResourceGroupName `
        --name $dashboardName `
        --input-path "temp-dashboard.json" `
        --location "West US 2"

    Write-Host "✅ Custom dashboard created: $dashboardName" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Dashboard creation failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

Remove-Item "temp-dashboard.json" -Force -ErrorAction SilentlyContinue

# Step 7: Create Log Analytics Queries
Write-Host "`n📝 Step 7: Setting up custom log queries..." -ForegroundColor Yellow

$logQueries = @{
    "ISAPI Response Time Trends" = @"
requests
| where timestamp > ago(24h)
| summarize avg(duration), percentile(duration, 95), percentile(duration, 99) by bin(timestamp, 5m)
| order by timestamp desc
"@

    "ISAPI Error Analysis" = @"
requests
| where timestamp > ago(24h) and success == false
| summarize count() by resultCode, name
| order by count_ desc
"@

    "ISAPI Performance Summary" = @"
requests
| where timestamp > ago(1h)
| summarize 
    TotalRequests = count(),
    SuccessfulRequests = countif(success == true),
    FailedRequests = countif(success == false),
    AvgDuration = avg(duration),
    P95Duration = percentile(duration, 95)
"@

    "ISAPI Top Slow Requests" = @"
requests
| where timestamp > ago(4h)
| top 10 by duration desc
| project timestamp, name, duration, resultCode, success
"@
}

Write-Host "Custom log queries for ISAPI monitoring:" -ForegroundColor Cyan
foreach ($queryName in $logQueries.Keys) {
    Write-Host "  - $queryName" -ForegroundColor Gray
}

# Step 8: Generate Monitoring Guide
Write-Host "`n📚 Step 8: Generating monitoring guide..." -ForegroundColor Yellow

$monitoringGuide = @"
# ISAPI Application Monitoring Guide
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## 🎯 Monitoring Overview
Your ISAPI application monitoring has been configured with the following components:

### 📊 Key Metrics Being Monitored
- **Response Time**: Alert if average > $($AlertThresholds.ResponseTime)ms over 5 minutes
- **Error Rate**: Alert if > $($AlertThresholds.ErrorRate)% over 5 minutes  
- **Availability**: Alert if < $($AlertThresholds.AvailabilityThreshold)% over 5 minutes
- **CPU Usage**: Alert if > $($AlertThresholds.CPUThreshold)% over 5 minutes
- **Memory Usage**: Alert if > $($AlertThresholds.MemoryThreshold)% over 10 minutes

### 🚨 Alert Configuration
- **Action Group**: $actionGroupName
- **Notification Email**: $NotificationEmail
- **Environment**: $Environment
- **Alert Severity Levels**:
  - Severity 0 (Critical): Availability issues
  - Severity 1 (Error): High error rates
  - Severity 2 (Warning): Performance degradation

### 📈 Dashboard Access
Access your custom monitoring dashboard:
- Dashboard Name: $dashboardName
- Location: Azure Portal → Dashboards → $dashboardName

### 🔍 Useful Log Analytics Queries
Access Application Insights → Logs and use these queries:

**1. Response Time Trends:**
``````kusto
$($logQueries['ISAPI Response Time Trends'])
``````

**2. Error Analysis:**
``````kusto
$($logQueries['ISAPI Error Analysis'])
``````

**3. Performance Summary:**
``````kusto
$($logQueries['ISAPI Performance Summary'])
``````

**4. Top Slow Requests:**
``````kusto
$($logQueries['ISAPI Top Slow Requests'])
``````

### 🔧 Monitoring Best Practices

#### Daily Monitoring Tasks:
- [ ] Check dashboard for any anomalies
- [ ] Review error rates and investigate spikes
- [ ] Monitor response time trends
- [ ] Verify availability test results

#### Weekly Monitoring Tasks:
- [ ] Analyze performance trends over the week
- [ ] Review and tune alert thresholds if needed
- [ ] Check for any recurring error patterns
- [ ] Update monitoring queries based on findings

#### Monthly Monitoring Tasks:
- [ ] Review overall application performance trends
- [ ] Assess if alert thresholds need adjustment
- [ ] Document any performance optimizations made
- [ ] Update monitoring documentation

### 📞 Incident Response Process

**When you receive an alert:**

1. **Immediate Response (0-5 minutes)**:
   - Check the Azure portal dashboard
   - Verify if the issue is still occurring
   - Check Application Insights for recent errors

2. **Assessment (5-15 minutes)**:
   - Run diagnostic queries to understand scope
   - Check if multiple metrics are affected
   - Determine if this is application or infrastructure issue

3. **Action (15+ minutes)**:
   - If application issue: Check recent deployments
   - If infrastructure issue: Check App Service metrics
   - Consider scaling up if performance-related
   - Document findings and resolution

### 🎛️ Alert Threshold Tuning

Current thresholds are set for **$Environment** environment. Adjust based on your application's normal behavior:

- **Response Time**: Currently $($AlertThresholds.ResponseTime)ms
  - Increase if false positives occur
  - Decrease for stricter monitoring

- **Error Rate**: Currently $($AlertThresholds.ErrorRate)%
  - Consider business impact of errors
  - May need adjustment during high traffic periods

### 📊 Performance Benchmarks

Document your application's normal performance ranges:
- **Typical Response Time**: _____ ms
- **Acceptable Error Rate**: _____ %
- **Normal CPU Usage**: _____ %
- **Normal Memory Usage**: _____ %
- **Peak Traffic Hours**: _____ to _____

### 🔗 Useful Links
- Azure Portal: https://portal.azure.com
- Application Insights: https://portal.azure.com/#resource$($appInsights.id)
- App Service: https://portal.azure.com/#resource$($appService.id)
- Action Group: https://portal.azure.com/#resource$actionGroupId

---
**Next Steps**: 
1. Test alert notifications by temporarily triggering a condition
2. Customize dashboard layout based on your preferences  
3. Set up additional custom metrics if needed
4. Train your team on using the monitoring tools
"@

$monitoringGuideFile = "ISAPI-Monitoring-Guide-$AppServiceName.md"
$monitoringGuide | Set-Content -Path $monitoringGuideFile -Encoding UTF8

Write-Host "✅ Monitoring guide created: $monitoringGuideFile" -ForegroundColor Green

# Final Summary
Write-Host "`n🎉 Monitoring Setup Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host "✅ Action group configured for notifications" -ForegroundColor Green
Write-Host "✅ Performance alerts created (5 alerts)" -ForegroundColor Green  
Write-Host "✅ Availability test configured" -ForegroundColor Green
Write-Host "✅ Custom dashboard created" -ForegroundColor Green
Write-Host "✅ Log Analytics queries prepared" -ForegroundColor Green
Write-Host "✅ Monitoring guide generated" -ForegroundColor Green

Write-Host "`n💡 Next Steps:" -ForegroundColor Blue
Write-Host "1. Open Azure Portal and verify all alerts are enabled" -ForegroundColor Blue
Write-Host "2. Test alert notifications by triggering a condition" -ForegroundColor Blue
Write-Host "3. Review the monitoring guide: $monitoringGuideFile" -ForegroundColor Blue
Write-Host "4. Customize alert thresholds based on your application behavior" -ForegroundColor Blue
Write-Host "5. Train your team on incident response procedures" -ForegroundColor Blue

Write-Host "`n📧 Alert notifications will be sent to: $NotificationEmail" -ForegroundColor Cyan
Write-Host "🎛️ Environment: $Environment (thresholds configured accordingly)" -ForegroundColor Cyan
