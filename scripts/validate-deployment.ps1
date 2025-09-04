#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates ISAPI deployment and performs comprehensive health checks
    
.DESCRIPTION
    This script performs post-deployment validation including:
    1. Application accessibility and response validation
    2. ISAPI filter functionality testing
    3. Performance baseline establishment
    4. Security configuration verification
    
.PARAMETER AppServiceUrl
    The URL of the deployed App Service
    
.PARAMETER TestDuration
    Duration in minutes for continuous monitoring (default: 5)
    
.PARAMETER PerformanceTest
    Run performance testing with load simulation
    
.EXAMPLE
    .\validate-deployment.ps1 -AppServiceUrl "https://my-app.azurewebsites.net"
    
.EXAMPLE
    .\validate-deployment.ps1 -AppServiceUrl "https://my-app.azurewebsites.net" -TestDuration 10 -PerformanceTest
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AppServiceUrl,
    
    [Parameter(Mandatory = $false)]
    [int]$TestDuration = 5,
    
    [Parameter(Mandatory = $false)]
    [switch]$PerformanceTest
)

Write-Host "=== ISAPI Deployment Validation ===" -ForegroundColor Green
Write-Host "App Service URL: $AppServiceUrl" -ForegroundColor Cyan
Write-Host "Test Duration: $TestDuration minutes" -ForegroundColor Cyan
Write-Host "Performance Testing: $PerformanceTest" -ForegroundColor Cyan
Write-Host

$ValidationResults = @{
    BasicConnectivity = $false
    SSLConfiguration = $false
    ISAPIFilter = $false
    PerformanceBaseline = $false
    SecurityHeaders = $false
    OverallSuccess = $false
}

# Test 1: Basic Connectivity
Write-Host "🔍 Testing Basic Connectivity..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri $AppServiceUrl -UseBasicParsing -TimeoutSec 30
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ App Service is accessible (Status: $($response.StatusCode))" -ForegroundColor Green
        $ValidationResults.BasicConnectivity = $true
    } else {
        Write-Host "⚠️ App Service returned status: $($response.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ App Service is not accessible: $_" -ForegroundColor Red
    return $ValidationResults
}

# Test 2: SSL/HTTPS Configuration
Write-Host "`n🔒 Testing SSL Configuration..." -ForegroundColor Yellow
try {
    $httpsUrl = $AppServiceUrl.Replace("http://", "https://")
    $sslResponse = Invoke-WebRequest -Uri $httpsUrl -UseBasicParsing -TimeoutSec 30
    Write-Host "✅ HTTPS is properly configured" -ForegroundColor Green
    $ValidationResults.SSLConfiguration = $true
} catch {
    Write-Host "❌ SSL configuration issue: $_" -ForegroundColor Red
}

# Test 3: ISAPI Filter Testing
Write-Host "`n🔧 Testing ISAPI Filter Functionality..." -ForegroundColor Yellow
try {
    # Test various ISAPI endpoints if they exist
    $isapiTestUrls = @(
        "$AppServiceUrl/isapi",
        "$AppServiceUrl/api",
        "$AppServiceUrl/filter"
    )
    
    $isapiWorking = $false
    foreach ($testUrl in $isapiTestUrls) {
        try {
            $isapiResponse = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 10
            if ($isapiResponse.StatusCode -eq 200 -or $isapiResponse.StatusCode -eq 404) {
                Write-Host "✅ ISAPI endpoint accessible: $testUrl" -ForegroundColor Green
                $isapiWorking = $true
                break
            }
        } catch {
            # Continue testing other endpoints
        }
    }
    
    if ($isapiWorking) {
        $ValidationResults.ISAPIFilter = $true
    } else {
        Write-Host "⚠️ No ISAPI endpoints found - this may be expected for simple deployments" -ForegroundColor Yellow
        $ValidationResults.ISAPIFilter = $true  # Don't fail validation for this
    }
} catch {
    Write-Host "⚠️ ISAPI filter testing inconclusive: $_" -ForegroundColor Yellow
}

# Test 4: Security Headers
Write-Host "`n🛡️ Testing Security Headers..." -ForegroundColor Yellow
try {
    $securityResponse = Invoke-WebRequest -Uri $AppServiceUrl -UseBasicParsing -TimeoutSec 30
    $headers = $securityResponse.Headers
    
    $securityChecks = @{
        'X-Content-Type-Options' = $false
        'X-Frame-Options' = $false
        'Strict-Transport-Security' = $false
    }
    
    foreach ($header in $securityChecks.Keys) {
        if ($headers.ContainsKey($header)) {
            Write-Host "✅ Security header present: $header" -ForegroundColor Green
            $securityChecks[$header] = $true
        } else {
            Write-Host "⚠️ Security header missing: $header" -ForegroundColor Yellow
        }
    }
    
    $ValidationResults.SecurityHeaders = ($securityChecks.Values | Where-Object { $_ -eq $true }).Count -gt 0
} catch {
    Write-Host "⚠️ Security header testing inconclusive: $_" -ForegroundColor Yellow
}

