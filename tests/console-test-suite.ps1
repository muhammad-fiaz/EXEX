# EXEX Comprehensive Test Suite
# PowerShell script to test all EXEX functionality with detailed pass/fail reporting

$BaseUrl = "http://127.0.0.1:8080"
$TestResults = @()
$PassedTests = 0
$FailedTests = 0
$TotalTests = 0

function Write-TestHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor DarkGray
    Write-Host " $Title " -ForegroundColor Magenta
    Write-Host "=" * 60 -ForegroundColor DarkGray
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Details = "",
        [double]$Duration = 0
    )
    
    $script:TotalTests++
    
    if ($Passed) { 
        $script:PassedTests++
        $status = "✅ PASS" 
        $color = "Green"
    } else { 
        $script:FailedTests++
        $status = "❌ FAIL"
        $color = "Red"
    }
    
    Write-Host ""
    Write-Host "[$status] $TestName" -ForegroundColor $color
    if ($Duration -gt 0) {
        Write-Host "Duration: ${Duration}ms" -ForegroundColor Cyan
    }
    if ($Details) {
        Write-Host "Details: $Details" -ForegroundColor Gray
    }
    
    $script:TestResults += [PSCustomObject]@{
        Name = $TestName
        Passed = $Passed
        Details = $Details
        Duration = $Duration
        Timestamp = Get-Date
    }
}

function Invoke-SimpleTest {
    param(
        [string]$TestName,
        [string]$Endpoint,
        [hashtable]$Body = $null,
        [string]$Method = "GET",
        [scriptblock]$TestLogic = $null
    )
    
    $startTime = Get-Date
    
    try {
        $uri = "$BaseUrl$Endpoint"
        $headers = @{ "Content-Type" = "application/json" }
        
        if ($Body) {
            $jsonBody = $Body | ConvertTo-Json -Depth 3
            $response = Invoke-RestMethod -Uri $uri -Method $Method -Body $jsonBody -Headers $headers -ErrorAction Stop
        } else {
            $response = Invoke-RestMethod -Uri $uri -Method $Method -Headers $headers -ErrorAction Stop
        }
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        
        # Apply custom test logic if provided
        if ($TestLogic) {
            $testResult = & $TestLogic $response
            Write-TestResult -TestName $TestName -Passed $testResult.Passed -Details $testResult.Details -Duration $duration
        } else {
            Write-TestResult -TestName $TestName -Passed $true -Details "Request successful" -Duration $duration
        }
        
        return $response
    }
    catch {
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        Write-TestResult -TestName $TestName -Passed $false -Details "Error: $($_.Exception.Message)" -Duration $duration
        return $null
    }
}

function Test-ServerConnectivity {
    Write-TestHeader "SERVER CONNECTIVITY TESTS"
    
    # Test 1: Basic health check
    Invoke-SimpleTest -TestName "Server Health Check" -Endpoint "/health" -TestLogic {
        param($response)
        $passed = $response.status -eq "healthy"
        $details = "Status: $($response.status), Service: $($response.service), Version: $($response.version)"
        return @{ Passed = $passed; Details = $details }
    }
}

