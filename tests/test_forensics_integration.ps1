# Test Script for Forensic Integration
# Verifies: Intent Parsing -> Forensics Module -> GhostDriver -> Memory Read

$ErrorActionPreference = "Stop"

Write-Host "1. Testing Intent Resolution (Regex)..." -ForegroundColor Cyan

# Import dependencies
Import-Module "$PSScriptRoot\..\engine\kernel\Registry.psm1" -Force
Import-Module "$PSScriptRoot\..\engine\kernel\IntentResolver.psm1" -Force
Import-Module "$PSScriptRoot\..\engine\intelligence\AIEngine.psm1" -Force # Fallback requirement

$userInput = "notepad s$([char]0x00FC)recini analiz et"
Write-Host "Input: $userInput"

# Debug regex match directly in test script to verify encoding
if ($userInput -match '(.+?)\s+(?:s\u00FCrecini|uygulamas\u0131n\u0131)\s+(?:analiz et|tara|incele)') {
    Write-Host "Regex MATCHED in test script check." -ForegroundColor Green
} else {
    Write-Host "Regex FAILED in test script check." -ForegroundColor Red
}

$json = Resolve-Intent -UserInput $userInput
$intent = $json | ConvertFrom-Json

if ($intent.intent -eq "forensic_analyze") {
    Write-Host "SUCCESS: Intent Resolved Correctly!" -ForegroundColor Green
    Write-Host "Target: $($intent.target)"
    Write-Host "Command: $($intent.generated_command)"
} else {
    Write-Error "FAILED: Intent resolution mismatch. Got: $($intent.intent)"
}

Write-Host "`n2. Executing Generated Command (Simulated)..." -ForegroundColor Cyan

# Check if notepad is running, start if not
if (-not (Get-Process -Name "notepad" -ErrorAction SilentlyContinue)) {
    Write-Host "Starting Notepad for testing..." -ForegroundColor Yellow
    Start-Process notepad
    Start-Sleep -Seconds 1
}

# Execute the command
try {
    # Need to adjust PSScriptRoot for the Invoke-Expression context or use absolute path
    # The generated command uses $PSScriptRoot which might be empty in Invoke-Expression context
    # So we replace it with actual path for this test
    $enginePath = "$PSScriptRoot\..\engine\kernel"
    $cmd = $intent.generated_command.Replace("`$PSScriptRoot", $enginePath)
    
    Invoke-Expression $cmd | Format-List
    Write-Host "SUCCESS: Forensic Scan Completed!" -ForegroundColor Green
}
catch {
    Write-Error "FAILED: Command Execution Error: $_"
}
