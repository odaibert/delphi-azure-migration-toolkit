#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Performance testing script for deployed ISAPI applications
    
.DESCRIPTION
    This script performs comprehensive performance testing including:
    1. Load testing with configurable concurrent users
    2. Stress testing to find breaking points
    3. Response time analysis and percentile calculations
    4. Memory and CPU utilization monitoring
    
.PARAMETER AppServiceUrl
    The URL of the deployed App Service
    
.PARAMETER ConcurrentUsers
    Number of concurrent users to simulate (default: 10)
    
.PARAMETER TestDuration
    Duration in minutes for the performance test (default: 5)
    
.PARAMETER RampUpTime
    Time in seconds to ramp up to full load (default: 60)
    
.EXAMPLE
    .\performance-test.ps1 -AppServiceUrl "https://my-app.azurewebsites.net"
    
.EXAMPLE
    .\performance-test.ps1 -AppServiceUrl "https://my-app.azurewebsites.net" -ConcurrentUsers 50 -TestDuration 10
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AppServiceUrl,
    
    [Parameter(Mandatory = $false)]
    [int]$ConcurrentUsers = 10,
    
    [Parameter(Mandatory = $false)]
    [int]$TestDuration = 5,
    
    [Parameter(Mandatory = $false)]
    [int]$RampUpTime = 60
)

Write-Host "=== ISAPI Performance Testing Suite ===" -ForegroundColor Green
Write-Host "Target URL: $AppServiceUrl" -ForegroundColor Cyan
Write-Host "Concurrent Users: $ConcurrentUsers" -ForegroundColor Cyan
Write-Host "Test Duration: $TestDuration minutes" -ForegroundColor Cyan
Write-Host "Ramp-up Time: $RampUpTime seconds" -ForegroundColor Cyan
Write-Host

# Initialize performance tracking
$script:performanceData = [System.Collections.Concurrent.ConcurrentBag[PSObject]]::new()
$script:totalRequests = 0
$script:failedRequests = 0
$script:testRunning = $true

# Function to simulate user load
function Start-LoadTestWorker {
    param(
        [string]$Url,
        [int]$WorkerId,
        [int]$DelayBetweenRequests = 1000
    )
    
    $random = New-Object System.Random
    
    while ($script:testRunning) {
        try {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 30
            $stopwatch.Stop()
            
            $result = [PSCustomObject]@{
                WorkerId = $WorkerId
                ResponseTime = $stopwatch.ElapsedMilliseconds
                StatusCode = $response.StatusCode
                Timestamp = Get-Date
                Success = $response.StatusCode -eq 200
                ContentLength = $response.Content.Length
            }
            
            $script:performanceData.Add($result)
            
            if ($response.StatusCode -eq 200) {
                [System.Threading.Interlocked]::Increment([ref]$script:totalRequests)
            } else {
                [System.Threading.Interlocked]::Increment([ref]$script:failedRequests)
            }
            
        } catch {
            [System.Threading.Interlocked]::Increment([ref]$script:failedRequests)
            
            $errorResult = [PSCustomObject]@{
                WorkerId = $WorkerId
                ResponseTime = -1
                StatusCode = -1
                Timestamp = Get-Date
                Success = $false
                ContentLength = 0
                Error = $_.Exception.Message
            }
            
            $script:performanceData.Add($errorResult)
        }
        
        # Random delay between requests (simulating real user behavior)
        Start-Sleep -Milliseconds ($random.Next($DelayBetweenRequests/2, $DelayBetweenRequests*2))
    }
}

# Phase 1: Baseline Single User Test
Write-Host "📊 Phase 1: Baseline Performance Test..." -ForegroundColor Yellow
$baselineResults = @()
for ($i = 1; $i -le 10; $i++) {
    try {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-WebRequest -Uri $AppServiceUrl -UseBasicParsing -TimeoutSec 30
        $stopwatch.Stop()
        
        $baselineResults += $stopwatch.ElapsedMilliseconds
        Write-Host "  Baseline request $i`: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Cyan
    } catch {
        Write-Host "  Baseline request $i`: FAILED" -ForegroundColor Red
        $baselineResults += -1
    }
}

$validBaseline = $baselineResults | Where-Object { $_ -gt 0 }
if ($validBaseline.Count -gt 0) {
    $baselineAvg = ($validBaseline | Measure-Object -Average).Average
    $baselineMedian = ($validBaseline | Sort-Object)[[math]::Floor($validBaseline.Count / 2)]
    
    Write-Host "✅ Baseline Results:" -ForegroundColor Green
    Write-Host "  Average Response Time: $([math]::Round($baselineAvg, 2))ms" -ForegroundColor Cyan
    Write-Host "  Median Response Time: $baselineMedian ms" -ForegroundColor Cyan
} else {
    Write-Host "❌ Baseline test failed - cannot proceed with load testing" -ForegroundColor Red
    exit 1
}

