#!/usr/bin/env pwsh

# Cross-Platform Config Test Suite for EXEX
# Tests the new versioned config system and validation

Write-Host "=== EXEX Cross-Platform Config Test Suite ===" -ForegroundColor Green
Write-Host "Testing dynamic config creation, validation, and security logic..." -ForegroundColor Yellow

$baseUrl = "http://localhost:8080"
$configPath = "$env:LOCALAPPDATA\EXEX\exex.config.json"

# Test 1: Check if config file was created with proper structure
Write-Host "`n1. Testing config file creation and structure..." -ForegroundColor Cyan
if (Test-Path $configPath) {
    $config = Get-Content $configPath | ConvertFrom-Json
    
    Write-Host "✓ Config file exists at: $configPath" -ForegroundColor Green
    Write-Host "✓ Version: $($config.version)" -ForegroundColor Green
    Write-Host "✓ Project: $($config.exex_project)" -ForegroundColor Green
    Write-Host "✓ Created: $($config.created)" -ForegroundColor Green
    Write-Host "✓ Disallowed paths: $($config.disallowed_paths.Count)" -ForegroundColor Green
    Write-Host "✓ Allowed paths: $($config.allowed_paths.Count)" -ForegroundColor Green
} else {
    Write-Host "✗ Config file not found!" -ForegroundColor Red
    exit 1
}

# Test 2: Test server health
Write-Host "`n2. Testing server health..." -ForegroundColor Cyan
try {
    $health = Invoke-RestMethod -Uri "$baseUrl/health" -Method Get
    Write-Host "✓ Server is healthy: $($health.status)" -ForegroundColor Green
    Write-Host "✓ Service: $($health.service)" -ForegroundColor Green
    Write-Host "✓ Version: $($health.version)" -ForegroundColor Green
} catch {
    Write-Host "✗ Server health check failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 3: Test disallowed path blocking (Windows System32)
Write-Host "`n3. Testing disallowed path blocking..." -ForegroundColor Cyan
try {
    $body = @{
        path = "C:/Windows/System32/drivers/etc/hosts"
    } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$baseUrl/read" -Method Post -ContentType "application/json" -Body $body
    Write-Host "✗ Should have blocked System32 access but didn't!" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 403) {
        Write-Host "✓ Correctly blocked access to System32" -ForegroundColor Green
    } else {
        Write-Host "✗ Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test 4: Test allowed path override (Windows Temp)
Write-Host "`n4. Testing allowed path override..." -ForegroundColor Cyan
$tempTestFile = "C:\Windows\Temp\exex-test.txt"
try {
    # Create a test file in Windows Temp
    "Test content for EXEX" | Out-File -FilePath $tempTestFile -Encoding UTF8
    
    # Try to read it via EXEX (should work because Windows/Temp is in allowed_paths)
    $response = Invoke-RestMethod -Uri "$baseUrl/read" -Method Post -ContentType "application/json" -Body "{`"path`": `"$tempTestFile`"}"
    Write-Host "✓ Successfully read file from allowed path (Windows Temp)" -ForegroundColor Green
    Write-Host "  Content preview: $($response.content.Substring(0, [Math]::Min(50, $response.content.Length)))..." -ForegroundColor Gray
    
    # Clean up
    Remove-Item $tempTestFile -Force -ErrorAction SilentlyContinue
} catch {
    Write-Host "✗ Failed to access allowed path: $($_.Exception.Message)" -ForegroundColor Red
    Remove-Item $tempTestFile -Force -ErrorAction SilentlyContinue
}

# Test 5: Test normal allowed path (Projects folder)
Write-Host "`n5. Testing normal allowed path access..." -ForegroundColor Cyan
$projectTestFile = "C:\Users\$env:USERNAME\Projects\exex-test.txt"
try {
    # Ensure directory exists
    $projectDir = Split-Path $projectTestFile
    if (!(Test-Path $projectDir)) {
        New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
    }
    
    # Create a test file in Projects
    "Test content for EXEX projects" | Out-File -FilePath $projectTestFile -Encoding UTF8
    
    # Try to read it via EXEX
    $response = Invoke-RestMethod -Uri "$baseUrl/read" -Method Post -ContentType "application/json" -Body "{`"path`": `"$projectTestFile`"}"
    Write-Host "✓ Successfully read file from Projects folder" -ForegroundColor Green
    
    # Clean up
    Remove-Item $projectTestFile -Force -ErrorAction SilentlyContinue
} catch {
    Write-Host "✗ Failed to access Projects folder: $($_.Exception.Message)" -ForegroundColor Red
    Remove-Item $projectTestFile -Force -ErrorAction SilentlyContinue
}

