# EXEX API Test Script for PowerShell
# Run this script to test the EXEX API endpoints

$BaseUrl = "http://127.0.0.1:8080"

function Invoke-ExexApi {
    param(
        [string]$Endpoint,
        [hashtable]$Body = $null,
        [string]$Method = "GET"
    )
    
    $uri = "$BaseUrl$Endpoint"
    
    Write-Host "🔄 $Method $uri" -ForegroundColor Cyan
    
    try {
        $headers = @{ "Content-Type" = "application/json" }
        
        if ($Body) {
            $jsonBody = $Body | ConvertTo-Json -Depth 3
            Write-Host "📤 Request:" -ForegroundColor Yellow
            Write-Host $jsonBody -ForegroundColor Gray
            
            $response = Invoke-RestMethod -Uri $uri -Method $Method -Body $jsonBody -Headers $headers
        } else {
            $response = Invoke-RestMethod -Uri $uri -Method $Method -Headers $headers
        }
        
        Write-Host "📥 Response:" -ForegroundColor Green
        Write-Host ($response | ConvertTo-Json -Depth 3) -ForegroundColor Gray
        Write-Host "---" -ForegroundColor DarkGray
        
        return $response
    }
    catch {
        Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "---" -ForegroundColor DarkGray
        return $null
    }
}

Write-Host "🧪 EXEX API Test Suite" -ForegroundColor Magenta
Write-Host ""

# Test 1: Health Check
Write-Host "1️⃣ Testing Health Check" -ForegroundColor White
Invoke-ExexApi -Endpoint "/health"

# Test 2: Execute Command
Write-Host "2️⃣ Testing Command Execution" -ForegroundColor White
$execBody = @{
    command = "echo Hello from EXEX!"
    cwd = $env:USERPROFILE
}
Invoke-ExexApi -Endpoint "/api/exec" -Method "POST" -Body $execBody

# Test 3: Execute Directory Listing
Write-Host "3️⃣ Testing Directory Listing" -ForegroundColor White
$dirBody = @{
    command = "dir"
    cwd = $env:USERPROFILE
}
Invoke-ExexApi -Endpoint "/api/exec" -Method "POST" -Body $dirBody

# Test 4: Write File
Write-Host "4️⃣ Testing File Write" -ForegroundColor White
$testFilePath = Join-Path $env:USERPROFILE "Desktop\exex-test-ps.txt"
$writeBody = @{
    path = $testFilePath
    content = "EXEX Test File (PowerShell)`nCreated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`nTest successful!"
}
Invoke-ExexApi -Endpoint "/api/write" -Method "POST" -Body $writeBody

# Test 5: Read the file we just wrote
Write-Host "5️⃣ Testing File Read" -ForegroundColor White
$readBody = @{
    path = $testFilePath
}
Invoke-ExexApi -Endpoint "/api/read" -Method "POST" -Body $readBody

# Test 6: Test Security - Try to access restricted path
Write-Host "6️⃣ Testing Security (should be denied)" -ForegroundColor White
$securityTestBody = @{
    path = "C:\Windows\System32\kernel32.dll"
}
Invoke-ExexApi -Endpoint "/api/read" -Method "POST" -Body $securityTestBody

# Test 7: Test invalid command execution
Write-Host "7️⃣ Testing Invalid Command" -ForegroundColor White
$invalidCmdBody = @{
    command = "nonexistentcommand12345"
    cwd = $env:USERPROFILE
}
Invoke-ExexApi -Endpoint "/api/exec" -Method "POST" -Body $invalidCmdBody

Write-Host "✅ Test suite completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Note: Some tests may fail if files don't exist or permissions are insufficient." -ForegroundColor Yellow
Write-Host "The security test should show 'Access denied' - this is expected behavior." -ForegroundColor Yellow
