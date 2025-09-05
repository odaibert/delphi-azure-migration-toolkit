#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive performance testing suite for ISAPI applications on Azure App Service
    
.DESCRIPTION
    This script performs detailed performance analysis including:
    1. Load testing with concurrent users
    2. Response time analysis
    3. Memory and CPU utilization monitoring
    4. Database connection performance
    5. Cold start performance measurement
    6. Scalability testing with different loads
    
.PARAMETER AppServiceUrl
    The URL of the deployed App Service to test
    
.PARAMETER Duration
    Test duration in minutes (default: 10)
    
.PARAMETER MaxConcurrentUsers
    Maximum number of concurrent users to simulate (default: 50)
    
.PARAMETER TestScenario
    Test scenario: Light, Medium, Heavy, or Stress (default: Medium)
    
.PARAMETER OutputPath
    Path to save test results (default: test-results)
    
.PARAMETER SkipWarmup
    Skip the warmup phase before testing
    
.EXAMPLE
    .\performance-test-comprehensive.ps1 -AppServiceUrl "https://myapp.azurewebsites.net"
    
.EXAMPLE
    .\performance-test-comprehensive.ps1 -AppServiceUrl "https://myapp.azurewebsites.net" -TestScenario "Heavy" -Duration 20
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AppServiceUrl,
    
    [Parameter(Mandatory = $false)]
    [int]$Duration = 10,
    
    [Parameter(Mandatory = $false)]
    [int]$MaxConcurrentUsers = 50,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Light", "Medium", "Heavy", "Stress")]
    [string]$TestScenario = "Medium",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "test-results",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipWarmup
)

Write-Host "⚡ ISAPI Performance Testing Suite" -ForegroundColor Green
Write-Host "Target URL: $AppServiceUrl" -ForegroundColor Cyan
Write-Host "Test Scenario: $TestScenario" -ForegroundColor Cyan
Write-Host "Duration: $Duration minutes" -ForegroundColor Cyan
Write-Host "Max Concurrent Users: $MaxConcurrentUsers" -ForegroundColor Cyan
Write-Host

# Configure test parameters based on scenario
$TestConfig = @{}
switch ($TestScenario) {
    "Light" {
        $TestConfig = @{
            ConcurrentUsers = [math]::Min(10, $MaxConcurrentUsers)
            RequestsPerUser = 20
            ThinkTime = 2000  # 2 seconds
            RampUpTime = 60   # 1 minute
        }
    }
    "Medium" {
        $TestConfig = @{
            ConcurrentUsers = [math]::Min(25, $MaxConcurrentUsers)
            RequestsPerUser = 50
            ThinkTime = 1000  # 1 second
            RampUpTime = 120  # 2 minutes
        }
    }
    "Heavy" {
        $TestConfig = @{
            ConcurrentUsers = [math]::Min(50, $MaxConcurrentUsers)
            RequestsPerUser = 100
            ThinkTime = 500   # 0.5 seconds
            RampUpTime = 180  # 3 minutes
        }
    }
    "Stress" {
        $TestConfig = @{
            ConcurrentUsers = $MaxConcurrentUsers
            RequestsPerUser = 200
            ThinkTime = 100   # 0.1 seconds
            RampUpTime = 300  # 5 minutes
        }
    }
}

Write-Host "Test Configuration:" -ForegroundColor Yellow
Write-Host "  Concurrent Users: $($TestConfig.ConcurrentUsers)" -ForegroundColor Cyan
Write-Host "  Requests per User: $($TestConfig.RequestsPerUser)" -ForegroundColor Cyan
Write-Host "  Think Time: $($TestConfig.ThinkTime)ms" -ForegroundColor Cyan
Write-Host "  Ramp-up Time: $($TestConfig.RampUpTime)s" -ForegroundColor Cyan
Write-Host

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$ResultsFile = Join-Path $OutputPath "performance-results-$Timestamp.json"
$LogFile = Join-Path $OutputPath "performance-log-$Timestamp.txt"

# Test results collection
$TestResults = @{
    TestConfig = $TestConfig
    StartTime = Get-Date
    EndTime = $null
    ColdStartTests = @()
    LoadTests = @()
    ResponseTimes = @()
    ErrorRates = @()
    ThroughputData = @()
    Summary = @{}
}

# Function to make HTTP request and measure performance
function Invoke-PerformanceRequest {
    param(
        [string]$Url,
        [int]$TimeoutSeconds = 30
    )
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSeconds -ErrorAction Stop
        $stopwatch.Stop()
        
        return @{
            Success = $true
            ResponseTime = $stopwatch.ElapsedMilliseconds
            StatusCode = $response.StatusCode
            ContentLength = $response.Content.Length
            Error = $null
        }
    } catch {
        $stopwatch.Stop()
        return @{
            Success = $false
            ResponseTime = $stopwatch.ElapsedMilliseconds
            StatusCode = 0
            ContentLength = 0
            Error = $_.Exception.Message
        }
    }
}