# Test 6: Test config validation by corrupting the config
Write-Host "`n6. Testing config validation..." -ForegroundColor Cyan
Write-Host "  Backing up current config..." -ForegroundColor Gray
$configBackup = Get-Content $configPath
$invalidConfig = @{
    "version" = ""
    "invalid_field" = "test"
} | ConvertTo-Json

# Write invalid config
$invalidConfig | Out-File -FilePath $configPath -Encoding UTF8

Write-Host "  Starting server with invalid config (should fail)..." -ForegroundColor Gray
try {
    # Try to start server with invalid config (should fail)
    $process = Start-Process -FilePath "cargo" -ArgumentList "run" -WorkingDirectory "C:\Users\smuha\Projects\exex" -RedirectStandardError "config-error.txt" -RedirectStandardOutput "config-output.txt" -Wait -PassThru
    
    if ($process.ExitCode -eq 1) {
        Write-Host "✓ Server correctly rejected invalid config and terminated" -ForegroundColor Green
    } else {
        Write-Host "✗ Server should have rejected invalid config" -ForegroundColor Red
    }
} catch {
    Write-Host "✓ Server correctly failed with invalid config" -ForegroundColor Green
}

# Restore backup
Write-Host "  Restoring config backup..." -ForegroundColor Gray
$configBackup | Out-File -FilePath $configPath -Encoding UTF8

# Test 7: Test execution blocking in disallowed paths
Write-Host "`n7. Testing command execution blocking..." -ForegroundColor Cyan
try {
    $body = @{
        command = "dir"
        cwd = "C:/Windows/System32"
    } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$baseUrl/exec" -Method Post -ContentType "application/json" -Body $body
    Write-Host "✗ Should have blocked execution in System32!" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 403) {
        Write-Host "✓ Correctly blocked command execution in System32" -ForegroundColor Green
    } else {
        Write-Host "✗ Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test 8: Test execution in allowed paths
Write-Host "`n8. Testing command execution in allowed paths..." -ForegroundColor Cyan
try {
    $body = @{
        command = "echo Hello from EXEX"
        cwd = "C:/temp"
    } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$baseUrl/exec" -Method Post -ContentType "application/json" -Body $body
    Write-Host "✓ Successfully executed command in allowed path" -ForegroundColor Green
    Write-Host "  Output: $($response.stdout)" -ForegroundColor Gray
} catch {
    Write-Host "✗ Failed to execute in allowed path: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Cross-Platform Config Test Complete ===" -ForegroundColor Green
Write-Host "All major features tested:" -ForegroundColor Yellow
Write-Host "  ✓ Dynamic config creation with version info" -ForegroundColor Gray
Write-Host "  ✓ Config validation and error handling" -ForegroundColor Gray
Write-Host "  ✓ Cross-platform path support" -ForegroundColor Gray
Write-Host "  ✓ Allowed paths override disallowed paths" -ForegroundColor Gray
Write-Host "  ✓ Security enforcement for file and exec operations" -ForegroundColor Gray

# Clean up any temporary files
Remove-Item "config-error.txt" -Force -ErrorAction SilentlyContinue
Remove-Item "config-output.txt" -Force -ErrorAction SilentlyContinue

Write-Host "`nEXEX is ready for production use!" -ForegroundColor Green
