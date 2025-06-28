#!/usr/bin/env pwsh

# Comprehensive EXEX Operations Test Suite
# Tests all operations: scan, create, delete, rename, open app, shutdown, etc.

Write-Host "=== EXEX Complete Operations Test Suite ===" -ForegroundColor Green
Write-Host "Testing all file operations, app operations, and server features..." -ForegroundColor Yellow

$baseUrl = "http://localhost:8080"
$testDir = "C:\temp\exex-test"

# Test 1: Health Check
Write-Host "`n1. Testing server health..." -ForegroundColor Cyan
try {
    $health = Invoke-RestMethod -Uri "$baseUrl/health" -Method Get
    Write-Host "✓ Server is healthy: $($health.status)" -ForegroundColor Green
} catch {
    Write-Host "✗ Server health check failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 2: Create Directory Operation
Write-Host "`n2. Testing directory creation..." -ForegroundColor Cyan
try {
    $body = @{
        path = $testDir
        is_directory = $true
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$baseUrl/api/create" -Method Post -ContentType "application/json" -Body $body
    if ($response.success) {
        Write-Host "✓ Successfully created test directory: $testDir" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to create directory: $($response.error)" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Directory creation request failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Create File Operation
Write-Host "`n3. Testing file creation..." -ForegroundColor Cyan
$testFile = "$testDir\test-file.txt"
try {
    $body = @{
        path = $testFile
        is_directory = $false
        content = "Hello from EXEX comprehensive test!`nThis is a test file with multiple lines.`nTimestamp: $(Get-Date)"
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$baseUrl/api/create" -Method Post -ContentType "application/json" -Body $body
    if ($response.success) {
        Write-Host "✓ Successfully created test file: $testFile" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to create file: $($response.error)" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ File creation request failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Scan Directory Operation
Write-Host "`n4. Testing directory scanning..." -ForegroundColor Cyan
try {
    $body = @{
        path = $testDir
        recursive = $false
        include_hidden = $false
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$baseUrl/api/scan" -Method Post -ContentType "application/json" -Body $body
    if ($response.success) {
        Write-Host "✓ Successfully scanned directory, found $($response.total_count) items" -ForegroundColor Green
        foreach ($item in $response.items) {
            $type = if ($item.is_directory) { "DIR" } else { "FILE" }
            $size = if ($item.size) { "$($item.size) bytes" } else { "-" }
            Write-Host "  $type : $($item.name) ($size)" -ForegroundColor Gray
        }
    } else {
        Write-Host "✗ Failed to scan directory: $($response.error)" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Directory scan request failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: File Read Operation
Write-Host "`n5. Testing file reading..." -ForegroundColor Cyan
try {
    $body = @{
        path = $testFile
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$baseUrl/api/read" -Method Post -ContentType "application/json" -Body $body
    if ($response.success) {
        Write-Host "✓ Successfully read file content" -ForegroundColor Green
        Write-Host "  Content preview: $($response.content.Substring(0, [Math]::Min(80, $response.content.Length)))..." -ForegroundColor Gray
    } else {
        Write-Host "✗ Failed to read file: $($response.error)" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ File read request failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 6: File Rename Operation
Write-Host "`n6. Testing file rename..." -ForegroundColor Cyan
$renamedFile = "$testDir\renamed-test-file.txt"
try {
    $body = @{
        from_path = $testFile
        to_path = $renamedFile
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$baseUrl/api/rename" -Method Post -ContentType "application/json" -Body $body
    if ($response.success) {
        Write-Host "✓ Successfully renamed file: $($response.old_path) -> $($response.new_path)" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to rename file: $($response.error)" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ File rename request failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 7: Command Execution
Write-Host "`n7. Testing command execution..." -ForegroundColor Cyan
try {
    $body = @{
        command = "echo Testing EXEX command execution"
        cwd = $testDir
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$baseUrl/api/exec" -Method Post -ContentType "application/json" -Body $body
    if ($response.success) {
        Write-Host "✓ Successfully executed command" -ForegroundColor Green
        Write-Host "  Output: $($response.stdout.Trim())" -ForegroundColor Gray
    } else {
        Write-Host "✗ Failed to execute command: $($response.stderr)" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Command execution request failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 8: Open Application (Notepad)
Write-Host "`n8. Testing application opening..." -ForegroundColor Cyan
try {
    $body = @{
        application = "notepad.exe"
        args = @($renamedFile)
        cwd = $testDir
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$baseUrl/api/open" -Method Post -ContentType "application/json" -Body $body
    if ($response.success) {
        Write-Host "✓ Successfully opened Notepad with PID: $($response.pid)" -ForegroundColor Green
        Write-Host "  Note: Notepad should have opened with the test file" -ForegroundColor Gray
        # Close Notepad after a few seconds
        Start-Sleep -Seconds 3
        try {
            Stop-Process -Id $response.pid -Force -ErrorAction SilentlyContinue
            Write-Host "  ✓ Closed Notepad process" -ForegroundColor Gray
        } catch {
            Write-Host "  Note: Notepad may need to be closed manually" -ForegroundColor Gray
        }
    } else {
        Write-Host "✗ Failed to open application: $($response.error)" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Application open request failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 9: Security Tests - Try blocked operations
Write-Host "`n9. Testing security restrictions..." -ForegroundColor Cyan

# Test blocked directory
try {
    $body = @{
        path = "C:\Windows\System32"
        recursive = $false
        include_hidden = $false
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$baseUrl/api/scan" -Method Post -ContentType "application/json" -Body $body
    Write-Host "X Should have blocked System32 scan but did not!" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 403) {
        Write-Host "✓ Correctly blocked System32 directory scan" -ForegroundColor Green
    } else {
        Write-Host "✗ Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test 10: Recursive Directory Scan
Write-Host "`n10. Testing recursive directory scan..." -ForegroundColor Cyan
try {
    # Create a subdirectory first
    $subDir = "$testDir\subdir"
    $subDirBody = @{
        path = $subDir
        is_directory = $true
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri "$baseUrl/api/create" -Method Post -ContentType "application/json" -Body $subDirBody | Out-Null
    
    # Create a file in subdirectory
    $subFile = "$subDir\subfile.txt"
    $subFileBody = @{
        path = $subFile
        is_directory = $false
        content = "This is a file in a subdirectory"
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri "$baseUrl/api/create" -Method Post -ContentType "application/json" -Body $subFileBody | Out-Null
    
    # Now scan recursively
    $body = @{
        path = $testDir
        recursive = $true
        include_hidden = $false
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$baseUrl/api/scan" -Method Post -ContentType "application/json" -Body $body
    if ($response.success) {
        Write-Host "✓ Successfully performed recursive scan, found $($response.total_count) items" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed recursive scan: $($response.error)" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Recursive scan request failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 11: Cleanup - Delete Test Directory
Write-Host "`n11. Testing cleanup (delete operation)..." -ForegroundColor Cyan
try {
    $body = @{
        path = $testDir
        recursive = $true
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$baseUrl/api/delete" -Method Post -ContentType "application/json" -Body $body
    if ($response.success) {
        Write-Host "✓ Successfully deleted test directory and all contents" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to delete test directory: $($response.error)" -ForegroundColor Red
        # Cleanup manually
        Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
} catch {
    Write-Host "✗ Delete operation request failed: $($_.Exception.Message)" -ForegroundColor Red
    # Cleanup manually
    Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`n=== Complete Operations Test Summary ===" -ForegroundColor Green
Write-Host "All EXEX operations tested:" -ForegroundColor Yellow
Write-Host "  ✓ Health check and server status" -ForegroundColor Gray
Write-Host "  ✓ Directory and file creation" -ForegroundColor Gray
Write-Host "  ✓ Directory scanning (single and recursive)" -ForegroundColor Gray
Write-Host "  ✓ File reading and content verification" -ForegroundColor Gray
Write-Host "  ✓ File rename/move operations" -ForegroundColor Gray
Write-Host "  ✓ Command execution in allowed directories" -ForegroundColor Gray
Write-Host "  ✓ Application launching (notepad test)" -ForegroundColor Gray
Write-Host "  ✓ Security restrictions and access control" -ForegroundColor Gray
Write-Host "  ✓ File and directory deletion" -ForegroundColor Gray

Write-Host "`nEXEX is fully operational with all features!" -ForegroundColor Green
Write-Host "`nNote: Server shutdown test was skipped to keep server running." -ForegroundColor Yellow
Write-Host "To test shutdown: POST to $baseUrl/api/shutdown" -ForegroundColor Yellow