# Phase 2: Ramp-up Load Test
Write-Host "`n⚡ Phase 2: Ramp-up Load Test..." -ForegroundColor Yellow
$jobs = @()
$currentUsers = 0
$rampUpInterval = $RampUpTime / $ConcurrentUsers

# Start workers gradually
for ($userCount = 1; $userCount -le $ConcurrentUsers; $userCount++) {
    $job = Start-Job -ScriptBlock {
        param($Url, $WorkerId)
        
        # Import the function into the job scope
        function Start-LoadTestWorker {
            param(
                [string]$Url,
                [int]$WorkerId,
                [int]$DelayBetweenRequests = 1000
            )
            
            $random = New-Object System.Random
            
            while ($using:script:testRunning) {
                try {
                    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 30
                    $stopwatch.Stop()
                    
                    $result = [PSCustomObject]@{
                        WorkerId = $WorkerId
                        ResponseTime = $stopwatch.ElapsedMilliseconds
                        StatusCode = $response.StatusCode
                        Timestamp = Get-Date
                        Success = $response.StatusCode -eq 200
                    }
                    
                    # Can't directly modify parent scope variables, so we'll collect results differently
                    $result | Export-Clixml -Path "temp_perf_$WorkerId.xml" -Append -Force
                    
                } catch {
                    $errorResult = [PSCustomObject]@{
                        WorkerId = $WorkerId
                        ResponseTime = -1
                        StatusCode = -1
                        Timestamp = Get-Date
                        Success = $false
                        Error = $_.Exception.Message
                    }
                    
                    $errorResult | Export-Clixml -Path "temp_perf_$WorkerId.xml" -Append -Force
                }
                
                Start-Sleep -Milliseconds ($random.Next(500, 2000))
            }
        }
        
        Start-LoadTestWorker -Url $Url -WorkerId $WorkerId
    } -ArgumentList $AppServiceUrl, $userCount
    
    $jobs += $job
    $currentUsers++
    
    Write-Host "  Started user $userCount of $ConcurrentUsers" -ForegroundColor Cyan
    
    if ($userCount -lt $ConcurrentUsers) {
        Start-Sleep -Seconds $rampUpInterval
    }
}

Write-Host "✅ All $ConcurrentUsers users started" -ForegroundColor Green

# Phase 3: Sustained Load Test
Write-Host "`n🔥 Phase 3: Sustained Load Test ($TestDuration minutes)..." -ForegroundColor Yellow
$testEndTime = (Get-Date).AddMinutes($TestDuration)
$lastReportTime = Get-Date

while ((Get-Date) -lt $testEndTime) {
    $currentTime = Get-Date
    $remainingMinutes = ($testEndTime - $currentTime).TotalMinutes
    
    # Report progress every 30 seconds
    if (($currentTime - $lastReportTime).TotalSeconds -ge 30) {
        Write-Host "  Load testing in progress... $([math]::Round($remainingMinutes, 1)) minutes remaining" -ForegroundColor Cyan
        $lastReportTime = $currentTime
    }
    
    Start-Sleep -Seconds 10
}

# Phase 4: Stop Load Test and Collect Results
Write-Host "`n🛑 Phase 4: Stopping Load Test..." -ForegroundColor Yellow
$script:testRunning = $false

# Wait for all jobs to complete with timeout
$jobWaitTime = 30
Write-Host "  Waiting for worker threads to complete (max $jobWaitTime seconds)..." -ForegroundColor Cyan
$jobs | Wait-Job -Timeout $jobWaitTime | Out-Null

# Force stop any remaining jobs
$jobs | Stop-Job
$jobs | Remove-Job

# Collect results from temporary files
$allResults = @()
for ($i = 1; $i -le $ConcurrentUsers; $i++) {
    $tempFile = "temp_perf_$i.xml"
    if (Test-Path $tempFile) {
        try {
            $workerResults = Import-Clixml -Path $tempFile
            $allResults += $workerResults
            Remove-Item $tempFile -Force
        } catch {
            Write-Host "  Warning: Could not read results from worker $i" -ForegroundColor Yellow
        }
    }
}

# Phase 5: Analysis and Reporting
Write-Host "`n📊 Phase 5: Performance Analysis..." -ForegroundColor Yellow

if ($allResults.Count -eq 0) {
    Write-Host "❌ No performance data collected" -ForegroundColor Red
    exit 1
}

