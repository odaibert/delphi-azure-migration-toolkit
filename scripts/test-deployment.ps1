param(
    [Parameter(Mandatory=$true)]
    [string]$AppServiceUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "",
    
    [Parameter(Mandatory=$false)]
    [string]$AppServiceName = "",
    
    [Parameter(Mandatory=$false)]
    [int]$TimeoutSeconds = 30,
    
    [Parameter(Mandatory=$false)]
    [switch]$Detailed
)

# Script to test ISAPI filter deployment on Azure App Service
Write-Host "🧪 Testing ISAPI Filter Deployment" -ForegroundColor Green

# Ensure URL has proper format
if (-not $AppServiceUrl.StartsWith("http")) {
    $AppServiceUrl = "https://$AppServiceUrl"
}

Write-Host "🎯 Target URL: $AppServiceUrl" -ForegroundColor Cyan

# Test functions
function Test-WebEndpoint {
    param($Url, $Description, $ExpectedStatus = 200)
    
    Write-Host "🔍 Testing: $Description" -ForegroundColor Yellow
    Write-Host "   URL: $Url" -ForegroundColor Gray
    
    try {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-WebRequest -Uri $Url -Method GET -TimeoutSec $TimeoutSeconds -UseBasicParsing
        $stopwatch.Stop()
        
        $responseTime = $stopwatch.ElapsedMilliseconds
        
        if ($response.StatusCode -eq $ExpectedStatus) {
            Write-Host "   ✅ SUCCESS - Status: $($response.StatusCode), Time: ${responseTime}ms" -ForegroundColor Green
            
            if ($Detailed) {
                Write-Host "   📊 Response Details:" -ForegroundColor Gray
                Write-Host "      Content-Type: $($response.Headers['Content-Type'])" -ForegroundColor Gray
                Write-Host "      Content-Length: $($response.Headers['Content-Length'])" -ForegroundColor Gray
                Write-Host "      Server: $($response.Headers['Server'])" -ForegroundColor Gray
                
                if ($response.Content.Length -lt 500) {
                    Write-Host "      Content Preview: $($response.Content.Substring(0, [Math]::Min(200, $response.Content.Length)))..." -ForegroundColor Gray
                }
            }
            
            return @{ Success = $true; StatusCode = $response.StatusCode; ResponseTime = $responseTime; Response = $response }
        } else {
            Write-Host "   ❌ FAILED - Expected: $ExpectedStatus, Got: $($response.StatusCode)" -ForegroundColor Red
            return @{ Success = $false; StatusCode = $response.StatusCode; ResponseTime = $responseTime; Response = $response }
        }
        
    } catch {
        Write-Host "   ❌ ERROR - $($_.Exception.Message)" -ForegroundColor Red
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Test-ISAPIEndpoint {
    param($BaseUrl, $DllName)
    
    $dllUrl = "$BaseUrl/$DllName"
    Write-Host "🔍 Testing ISAPI DLL directly" -ForegroundColor Yellow
    Write-Host "   URL: $dllUrl" -ForegroundColor Gray
    
    try {
        $response = Invoke-WebRequest -Uri $dllUrl -Method GET -TimeoutSec $TimeoutSeconds -UseBasicParsing
        
        Write-Host "   ✅ ISAPI DLL responded - Status: $($response.StatusCode)" -ForegroundColor Green
        
        if ($Detailed) {
            Write-Host "   📊 ISAPI Response Details:" -ForegroundColor Gray
            Write-Host "      Content-Type: $($response.Headers['Content-Type'])" -ForegroundColor Gray
            Write-Host "      Response Length: $($response.Content.Length) bytes" -ForegroundColor Gray
            
            if ($response.Content.Length -lt 500) {
                Write-Host "      Content: $($response.Content)" -ForegroundColor Gray
            }
        }
        
        return @{ Success = $true; StatusCode = $response.StatusCode; Response = $response }
        
    } catch {
        $errorMessage = $_.Exception.Message
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode } else { "Unknown" }
        
        if ($statusCode -eq 404) {
            Write-Host "   ⚠️ ISAPI DLL not found (404) - Check DLL deployment and web.config" -ForegroundColor Yellow
        } elseif ($statusCode -eq 500) {
            Write-Host "   ❌ ISAPI DLL error (500) - Check DLL compatibility and dependencies" -ForegroundColor Red
        } else {
            Write-Host "   ❌ ISAPI DLL test failed - $errorMessage" -ForegroundColor Red
        }
        
        return @{ Success = $false; Error = $errorMessage; StatusCode = $statusCode }
    }
}

# Start testing
$testResults = @()
$startTime = Get-Date

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray

# Test 1: Basic connectivity
$test1 = Test-WebEndpoint -Url $AppServiceUrl -Description "Basic App Service connectivity"
$testResults += @{ Test = "Basic Connectivity"; Result = $test1 }

# Test 2: Default document
$test2 = Test-WebEndpoint -Url "$AppServiceUrl/default.html" -Description "Default document access"
$testResults += @{ Test = "Default Document"; Result = $test2 }

# Test 3: Web.config accessibility (should return 404 or 403 for security)
$test3 = Test-WebEndpoint -Url "$AppServiceUrl/web.config" -Description "Web.config security" -ExpectedStatus 404
$testResults += @{ Test = "Web.config Security"; Result = $test3 }

# Test 4: Try to detect ISAPI DLL name from web.config (if accessible)
$isapiDllName = "YourISAPIFilter.dll"  # Default name, will try to detect actual name

if ($ResourceGroupName -and $AppServiceName) {
    Write-Host "🔍 Attempting to retrieve web.config from App Service..." -ForegroundColor Yellow
    
    try {
        # Try to get deployment info
        $tempDir = Join-Path $env:TEMP "isapi-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        # Download site content (requires appropriate permissions)
        $zipPath = Join-Path $tempDir "site-content.zip"
        az webapp deployment source download --name $AppServiceName --resource-group $ResourceGroupName --file-path $zipPath --output none 2>$null
        
        if (Test-Path $zipPath) {
            # Extract and check web.config
            Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
            $webConfigPath = Join-Path $tempDir "web.config"
            
            if (Test-Path $webConfigPath) {
                $webConfigContent = Get-Content $webConfigPath -Raw
                if ($webConfigContent -match 'path="bin\\([^"]+\.dll)"') {
                    $isapiDllName = $matches[1]
                    Write-Host "   ✅ Detected ISAPI DLL: $isapiDllName" -ForegroundColor Green
                }
            }
        }
        
        # Cleanup
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
    } catch {
        Write-Host "   ⚠️ Could not retrieve deployment info: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Test 5: ISAPI DLL direct access
$test5 = Test-ISAPIEndpoint -BaseUrl $AppServiceUrl -DllName $isapiDllName
$testResults += @{ Test = "ISAPI DLL Access"; Result = $test5 }

# Test 6: Custom ISAPI extension (if configured)
$test6 = Test-WebEndpoint -Url "$AppServiceUrl/test.dapi" -Description "Custom ISAPI extension" -ExpectedStatus 200
$testResults += @{ Test = "Custom ISAPI Extension"; Result = $test6 }

# Test 7: Performance test (multiple requests)
Write-Host "🚀 Running performance test (10 requests)..." -ForegroundColor Yellow
$performanceResults = @()

for ($i = 1; $i -le 10; $i++) {
    try {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-WebRequest -Uri $AppServiceUrl -Method GET -TimeoutSec $TimeoutSeconds -UseBasicParsing
        $stopwatch.Stop()
        
        $performanceResults += $stopwatch.ElapsedMilliseconds
        Write-Progress -Activity "Performance Test" -Status "Request $i/10" -PercentComplete ($i * 10)
    } catch {
        Write-Host "   ⚠️ Request $i failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if ($performanceResults.Count -gt 0) {
    $avgResponseTime = ($performanceResults | Measure-Object -Average).Average
    $minResponseTime = ($performanceResults | Measure-Object -Minimum).Minimum
    $maxResponseTime = ($performanceResults | Measure-Object -Maximum).Maximum
    
    Write-Host "   📊 Performance Results:" -ForegroundColor Green
    Write-Host "      Average: $([math]::Round($avgResponseTime, 1))ms" -ForegroundColor White
    Write-Host "      Min: ${minResponseTime}ms, Max: ${maxResponseTime}ms" -ForegroundColor White
    Write-Host "      Successful requests: $($performanceResults.Count)/10" -ForegroundColor White
    
    $testResults += @{ Test = "Performance"; Result = @{ Success = $true; AverageTime = $avgResponseTime } }
} else {
    Write-Host "   ❌ All performance test requests failed" -ForegroundColor Red
    $testResults += @{ Test = "Performance"; Result = @{ Success = $false } }
}

# Test 8: Azure-specific headers and features
Write-Host "🔍 Checking Azure-specific features..." -ForegroundColor Yellow

try {
    $response = Invoke-WebRequest -Uri $AppServiceUrl -Method GET -TimeoutSec $TimeoutSeconds -UseBasicParsing
    
    $azureHeaders = @()
    if ($response.Headers['X-Powered-By']) { $azureHeaders += "X-Powered-By: $($response.Headers['X-Powered-By'])" }
    if ($response.Headers['X-Azure-Ref']) { $azureHeaders += "X-Azure-Ref: $($response.Headers['X-Azure-Ref'])" }
    if ($response.Headers['X-Cache']) { $azureHeaders += "X-Cache: $($response.Headers['X-Cache'])" }
    
    if ($azureHeaders.Count -gt 0) {
        Write-Host "   ✅ Azure headers detected:" -ForegroundColor Green
        foreach ($header in $azureHeaders) {
            Write-Host "      $header" -ForegroundColor Gray
        }
    } else {
        Write-Host "   ℹ️ No Azure-specific headers found" -ForegroundColor Cyan
    }
    
} catch {
    Write-Host "   ⚠️ Could not check Azure headers: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Generate test report
$endTime = Get-Date
$totalDuration = $endTime - $startTime

Write-Host "" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "📋 Test Report Summary" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray

$passedTests = 0
$totalTests = $testResults.Count

foreach ($test in $testResults) {
    $status = if ($test.Result.Success) { "✅ PASS" } else { "❌ FAIL" }
    $passedTests += if ($test.Result.Success) { 1 } else { 0 }
    
    Write-Host "$status $($test.Test)" -ForegroundColor $(if ($test.Result.Success) { "Green" } else { "Red" })
}

Write-Host "" -ForegroundColor White
Write-Host "📊 Results: $passedTests/$totalTests tests passed" -ForegroundColor Cyan
Write-Host "⏱️ Total test duration: $([math]::Round($totalDuration.TotalSeconds, 1)) seconds" -ForegroundColor Cyan

# Recommendations
Write-Host "" -ForegroundColor White
Write-Host "💡 Recommendations:" -ForegroundColor Yellow

if ($testResults | Where-Object { $_.Test -eq "ISAPI DLL Access" -and -not $_.Result.Success }) {
    Write-Host "   • Check if ISAPI DLL is properly deployed to the bin folder" -ForegroundColor White
    Write-Host "   • Verify web.config ISAPI filter configuration" -ForegroundColor White
    Write-Host "   • Ensure DLL is compiled for x64 architecture" -ForegroundColor White
    Write-Host "   • Check App Service logs for detailed error information" -ForegroundColor White
}

if ($testResults | Where-Object { $_.Test -eq "Performance" -and $_.Result.AverageTime -gt 5000 }) {
    Write-Host "   • Consider upgrading App Service Plan for better performance" -ForegroundColor White
    Write-Host "   • Review ISAPI filter code for optimization opportunities" -ForegroundColor White
}

if ($passedTests -eq $totalTests) {
    Write-Host "" -ForegroundColor White
    Write-Host "🎉 All tests passed! Your ISAPI filter appears to be working correctly." -ForegroundColor Green
} else {
    Write-Host "" -ForegroundColor White
    Write-Host "🔧 Some tests failed. Please review the recommendations above." -ForegroundColor Yellow
}

# Show useful commands
Write-Host "" -ForegroundColor White
Write-Host "🛠️ Useful Commands:" -ForegroundColor Cyan
Write-Host "   View App Service logs:" -ForegroundColor White
if ($AppServiceName -and $ResourceGroupName) {
    Write-Host "   az webapp log tail --name $AppServiceName --resource-group $ResourceGroupName" -ForegroundColor Gray
    Write-Host "" -ForegroundColor White
    Write-Host "   Download logs:" -ForegroundColor White
    Write-Host "   az webapp log download --name $AppServiceName --resource-group $ResourceGroupName" -ForegroundColor Gray
} else {
    Write-Host "   az webapp log tail --name <app-name> --resource-group <rg-name>" -ForegroundColor Gray
}

Write-Host "" -ForegroundColor White
Write-Host "✅ Testing completed!" -ForegroundColor Green