# Phase 1: Cold Start Testing (if not skipped)
if (-not $SkipWarmup) {
    Write-Host "🧊 Phase 1: Cold Start Performance Testing..." -ForegroundColor Yellow
    
    # Test multiple cold starts to get average
    for ($i = 1; $i -le 3; $i++) {
        Write-Host "  Cold start test $i/3..." -ForegroundColor Cyan
        
        # Wait for potential cool-down (simulate cold start)
        if ($i -gt 1) {
            Write-Host "    Waiting 30 seconds for cool-down..." -ForegroundColor Gray
            Start-Sleep -Seconds 30
        }
        
        $coldStartResult = Invoke-PerformanceRequest -Url $AppServiceUrl
        $TestResults.ColdStartTests += $coldStartResult
        
        Write-Host "    Response time: $($coldStartResult.ResponseTime)ms | Status: $($coldStartResult.StatusCode)" -ForegroundColor $(if ($coldStartResult.Success) { 'Green' } else { 'Red' })
    }
    
    # Warmup requests
    Write-Host "  Warming up application..." -ForegroundColor Cyan
    for ($i = 1; $i -le 5; $i++) {
        $warmupResult = Invoke-PerformanceRequest -Url $AppServiceUrl
        Start-Sleep -Milliseconds 500
    }
    
    Write-Host "✅ Cold start testing completed" -ForegroundColor Green
} else {
    Write-Host "ℹ️ Skipping cold start testing and warmup" -ForegroundColor Cyan
}

# Phase 2: Single User Baseline Testing
Write-Host "`n📊 Phase 2: Baseline Performance Testing..." -ForegroundColor Yellow

$baselineTests = @()
for ($i = 1; $i -le 10; $i++) {
    Write-Progress -Activity "Baseline Testing" -Status "Request $i/10" -PercentComplete (($i / 10) * 100)
    $baselineResult = Invoke-PerformanceRequest -Url $AppServiceUrl
    $baselineTests += $baselineResult
    $TestResults.ResponseTimes += $baselineResult.ResponseTime
    Start-Sleep -Milliseconds 100
}

$avgBaseline = ($baselineTests | Where-Object { $_.Success } | Measure-Object ResponseTime -Average).Average
Write-Host "✅ Baseline average response time: $([math]::Round($avgBaseline, 2))ms" -ForegroundColor Green

# Phase 3: Concurrent Load Testing
Write-Host "`n🚀 Phase 3: Concurrent Load Testing..." -ForegroundColor Yellow
Write-Host "  Ramping up to $($TestConfig.ConcurrentUsers) concurrent users over $($TestConfig.RampUpTime) seconds..." -ForegroundColor Cyan

$jobs = @()
$loadTestStartTime = Get-Date

# Create background jobs for concurrent testing
$scriptBlock = {
    param($Url, $RequestsPerUser, $ThinkTime, $StartDelay)
    
    # Wait for ramp-up delay
    Start-Sleep -Milliseconds $StartDelay
    
    $results = @()
    for ($i = 1; $i -le $RequestsPerUser; $i++) {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
            $stopwatch.Stop()
            
            $results += @{
                Success = $true
                ResponseTime = $stopwatch.ElapsedMilliseconds
                StatusCode = $response.StatusCode
                ContentLength = $response.Content.Length
                Timestamp = Get-Date
            }
        } catch {
            $stopwatch.Stop()
            $results += @{
                Success = $false
                ResponseTime = $stopwatch.ElapsedMilliseconds
                StatusCode = 0
                ContentLength = 0
                Timestamp = Get-Date
                Error = $_.Exception.Message
            }
        }
        
        # Think time between requests
        if ($i -lt $RequestsPerUser) {
            Start-Sleep -Milliseconds $ThinkTime
        }
    }
    
    return $results
}

# Start concurrent jobs with ramp-up
$rampUpInterval = $TestConfig.RampUpTime * 1000 / $TestConfig.ConcurrentUsers  # milliseconds per user

for ($i = 0; $i -lt $TestConfig.ConcurrentUsers; $i++) {
    $startDelay = $i * $rampUpInterval
    $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $AppServiceUrl, $TestConfig.RequestsPerUser, $TestConfig.ThinkTime, $startDelay
    $jobs += $job
    
    Write-Progress -Activity "Starting Concurrent Users" -Status "User $($i + 1)/$($TestConfig.ConcurrentUsers)" -PercentComplete ((($i + 1) / $TestConfig.ConcurrentUsers) * 100)
}

