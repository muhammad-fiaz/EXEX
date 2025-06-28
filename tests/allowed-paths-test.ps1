# EXEX Allowed Paths Test Suite
# Test the new allowed_paths functionality that overrides disallowed_paths

$BaseUrl = "http://127.0.0.1:8080"

Write-Host "🧪 EXEX Allowed Paths Priority Test" -ForegroundColor Magenta
Write-Host "Testing the priority system: Allowed > Disallowed > Default Allow" -ForegroundColor Cyan
Write-Host ""

# Test 1: Verify server is running
Write-Host "1️⃣ Server Health Check" -ForegroundColor White
try {
    $health = Invoke-RestMethod -Uri "$BaseUrl/health" -Method GET
    Write-Host "✅ PASS - Server: $($health.status) v$($health.version)" -ForegroundColor Green
} catch {
    Write-Host "❌ FAIL - Server not responding: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 2: Test normal disallowed path (should be blocked)
Write-Host ""
Write-Host "2️⃣ Testing Disallowed Path (Should be Blocked)" -ForegroundColor White
Write-Host "   Path: C:\Windows\System32\kernel32.dll" -ForegroundColor Gray
try {
    $req = @{ path = "C:\Windows\System32\kernel32.dll" } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$BaseUrl/api/read" -Method POST -Body $req -ContentType "application/json" -ErrorAction Stop
    Write-Host "❌ FAIL - Disallowed path was not blocked!" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 403) {
        Write-Host "✅ PASS - Disallowed path correctly blocked (HTTP 403)" -ForegroundColor Green
    } else {
        Write-Host "❌ FAIL - Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test 3: Test allowed path within disallowed directory (should be allowed)
Write-Host ""
Write-Host "3️⃣ Testing Allowed Path Exception (Should Override Disallowed)" -ForegroundColor White
Write-Host "   Disallowed: C:\Windows\\" -ForegroundColor Gray
Write-Host "   Allowed Exception: C:\Windows\Temp\\" -ForegroundColor Gray
Write-Host "   Testing: C:\Windows\Temp\" -ForegroundColor Gray

# First, let's create a test file in Windows Temp to test with
$tempTestFile = "C:\Windows\Temp\exex-allowed-test.txt"
$tempContent = "EXEX Allowed Path Test`nThis file is in C:\Windows\Temp\ which should be allowed`nCreated: $(Get-Date)"

# Write the test file using the API
try {
    $writeReq = @{ path = $tempTestFile; content = $tempContent } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$BaseUrl/api/write" -Method POST -Body $writeReq -ContentType "application/json"
    if ($result.success) {
        Write-Host "✅ PASS - Write to allowed exception path successful" -ForegroundColor Green
        
        # Now try to read it back
        $readReq = @{ path = $tempTestFile } | ConvertTo-Json
        $readResult = Invoke-RestMethod -Uri "$BaseUrl/api/read" -Method POST -Body $readReq -ContentType "application/json"
        if ($readResult.success) {
            Write-Host "✅ PASS - Read from allowed exception path successful" -ForegroundColor Green
            Write-Host "   Content length: $($readResult.content.Length) characters" -ForegroundColor Gray
        } else {
            Write-Host "❌ FAIL - Read from allowed path failed: $($readResult.error)" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ FAIL - Write to allowed path failed: $($result.error)" -ForegroundColor Red
    }
} catch {
    if ($_.Exception.Response.StatusCode -eq 403) {
        Write-Host "❌ FAIL - Allowed path was incorrectly blocked (HTTP 403)" -ForegroundColor Red
        Write-Host "   This suggests the allowed_paths override is not working" -ForegroundColor Red
    } else {
        Write-Host "❌ FAIL - Error testing allowed path: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test 4: Test Program Files allowed exception
Write-Host ""
Write-Host "4️⃣ Testing Program Files Allowed Exception" -ForegroundColor White
Write-Host "   Disallowed: C:\Program Files\\" -ForegroundColor Gray
Write-Host "   Allowed Exception: C:\Program Files\Common Files\Microsoft Shared\\" -ForegroundColor Gray
try {
    $req = @{ path = "C:\Program Files\Common Files\Microsoft Shared\" } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$BaseUrl/api/read" -Method POST -Body $req -ContentType "application/json"
    if ($result.success) {
        Write-Host "✅ PASS - Program Files allowed exception working" -ForegroundColor Green
    } else {
        Write-Host "⚠️ WARNING - Allowed path accessible but returned: $($result.error)" -ForegroundColor Yellow
        Write-Host "   This might be due to the directory not existing or permissions" -ForegroundColor Yellow
    }
} catch {
    if ($_.Exception.Response.StatusCode -eq 403) {
        Write-Host "❌ FAIL - Allowed exception was blocked (HTTP 403)" -ForegroundColor Red
    } else {
        Write-Host "⚠️ WARNING - Non-403 error (likely filesystem): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Test 5: Test ProgramData allowed exception  
Write-Host ""
Write-Host "5️⃣ Testing ProgramData Allowed Exception" -ForegroundColor White
Write-Host "   Disallowed: C:\ProgramData\\" -ForegroundColor Gray
Write-Host "   Allowed Exception: C:\ProgramData\Microsoft\Windows\Start Menu\\" -ForegroundColor Gray
try {
    $req = @{ path = "C:\ProgramData\Microsoft\Windows\Start Menu\" } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$BaseUrl/api/read" -Method POST -Body $req -ContentType "application/json"
    if ($result.success) {
        Write-Host "✅ PASS - ProgramData allowed exception working" -ForegroundColor Green
    } else {
        Write-Host "⚠️ WARNING - Allowed path accessible but returned: $($result.error)" -ForegroundColor Yellow
    }
} catch {
    if ($_.Exception.Response.StatusCode -eq 403) {
        Write-Host "❌ FAIL - Allowed exception was blocked (HTTP 403)" -ForegroundColor Red
    } else {
        Write-Host "⚠️ WARNING - Non-403 error (likely filesystem): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Test 6: Test that non-allowed areas within disallowed directories are still blocked
Write-Host ""
Write-Host "6️⃣ Testing Non-Allowed Area in Disallowed Directory (Should be Blocked)" -ForegroundColor White
Write-Host "   Path: C:\Windows\System32\ (not in allowed exceptions)" -ForegroundColor Gray
try {
    $req = @{ path = "C:\Windows\System32\" } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$BaseUrl/api/read" -Method POST -Body $req -ContentType "application/json" -ErrorAction Stop
    Write-Host "❌ FAIL - Non-allowed area in disallowed directory was not blocked!" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 403) {
        Write-Host "✅ PASS - Non-allowed area correctly blocked (HTTP 403)" -ForegroundColor Green
    } else {
        Write-Host "⚠️ WARNING - Non-403 error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Test 7: Test default allowed path (not in any list)
Write-Host ""
Write-Host "7️⃣ Testing Default Allowed Path (Not in Any List)" -ForegroundColor White
$userDesktop = "C:\Users\smuha\Desktop\exex-default-allowed-test.txt"
Write-Host "   Path: $userDesktop" -ForegroundColor Gray
try {
    $writeReq = @{ path = $userDesktop; content = "Default allowed path test" } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$BaseUrl/api/write" -Method POST -Body $writeReq -ContentType "application/json"
    if ($result.success) {
        Write-Host "✅ PASS - Default allowed path working (not in disallowed list)" -ForegroundColor Green
    } else {
        Write-Host "❌ FAIL - Default allowed path failed: $($result.error)" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ FAIL - Default allowed path blocked: $($_.Exception.Message)" -ForegroundColor Red
}

# Cleanup
Write-Host ""
Write-Host "8️⃣ Cleanup" -ForegroundColor White
try {
    if (Test-Path $tempTestFile) {
        Remove-Item $tempTestFile -Force
        Write-Host "✅ Cleaned up test file: $tempTestFile" -ForegroundColor Green
    }
    if (Test-Path $userDesktop) {
        Remove-Item $userDesktop -Force
        Write-Host "✅ Cleaned up test file: $userDesktop" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️ Cleanup warning: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎯 Priority System Summary:" -ForegroundColor Magenta
Write-Host "✓ Step 1: Check if path is in allowed_paths (HIGHEST PRIORITY)" -ForegroundColor Green
Write-Host "✓ Step 2: Check if path is in disallowed_paths (MEDIUM PRIORITY)" -ForegroundColor Yellow  
Write-Host "✓ Step 3: Default behavior - allow all other paths (LOWEST PRIORITY)" -ForegroundColor Cyan

Write-Host ""
Write-Host "📋 Configuration:" -ForegroundColor Magenta
Write-Host "• Config location: C:\Users\smuha\AppData\Local\EXEX\exex.config.json" -ForegroundColor Gray
Write-Host "• Disallowed paths: 7 system directories" -ForegroundColor Gray
Write-Host "• Allowed exceptions: 3 specific safe areas within disallowed directories" -ForegroundColor Gray

Write-Host ""
Write-Host "✨ Allowed Paths Test Complete!" -ForegroundColor Green
