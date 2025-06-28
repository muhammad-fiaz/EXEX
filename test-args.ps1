# Test the new args functionality
Write-Host "Testing EXEX Command Execution with Args..."

$baseUrl = "http://127.0.0.1:8080"

# Test 1: Command with separate args (recommended approach)
$payload1 = @{
    command = "echo"
    args = @("Hello", "World", "from", "args")
} | ConvertTo-Json

Write-Host "`nTest 1: Command with args array"
Write-Host "Payload: $payload1"

# Test 2: Command as single string (backward compatible)
$payload2 = @{
    command = "echo Hello World from string"
} | ConvertTo-Json

Write-Host "`nTest 2: Command as single string"
Write-Host "Payload: $payload2"

Write-Host "`nTo test these commands, run the server with 'cargo run' in another terminal, then use these payloads with Invoke-RestMethod:"
Write-Host "Invoke-RestMethod -Uri '$baseUrl/api/exec' -Method POST -Body `$payload1 -ContentType 'application/json'"
Write-Host "Invoke-RestMethod -Uri '$baseUrl/api/exec' -Method POST -Body `$payload2 -ContentType 'application/json'"