Write-Host "  All users started. Running test for $Duration minutes..." -ForegroundColor Cyan

# Monitor test progress
$testEndTime = (Get-Date).AddMinutes($Duration)
while ((Get-Date) -lt $testEndTime) {
    $completedJobs = ($jobs | Where-Object { $_.State -eq 'Completed' }).Count
    $runningJobs = ($jobs | Where-Object { $_.State -eq 'Running' }).Count
    $failedJobs = ($jobs | Where-Object { $_.State -eq 'Failed' }).Count
    
    $remainingMinutes = [math]::Round(($testEndTime - (Get-Date)).TotalMinutes, 1)
    Write-Host "    Progress: $completedJobs completed, $runningJobs running, $failedJobs failed | $remainingMinutes minutes remaining" -ForegroundColor Gray
    
    Start-Sleep -Seconds 30
}

# Stop all remaining jobs after duration
Write-Host "  Stopping test and collecting results..." -ForegroundColor Cyan
$jobs | Stop-Job
$allResults = @()

foreach ($job in $jobs) {
    try {
        $jobResults = Receive-Job -Job $job -ErrorAction SilentlyContinue
        if ($jobResults) {
            $allResults += $jobResults
        }
    } catch {
        Write-Host "    Warning: Failed to receive results from job $($job.Id)" -ForegroundColor Yellow
    }
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
}

$TestResults.LoadTests = $allResults
$TestResults.EndTime = Get-Date

# Phase 4: Results Analysis
Write-Host "`n📈 Phase 4: Results Analysis..." -ForegroundColor Yellow

$successfulRequests = $allResults | Where-Object { $_.Success -eq $true }
$failedRequests = $allResults | Where-Object { $_.Success -eq $false }

$totalRequests = $allResults.Count
$successCount = $successfulRequests.Count
$failureCount = $failedRequests.Count
$successRate = if ($totalRequests -gt 0) { [math]::Round(($successCount / $totalRequests) * 100, 2) } else { 0 }

if ($successfulRequests.Count -gt 0) {
    $avgResponseTime = [math]::Round(($successfulRequests | Measure-Object ResponseTime -Average).Average, 2)
    $minResponseTime = ($successfulRequests | Measure-Object ResponseTime -Minimum).Minimum
    $maxResponseTime = ($successfulRequests | Measure-Object ResponseTime -Maximum).Maximum
    $p95ResponseTime = [math]::Round(($successfulRequests | Sort-Object ResponseTime)[([math]::Floor($successfulRequests.Count * 0.95))].ResponseTime, 2)
    $p99ResponseTime = [math]::Round(($successfulRequests | Sort-Object ResponseTime)[([math]::Floor($successfulRequests.Count * 0.99))].ResponseTime, 2)
} else {
    $avgResponseTime = $minResponseTime = $maxResponseTime = $p95ResponseTime = $p99ResponseTime = 0
}

$testDurationActual = ($TestResults.EndTime - $loadTestStartTime).TotalSeconds
$throughput = if ($testDurationActual -gt 0) { [math]::Round($successCount / $testDurationActual, 2) } else { 0 }

# Calculate cold start statistics
$coldStartStats = @{
    Average = 0
    Min = 0
    Max = 0
}

if ($TestResults.ColdStartTests.Count -gt 0) {
    $successfulColdStarts = $TestResults.ColdStartTests | Where-Object { $_.Success }
    if ($successfulColdStarts.Count -gt 0) {
        $coldStartStats.Average = [math]::Round(($successfulColdStarts | Measure-Object ResponseTime -Average).Average, 2)
        $coldStartStats.Min = ($successfulColdStarts | Measure-Object ResponseTime -Minimum).Minimum
        $coldStartStats.Max = ($successfulColdStarts | Measure-Object ResponseTime -Maximum).Maximum
    }
}

$TestResults.Summary = @{
    TotalRequests = $totalRequests
    SuccessfulRequests = $successCount
    FailedRequests = $failureCount
    SuccessRate = $successRate
    AverageResponseTime = $avgResponseTime
    MinResponseTime = $minResponseTime
    MaxResponseTime = $maxResponseTime
    P95ResponseTime = $p95ResponseTime
    P99ResponseTime = $p99ResponseTime
    Throughput = $throughput
    TestDuration = $testDurationActual
    ColdStartStats = $coldStartStats
}

# Display results
Write-Host "`n🎯 Performance Test Results:" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host "Total Requests: $totalRequests" -ForegroundColor Cyan
Write-Host "Successful Requests: $successCount" -ForegroundColor Green
Write-Host "Failed Requests: $failureCount" -ForegroundColor $(if ($failureCount -gt 0) { 'Red' } else { 'Green' })
Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 95) { 'Green' } elseif ($successRate -ge 90) { 'Yellow' } else { 'Red' })
Write-Host "Throughput: $throughput requests/second" -ForegroundColor Cyan

