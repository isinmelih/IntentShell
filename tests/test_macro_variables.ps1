
Import-Module "$PSScriptRoot\..\engine\modules\MacroManager.psm1" -Force
Import-Module "$PSScriptRoot\..\engine\kernel\IntentResolver.psm1" -Force

Write-Host "Testing Macro Variable System..." -ForegroundColor Yellow

# 1. Set a variable
Write-Host "1. Setting variable #zoom..."
Set-MacroVariable -Name "zoom" -Value "Open C:\Windows"

# Verify it's in the file
$configPath = "$PSScriptRoot\..\config\user_macros.ini"
if (Get-Content $configPath | Select-String "zoom=Open C:\\Windows") {
    Write-Host "   [PASS] Variable saved to .ini" -ForegroundColor Green
} else {
    Write-Host "   [FAIL] Variable NOT found in .ini" -ForegroundColor Red
}

# 2. Resolve Intent
Write-Host "2. Resolving intent #zoom..."
$json = Resolve-Intent -UserInput "#zoom"
$obj = $json | ConvertFrom-Json

if ($obj.intent -eq "open_file" -and $obj.target -eq "C:\Windows") {
    Write-Host "   [PASS] Intent resolved correctly to: $($obj.description)" -ForegroundColor Green
} else {
    Write-Host "   [FAIL] Intent resolution failed. Got:" -ForegroundColor Red
    Write-Host $json
}

# 3. Test "Set Macro" Intent
Write-Host "3. Testing 'set macro' intent..."
$setJson = Resolve-Intent -UserInput "set macro testvar to echo hello"
$setObj = $setJson | ConvertFrom-Json

if ($setObj.intent -eq "set_macro" -and $setObj.generated_command -match "Set-MacroVariable -Name 'testvar'") {
    Write-Host "   [PASS] Set Macro intent recognized." -ForegroundColor Green
} else {
    Write-Host "   [FAIL] Set Macro intent failed." -ForegroundColor Red
    Write-Host $setJson
}

# Cleanup
# Remove-Item $configPath -ErrorAction SilentlyContinue