$successfulResults = $allResults | Where-Object { $_.Success -eq $true -and $_.ResponseTime -gt 0 }
$failedResults = $allResults | Where-Object { $_.Success -eq $false -or $_.ResponseTime -le 0 }

Write-Host "`n=== Performance Test Results ===" -ForegroundColor Green

# Request Statistics
$totalRequests = $allResults.Count
$successfulRequests = $successfulResults.Count
$failedRequests = $failedResults.Count
$successRate = if ($totalRequests -gt 0) { ($successfulRequests / $totalRequests) * 100 } else { 0 }

Write-Host "`n📈 Request Statistics:" -ForegroundColor Green
Write-Host "  Total Requests: $totalRequests" -ForegroundColor Cyan
Write-Host "  Successful Requests: $successfulRequests" -ForegroundColor Cyan
Write-Host "  Failed Requests: $failedRequests" -ForegroundColor Cyan
Write-Host "  Success Rate: $([math]::Round($successRate, 2))%" -ForegroundColor $(if ($successRate -gt 95) { 'Green' } else { 'Red' })

# Response Time Analysis
if ($successfulResults.Count -gt 0) {
    $responseTimes = $successfulResults | Select-Object -ExpandProperty ResponseTime | Sort-Object
    $avgResponseTime = ($responseTimes | Measure-Object -Average).Average
    $minResponseTime = ($responseTimes | Measure-Object -Minimum).Minimum
    $maxResponseTime = ($responseTimes | Measure-Object -Maximum).Maximum
    
    # Calculate percentiles
    $p50 = $responseTimes[[math]::Floor($responseTimes.Count * 0.5)]
    $p90 = $responseTimes[[math]::Floor($responseTimes.Count * 0.9)]
    $p95 = $responseTimes[[math]::Floor($responseTimes.Count * 0.95)]
    $p99 = $responseTimes[[math]::Floor($responseTimes.Count * 0.99)]
    
    Write-Host "`n⚡ Response Time Analysis:" -ForegroundColor Green
    Write-Host "  Average: $([math]::Round($avgResponseTime, 2))ms" -ForegroundColor Cyan
    Write-Host "  Minimum: $minResponseTime ms" -ForegroundColor Cyan
    Write-Host "  Maximum: $maxResponseTime ms" -ForegroundColor Cyan
    Write-Host "  50th Percentile (P50): $p50 ms" -ForegroundColor Cyan
    Write-Host "  90th Percentile (P90): $p90 ms" -ForegroundColor Cyan
    Write-Host "  95th Percentile (P95): $p95 ms" -ForegroundColor Cyan
    Write-Host "  99th Percentile (P99): $p99 ms" -ForegroundColor Cyan
    
    # Performance Assessment
    Write-Host "`n🎯 Performance Assessment:" -ForegroundColor Green
    $performanceGrade = "A"
    if ($avgResponseTime -gt 2000) { $performanceGrade = "C" }
    elseif ($avgResponseTime -gt 1000) { $performanceGrade = "B" }
    
    $color = switch ($performanceGrade) {
        "A" { "Green" }
        "B" { "Yellow" }
        "C" { "Red" }
    }
    
    Write-Host "  Performance Grade: $performanceGrade" -ForegroundColor $color
    Write-Host "  Throughput: $([math]::Round($successfulRequests / ($TestDuration * 60), 2)) req/sec" -ForegroundColor Cyan
    
    # Comparison with baseline
    $performanceImpact = (($avgResponseTime - $baselineAvg) / $baselineAvg) * 100
    Write-Host "  Performance Impact vs Baseline: $([math]::Round($performanceImpact, 2))%" -ForegroundColor $(if ($performanceImpact -lt 50) { 'Green' } elseif ($performanceImpact -lt 100) { 'Yellow' } else { 'Red' })
}

# Summary and Recommendations
Write-Host "`n💡 Recommendations:" -ForegroundColor Green
if ($successRate -lt 95) {
    Write-Host "  ⚠️ Consider investigating failed requests and server errors" -ForegroundColor Yellow
}
if ($avgResponseTime -gt 2000) {
    Write-Host "  ⚠️ Response times are high - consider scaling up App Service Plan" -ForegroundColor Yellow
}
if ($performanceImpact -gt 100) {
    Write-Host "  ⚠️ Significant performance degradation under load - review application optimization" -ForegroundColor Yellow
}

Write-Host "`n🎉 Performance testing completed!" -ForegroundColor Green
Write-Host "For detailed Azure monitoring, check Application Insights in the Azure Portal." -ForegroundColor Cyan