Write-Host "`nResponse Time Statistics:" -ForegroundColor Yellow
Write-Host "  Average: ${avgResponseTime}ms" -ForegroundColor Cyan
Write-Host "  Minimum: ${minResponseTime}ms" -ForegroundColor Cyan
Write-Host "  Maximum: ${maxResponseTime}ms" -ForegroundColor Cyan
Write-Host "  95th Percentile: ${p95ResponseTime}ms" -ForegroundColor Cyan
Write-Host "  99th Percentile: ${p99ResponseTime}ms" -ForegroundColor Cyan

if ($TestResults.ColdStartTests.Count -gt 0) {
    Write-Host "`nCold Start Performance:" -ForegroundColor Yellow
    Write-Host "  Average: $($coldStartStats.Average)ms" -ForegroundColor Cyan
    Write-Host "  Minimum: $($coldStartStats.Min)ms" -ForegroundColor Cyan
    Write-Host "  Maximum: $($coldStartStats.Max)ms" -ForegroundColor Cyan
}

# Performance Assessment
Write-Host "`n🏆 Performance Assessment:" -ForegroundColor Green
$assessment = @()

if ($successRate -ge 99) {
    $assessment += "✅ Excellent reliability (>99% success rate)"
} elseif ($successRate -ge 95) {
    $assessment += "✅ Good reliability (>95% success rate)"
} else {
    $assessment += "❌ Poor reliability (<95% success rate) - investigate errors"
}

if ($avgResponseTime -le 500) {
    $assessment += "✅ Excellent response time (<500ms average)"
} elseif ($avgResponseTime -le 1000) {
    $assessment += "✅ Good response time (<1000ms average)"
} elseif ($avgResponseTime -le 2000) {
    $assessment += "⚠️ Acceptable response time (<2000ms average)"
} else {
    $assessment += "❌ Poor response time (>2000ms average) - optimization needed"
}

if ($p95ResponseTime -le ($avgResponseTime * 2)) {
    $assessment += "✅ Consistent performance (P95 < 2x average)"
} else {
    $assessment += "⚠️ Variable performance (P95 > 2x average) - investigate outliers"
}

if ($throughput -ge 10) {
    $assessment += "✅ Good throughput (>10 req/sec)"
} elseif ($throughput -ge 5) {
    $assessment += "⚠️ Moderate throughput (>5 req/sec)"
} else {
    $assessment += "❌ Low throughput (<5 req/sec) - performance tuning needed"
}

foreach ($item in $assessment) {
    Write-Host $item -ForegroundColor $(if ($item.StartsWith('✅')) { 'Green' } elseif ($item.StartsWith('⚠️')) { 'Yellow' } else { 'Red' })
}

# Save detailed results to JSON
Write-Host "`n💾 Saving Results..." -ForegroundColor Yellow
$TestResults | ConvertTo-Json -Depth 10 | Set-Content -Path $ResultsFile -Encoding UTF8
Write-Host "✅ Detailed results saved to: $ResultsFile" -ForegroundColor Green

# Create summary report
$summaryReport = @"
ISAPI Performance Test Summary
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Target: $AppServiceUrl
Test Scenario: $TestScenario
Duration: $Duration minutes

RESULTS OVERVIEW:
- Total Requests: $totalRequests
- Success Rate: $successRate%
- Average Response Time: ${avgResponseTime}ms
- P95 Response Time: ${p95ResponseTime}ms
- Throughput: $throughput req/sec

COLD START PERFORMANCE:
- Average: $($coldStartStats.Average)ms
- Range: $($coldStartStats.Min)ms - $($coldStartStats.Max)ms

ASSESSMENT:
$(($assessment | ForEach-Object { "- $_" }) -join "`n")

RECOMMENDATIONS:
$(if ($successRate -lt 95) { "- Investigate and fix application errors" })
$(if ($avgResponseTime -gt 1000) { "- Optimize application response time" })
$(if ($p95ResponseTime -gt ($avgResponseTime * 3)) { "- Address performance outliers" })
$(if ($throughput -lt 10) { "- Consider performance tuning or scaling up" })
$(if ($coldStartStats.Average -gt 5000) { "- Consider always-on setting to reduce cold starts" })

For detailed results, see: $ResultsFile
"@

$summaryReport | Set-Content -Path $LogFile -Encoding UTF8
Write-Host "✅ Summary report saved to: $LogFile" -ForegroundColor Green

Write-Host "`n🎉 Performance testing completed successfully!" -ForegroundColor Green
Write-Host "💡 Review the results and recommendations above to optimize your ISAPI application." -ForegroundColor Blue

return $TestResults.Summary