function Test-CommandExecution {
    Write-TestHeader "COMMAND EXECUTION TESTS"
    
    # Test 1: Simple echo command
    Invoke-SimpleTest -TestName "Basic Echo Command" -Endpoint "/api/exec" -Method "POST" -Body @{
        command = "echo Hello EXEX!"
    } -TestLogic {
        param($response)
        $passed = $response.success -and $response.stdout.Contains("Hello EXEX!")
        $details = "Output: $($response.stdout -replace "`n", " ")"
        return @{ Passed = $passed; Details = $details }
    }
    
    # Test 2: Directory listing
    Invoke-SimpleTest -TestName "Directory Listing (dir)" -Endpoint "/api/exec" -Method "POST" -Body @{
        command = "dir"
        cwd = $env:USERPROFILE
    } -TestLogic {
        param($response)
        $passed = $response.success -and $response.stdout.Length -gt 0
        $details = "Listed $(($response.stdout -split "`n").Count) lines"
        return @{ Passed = $passed; Details = $details }
    }
    
    # Test 3: PowerShell command
    Invoke-SimpleTest -TestName "PowerShell Get-Date" -Endpoint "/api/exec" -Method "POST" -Body @{
        command = "powershell -Command Get-Date"
    } -TestLogic {
        param($response)
        $passed = $response.success -and $response.stdout.Contains("2025")
        $details = "Date output received"
        return @{ Passed = $passed; Details = $details }
    }
    
    # Test 4: Command with working directory
    Invoke-SimpleTest -TestName "Command with Working Directory" -Endpoint "/api/exec" -Method "POST" -Body @{
        command = "echo %CD%"
        cwd = "C:\Windows"
    } -TestLogic {
        param($response)
        $passed = $response.success -and $response.stdout.Contains("Windows")
        $details = "Working directory: $($response.stdout -replace "`n", " ")"
        return @{ Passed = $passed; Details = $details }
    }
    
    # Test 5: Invalid command (should fail gracefully)
    Invoke-SimpleTest -TestName "Invalid Command Handling" -Endpoint "/api/exec" -Method "POST" -Body @{
        command = "nonexistentcommand12345xyz"
    } -TestLogic {
        param($response)
        $passed = -not $response.success -or $response.stderr.Length -gt 0
        $details = "Error handled gracefully"
        return @{ Passed = $passed; Details = $details }
    }
}

function Test-FileOperations {
    Write-TestHeader "FILE OPERATION TESTS"
    
    $testDir = Join-Path $env:USERPROFILE "Desktop\EXEX-Tests"
    $testFile = Join-Path $testDir "test-file.txt"
    $testContent = @"
EXEX Test File
Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Test ID: $(Get-Random)
Content with multiple lines
"@
    
    # Ensure test directory exists
    if (-not (Test-Path $testDir)) {
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
    }
    
    # Test 1: Write file
    Invoke-SimpleTest -TestName "File Write Operation" -Endpoint "/api/write" -Method "POST" -Body @{
        path = $testFile
        content = $testContent
    } -TestLogic {
        param($response)
        $passed = $response.success
        $details = "File written successfully"
        return @{ Passed = $passed; Details = $details }
    }
    
    # Test 2: Read file back
    Invoke-SimpleTest -TestName "File Read Operation" -Endpoint "/api/read" -Method "POST" -Body @{
        path = $testFile
    } -TestLogic {
        param($response)
        $passed = $response.success -and $response.content.Contains("EXEX Test File")
        $details = "Read $(($response.content).Length) characters"
        return @{ Passed = $passed; Details = $details }
    }
    
    # Test 3: Read non-existent file
    $nonExistentFile = Join-Path $testDir "non-existent-file.txt"
    Invoke-SimpleTest -TestName "Non-existent File Handling" -Endpoint "/api/read" -Method "POST" -Body @{
        path = $nonExistentFile
    } -TestLogic {
        param($response)
        $passed = -not $response.success
        $details = "Correctly failed to read non-existent file"
        return @{ Passed = $passed; Details = $details }
    }
}

function Test-SecurityFeatures {
    Write-TestHeader "SECURITY TESTS"
    
    # Test 1: Restricted path access (Windows system files)
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/read" -Method POST -Body (@{path = "C:\Windows\System32\kernel32.dll"} | ConvertTo-Json) -ContentType "application/json" -ErrorAction Stop
        Write-TestResult -TestName "System File Access Denial" -Passed $false -Details "Should have been blocked with 403 status, but request succeeded"
    }
    catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { 0 }
        $passed = $statusCode -eq 403
        $details = if ($passed) { 
            "✅ Correctly blocked with HTTP 403 Forbidden" 
        } else { 
            "❌ Wrong status code: $statusCode (expected 403)" 
        }
        Write-TestResult -TestName "System File Access Denial" -Passed $passed -Details $details
    }
    
    # Test 2: Program Files access denial  
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/read" -Method POST -Body (@{path = "C:\Program Files"} | ConvertTo-Json) -ContentType "application/json" -ErrorAction Stop
        Write-TestResult -TestName "Program Files Access Denial" -Passed $false -Details "Should have been blocked with 403 status, but request succeeded"
    }
    catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { 0 }
        $passed = $statusCode -eq 403
        $details = if ($passed) { 
            "✅ Correctly blocked with HTTP 403 Forbidden" 
        } else { 
            "❌ Wrong status code: $statusCode (expected 403)" 
        }
        Write-TestResult -TestName "Program Files Access Denial" -Passed $passed -Details $details
    }
    
    # Test 3: Windows directory access denial
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/read" -Method POST -Body (@{path = "C:\Windows\notepad.exe"} | ConvertTo-Json) -ContentType "application/json" -ErrorAction Stop
        Write-TestResult -TestName "Windows Directory Access Denial" -Passed $false -Details "Should have been blocked with 403 status, but request succeeded"
    }
    catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { 0 }
        $passed = $statusCode -eq 403
        $details = if ($passed) { 
            "✅ Correctly blocked with HTTP 403 Forbidden" 
        } else { 
            "❌ Wrong status code: $statusCode (expected 403)" 
        }
        Write-TestResult -TestName "Windows Directory Access Denial" -Passed $passed -Details $details
    }
    
    # Test 4: Dangerous command execution prevention
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/exec" -Method POST -Body (@{command = "format C: /q"} | ConvertTo-Json) -ContentType "application/json" -ErrorAction Stop
        Write-TestResult -TestName "Dangerous Command Prevention" -Passed $false -Details "Should have been blocked with 403 status, but request succeeded"
    }
    catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { 0 }
        $passed = $statusCode -eq 403
        $details = if ($passed) { 
            "✅ Correctly blocked dangerous command with HTTP 403 Forbidden" 
        } else { 
            "❌ Wrong status code: $statusCode (expected 403)" 
        }
        Write-TestResult -TestName "Dangerous Command Prevention" -Passed $passed -Details $details
    }
    
    # Test 5: Working directory in restricted path
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/exec" -Method POST -Body (@{command = "dir"; cwd = "C:\Windows\System32"} | ConvertTo-Json) -ContentType "application/json" -ErrorAction Stop
        Write-TestResult -TestName "Restricted Working Directory" -Passed $false -Details "Should have been blocked with 403 status, but request succeeded"
    }
    catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { 0 }
        $passed = $statusCode -eq 403
        $details = if ($passed) { 
            "✅ Correctly blocked restricted working directory with HTTP 403 Forbidden" 
        } else { 
            "❌ Wrong status code: $statusCode (expected 403)" 
        }
        Write-TestResult -TestName "Restricted Working Directory" -Passed $passed -Details $details
    }
    
    # Test 6: Allowed path should work (positive test)
    $allowedPath = Join-Path $env:USERPROFILE "Desktop\EXEX-Tests\security-test.txt"
    "Security test content" | Out-File $allowedPath -Encoding UTF8
    
    Invoke-SimpleTest -TestName "Allowed Path Access" -Endpoint "/api/read" -Method "POST" -Body @{
        path = $allowedPath
    } -TestLogic {
        param($response)
        $passed = $response.success -and $response.content.Contains("Security test content")
        $details = if ($passed) { 
            "✅ Allowed path correctly accessible" 
        } else { 
            "❌ Allowed path incorrectly blocked" 
        }
        return @{ Passed = $passed; Details = $details }
    }
}

function Test-HttpStatusCodes {
    Write-TestHeader "HTTP STATUS CODE TESTS"
    
    Write-Host "Testing various HTTP status codes returned by EXEX:" -ForegroundColor Cyan
    Write-Host "  200 OK - Successful requests" -ForegroundColor Green
    Write-Host "  400 Bad Request - Invalid JSON or missing fields" -ForegroundColor Yellow  
    Write-Host "  403 Forbidden - Security restrictions" -ForegroundColor Red
    Write-Host "  404 Not Found - Invalid endpoints" -ForegroundColor Red
    Write-Host "  405 Method Not Allowed - Wrong HTTP method" -ForegroundColor Red
    Write-Host ""
    
    # Test successful request (200)
    Invoke-SimpleTest -TestName "HTTP 200 OK Response" -Endpoint "/health" -TestLogic {
        param($response)
        $passed = $response.status -eq "healthy"
        $details = "✅ HTTP 200 - Health check successful"
        return @{ Passed = $passed; Details = $details }
    }
    
    # Test forbidden access (403) 
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/read" -Method POST -Body (@{path = "C:\Windows\win.ini"} | ConvertTo-Json) -ContentType "application/json" -ErrorAction Stop
        Write-TestResult -TestName "HTTP 403 Forbidden Response" -Passed $false -Details "Should have returned 403"
    }
    catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { 0 }
        $passed = $statusCode -eq 403
        $details = if ($passed) { "✅ HTTP 403 - Access correctly forbidden" } else { "Wrong status: $statusCode" }
        Write-TestResult -TestName "HTTP 403 Forbidden Response" -Passed $passed -Details $details
    }
}
    Write-TestHeader "ERROR HANDLING TESTS"
    
    # Test 1: Invalid JSON request
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/exec" -Method POST -Body "invalid json" -ContentType "application/json" -ErrorAction Stop
        Write-TestResult -TestName "Invalid JSON Handling" -Passed $false -Details "Should have rejected invalid JSON"
    }
    catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { 0 }
        $passed = $statusCode -eq 400
        $details = if ($passed) { 
            "✅ Correctly rejected invalid JSON with HTTP 400 Bad Request" 
        } else { 
            "Status code: $statusCode (expected 400)" 
        }
        Write-TestResult -TestName "Invalid JSON Handling" -Passed $passed -Details $details
    }
    
    # Test 2: Missing required fields
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/exec" -Method POST -Body (@{cwd = "C:\"} | ConvertTo-Json) -ContentType "application/json" -ErrorAction Stop
        Write-TestResult -TestName "Missing Command Field" -Passed $false -Details "Should have rejected missing command"
    }
    catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { 0 }
        $passed = $statusCode -eq 400
        $details = if ($passed) { 
            "✅ Correctly rejected missing field with HTTP 400 Bad Request" 
        } else { 
            "Status code: $statusCode (expected 400)" 
        }
        Write-TestResult -TestName "Missing Command Field" -Passed $passed -Details $details
    }
    
    # Test 3: Invalid endpoint
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/invalid" -Method GET -ErrorAction Stop
        Write-TestResult -TestName "Invalid Endpoint Handling" -Passed $false -Details "Should return 404"
    }
    catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { 0 }
        $passed = $statusCode -eq 404
        $details = if ($passed) { 
            "✅ Correctly returned HTTP 404 Not Found" 
        } else { 
            "Status code: $statusCode (expected 404)" 
        }
        Write-TestResult -TestName "Invalid Endpoint Handling" -Passed $passed -Details $details
    }
    
    # Test 4: Method not allowed
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/exec" -Method DELETE -ErrorAction Stop
        Write-TestResult -TestName "Method Not Allowed Handling" -Passed $false -Details "Should return 405"
    }
    catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { 0 }
        $passed = $statusCode -eq 405
        $details = if ($passed) { 
            "✅ Correctly returned HTTP 405 Method Not Allowed" 
        } else { 
            "Status code: $statusCode (expected 405)" 
        }
        Write-TestResult -TestName "Method Not Allowed Handling" -Passed $passed -Details $details
    }
}

function Show-TestSummary {
    Write-TestHeader "TEST SUMMARY"
    
    Write-Host ""
    Write-Host "📊 Test Results Summary:" -ForegroundColor Magenta
    Write-Host "  Total Tests: $TotalTests" -ForegroundColor Cyan
    Write-Host "  ✅ Passed: $PassedTests" -ForegroundColor Green
    Write-Host "  ❌ Failed: $FailedTests" -ForegroundColor Red
    
    $successRate = if ($TotalTests -gt 0) { [math]::Round(($PassedTests / $TotalTests) * 100, 2) } else { 0 }
    $rateColor = if ($successRate -ge 80) { "Green" } else { "Yellow" }
    Write-Host "  📈 Success Rate: $successRate%" -ForegroundColor $rateColor
    
    if ($FailedTests -gt 0) {
        Write-Host ""
        Write-Host "❌ Failed Tests:" -ForegroundColor Red
        $TestResults | Where-Object { -not $_.Passed } | ForEach-Object {
            Write-Host "  - $($_.Name): $($_.Details)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "⏱️  Test Execution Time:" -ForegroundColor Cyan
    $totalDuration = ($TestResults | Measure-Object -Property Duration -Sum).Sum
    Write-Host "  Total Duration: ${totalDuration}ms" -ForegroundColor Cyan
    
    Write-Host ""
    if ($FailedTests -eq 0) {
        Write-Host "🎉 All tests passed! EXEX is working correctly." -ForegroundColor Green
    } else {
        Write-Host "⚠️  Some tests failed. Please review the errors above." -ForegroundColor Yellow
    }
}

# Main execution
Clear-Host
Write-Host "🧪 EXEX Comprehensive Test Suite" -ForegroundColor Magenta
Write-Host "Starting at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "Target: $BaseUrl" -ForegroundColor Cyan

# Check if server is running
try {
    $healthCheck = Invoke-RestMethod -Uri "$BaseUrl/health" -Method GET -ErrorAction Stop
    Write-Host "✅ Server is running (Version: $($healthCheck.version))" -ForegroundColor Green
}
catch {
    Write-Host "❌ Cannot connect to EXEX server at $BaseUrl" -ForegroundColor Red
    Write-Host "Please ensure the server is running with: cargo run" -ForegroundColor Yellow
    exit 1
}

# Run all test suites
Test-ServerConnectivity
Test-CommandExecution
Test-FileOperations
Test-SecurityFeatures
Test-HttpStatusCodes
Test-ErrorHandling

# Show final summary
Show-TestSummary

Write-Host ""
Write-Host "✨ Test suite completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