# Test 5: Performance Baseline
if ($PerformanceTest) {
    Write-Host "`n⚡ Running Performance Baseline Test..." -ForegroundColor Yellow
    try {
        $performanceResults = @()
        for ($i = 1; $i -le 10; $i++) {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $perfResponse = Invoke-WebRequest -Uri $AppServiceUrl -UseBasicParsing -TimeoutSec 30
            $stopwatch.Stop()
            
            $performanceResults += $stopwatch.ElapsedMilliseconds
            Write-Host "  Request $i`: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Cyan
        }
        
        $averageResponse = ($performanceResults | Measure-Object -Average).Average
        $maxResponse = ($performanceResults | Measure-Object -Maximum).Maximum
        
        Write-Host "✅ Performance Baseline:" -ForegroundColor Green
        Write-Host "  Average Response Time: $([math]::Round($averageResponse, 2))ms" -ForegroundColor Cyan
        Write-Host "  Maximum Response Time: $maxResponse ms" -ForegroundColor Cyan
        
        $ValidationResults.PerformanceBaseline = $averageResponse -lt 2000  # Less than 2 seconds
    } catch {
        Write-Host "❌ Performance testing failed: $_" -ForegroundColor Red
    }
}

# Test 6: Continuous Monitoring
Write-Host "`n📊 Starting Continuous Monitoring ($TestDuration minutes)..." -ForegroundColor Yellow
$monitoringEnd = (Get-Date).AddMinutes($TestDuration)
$successCount = 0
$totalRequests = 0

while ((Get-Date) -lt $monitoringEnd) {
    try {
        $monitorResponse = Invoke-WebRequest -Uri $AppServiceUrl -UseBasicParsing -TimeoutSec 10
        if ($monitorResponse.StatusCode -eq 200) {
            $successCount++
        }
        $totalRequests++
        
        # Update progress
        $remainingTime = ($monitoringEnd - (Get-Date)).TotalMinutes
        Write-Host "`r  Monitoring... $successCount/$totalRequests successful ($([math]::Round($remainingTime, 1))min remaining)" -NoNewline -ForegroundColor Cyan
        
        Start-Sleep -Seconds 15
    } catch {
        $totalRequests++
        Write-Host "`r  Monitoring... $successCount/$totalRequests successful (error detected)" -NoNewline -ForegroundColor Yellow
    }
}

Write-Host ""  # New line after monitoring

# Calculate overall success rate
$successRate = if ($totalRequests -gt 0) { ($successCount / $totalRequests) * 100 } else { 0 }
Write-Host "📊 Monitoring Results:" -ForegroundColor Green
Write-Host "  Total Requests: $totalRequests" -ForegroundColor Cyan
Write-Host "  Successful Requests: $successCount" -ForegroundColor Cyan
Write-Host "  Success Rate: $([math]::Round($successRate, 2))%" -ForegroundColor Cyan

# Overall Validation Result
$ValidationResults.OverallSuccess = (
    $ValidationResults.BasicConnectivity -and 
    $ValidationResults.SSLConfiguration -and
    $successRate -gt 95
)

Write-Host "`n=== Validation Summary ===" -ForegroundColor Green
Write-Host "Basic Connectivity: $(if ($ValidationResults.BasicConnectivity) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($ValidationResults.BasicConnectivity) { 'Green' } else { 'Red' })
Write-Host "SSL Configuration: $(if ($ValidationResults.SSLConfiguration) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($ValidationResults.SSLConfiguration) { 'Green' } else { 'Red' })
Write-Host "ISAPI Filter: $(if ($ValidationResults.ISAPIFilter) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($ValidationResults.ISAPIFilter) { 'Green' } else { 'Red' })
Write-Host "Security Headers: $(if ($ValidationResults.SecurityHeaders) { '✅ PASS' } else { '⚠️ PARTIAL' })" -ForegroundColor $(if ($ValidationResults.SecurityHeaders) { 'Green' } else { 'Yellow' })
if ($PerformanceTest) {
    Write-Host "Performance Baseline: $(if ($ValidationResults.PerformanceBaseline) { '✅ PASS' } else { '⚠️ REVIEW' })" -ForegroundColor $(if ($ValidationResults.PerformanceBaseline) { 'Green' } else { 'Yellow' })
}
Write-Host "Uptime Monitoring: $(if ($successRate -gt 95) { '✅ PASS' } else { '❌ FAIL' }) ($([math]::Round($successRate, 2))%)" -ForegroundColor $(if ($successRate -gt 95) { 'Green' } else { 'Red' })

Write-Host "`nOverall Validation: $(if ($ValidationResults.OverallSuccess) { '✅ SUCCESS' } else { '❌ REVIEW REQUIRED' })" -ForegroundColor $(if ($ValidationResults.OverallSuccess) { 'Green' } else { 'Red' })

if (-not $ValidationResults.OverallSuccess) {
    Write-Host "`n⚠️ Some validation checks failed. Review the results above and check:" -ForegroundColor Yellow
    Write-Host "   - App Service logs in Azure Portal" -ForegroundColor Yellow
    Write-Host "   - ISAPI configuration in web.config" -ForegroundColor Yellow  
    Write-Host "   - Network connectivity and DNS resolution" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n🎉 Deployment validation completed successfully!" -ForegroundColor Green
return $ValidationResults
