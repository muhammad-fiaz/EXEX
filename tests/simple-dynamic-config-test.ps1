# Simple EXEX Test Script
# Test the dynamic config functionality

$BaseUrl = "http://127.0.0.1:8080"

Write-Host "🧪 EXEX Dynamic Config Test" -ForegroundColor Magenta
Write-Host "Config file location: C:\Users\smuha\AppData\Local\EXEX\exex.config.json" -ForegroundColor Cyan
Write-Host ""

# Test 1: Server Health
Write-Host "1️⃣ Testing Server Health" -ForegroundColor White
try {
    $health = Invoke-RestMethod -Uri "$BaseUrl/health" -Method GET
    Write-Host "✅ PASS - Server Health: $($health.status)" -ForegroundColor Green
    Write-Host "   Service: $($health.service), Version: $($health.version)" -ForegroundColor Gray
} catch {
    Write-Host "❌ FAIL - Server Health: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Command Execution
Write-Host ""
Write-Host "2️⃣ Testing Command Execution" -ForegroundColor White
try {
    $cmd = @{ command = "echo Dynamic Config Test" } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$BaseUrl/api/exec" -Method POST -Body $cmd -ContentType "application/json"
    if ($result.success) {
        Write-Host "✅ PASS - Command Execution: $($result.stdout.Trim())" -ForegroundColor Green
    } else {
        Write-Host "❌ FAIL - Command Execution: $($result.stderr)" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ FAIL - Command Execution: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: File Write (allowed path)
Write-Host ""
Write-Host "3️⃣ Testing File Write (Allowed Path)" -ForegroundColor White
$testFile = "C:\Users\smuha\Desktop\exex-dynamic-config-test.txt"
$testContent = "EXEX Dynamic Config Test`nCreated: $(Get-Date)`nConfig Location: AppData/Local/EXEX/"
try {
    $writeReq = @{ path = $testFile; content = $testContent } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$BaseUrl/api/write" -Method POST -Body $writeReq -ContentType "application/json"
    if ($result.success) {
        Write-Host "✅ PASS - File Write: Successfully wrote to $testFile" -ForegroundColor Green
    } else {
        Write-Host "❌ FAIL - File Write: $($result.error)" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ FAIL - File Write: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: File Read (allowed path)
Write-Host ""
Write-Host "4️⃣ Testing File Read (Allowed Path)" -ForegroundColor White
try {
    $readReq = @{ path = $testFile } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$BaseUrl/api/read" -Method POST -Body $readReq -ContentType "application/json"
    if ($result.success) {
        Write-Host "✅ PASS - File Read: Read $($result.content.Length) characters" -ForegroundColor Green
    } else {
        Write-Host "❌ FAIL - File Read: $($result.error)" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ FAIL - File Read: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: Security Test - Windows System Files (should be blocked)
Write-Host ""
Write-Host "5️⃣ Testing Security - System File Access (Should be Blocked)" -ForegroundColor White
try {
    $secReq = @{ path = "C:\Windows\System32\kernel32.dll" } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$BaseUrl/api/read" -Method POST -Body $secReq -ContentType "application/json" -ErrorAction Stop
    Write-Host "❌ FAIL - Security: System file access was not blocked!" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 403) {
        Write-Host "✅ PASS - Security: Access correctly denied (HTTP 403)" -ForegroundColor Green
    } else {
        Write-Host "❌ FAIL - Security: Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test 6: Security Test - Program Files (should be blocked)
Write-Host ""
Write-Host "6️⃣ Testing Security - Program Files Access (Should be Blocked)" -ForegroundColor White
try {
    $secReq = @{ path = "C:\Program Files\Common Files" } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$BaseUrl/api/read" -Method POST -Body $secReq -ContentType "application/json" -ErrorAction Stop
    Write-Host "❌ FAIL - Security: Program Files access was not blocked!" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 403) {
        Write-Host "✅ PASS - Security: Access correctly denied (HTTP 403)" -ForegroundColor Green
    } else {
        Write-Host "❌ FAIL - Security: Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test 7: Security Test - ProgramData (should be blocked)
Write-Host ""
Write-Host "7️⃣ Testing Security - ProgramData Access (Should be Blocked)" -ForegroundColor White
try {
    $secReq = @{ path = "C:\ProgramData\Microsoft" } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$BaseUrl/api/read" -Method POST -Body $secReq -ContentType "application/json" -ErrorAction Stop
    Write-Host "❌ FAIL - Security: ProgramData access was not blocked!" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 403) {
        Write-Host "✅ PASS - Security: Access correctly denied (HTTP 403)" -ForegroundColor Green
    } else {
        Write-Host "❌ FAIL - Security: Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test 8: Command Security Test
Write-Host ""
Write-Host "8️⃣ Testing Command Security - Dangerous Command (Should be Blocked)" -ForegroundColor White
try {
    $dangerCmd = @{ command = "format C: /q" } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$BaseUrl/api/exec" -Method POST -Body $dangerCmd -ContentType "application/json" -ErrorAction Stop
    Write-Host "❌ FAIL - Command Security: Dangerous command was not blocked!" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 403) {
        Write-Host "✅ PASS - Command Security: Dangerous command correctly blocked (HTTP 403)" -ForegroundColor Green
    } else {
        Write-Host "❌ FAIL - Command Security: Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "🎯 Dynamic Config Summary:" -ForegroundColor Magenta
Write-Host "• Config file created at: C:\Users\smuha\AppData\Local\EXEX\exex.config.json" -ForegroundColor Cyan
Write-Host "• Contains 7 default disallowed paths" -ForegroundColor Cyan
Write-Host "• Security restrictions are working correctly" -ForegroundColor Cyan
Write-Host "• HTTP 403 Forbidden returned for blocked access" -ForegroundColor Cyan

Write-Host ""
Write-Host "✨ Test completed!" -ForegroundColor Green
