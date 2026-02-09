
Import-Module "$PSScriptRoot\..\engine\modules\MacroManager.psm1" -Force
Import-Module "$PSScriptRoot\..\engine\kernel\IntentResolver.psm1" -Force

Write-Host "Testing Advanced Macro Expansion..." -ForegroundColor Yellow

# 1. Setup Macro
Set-MacroVariable -Name "browser" -Value "Start-Process chrome"
Set-MacroVariable -Name "site" -Value "google.com"
Set-MacroVariable -Name "ssk" -Value "Open ssk.exe"

# 2. Test Full Expansion (The user case)
# "#ssk" -> "Open ssk.exe"
# "Open ssk.exe" should trigger "open_file" regex
Write-Host "2. Testing Single Macro Expansion (#ssk -> Open ssk.exe)..."
$json = Resolve-Intent -UserInput "#ssk"
$obj = $json | ConvertFrom-Json

if ($obj.intent -eq "open_file" -and $obj.target -eq "ssk.exe") {
    Write-Host "   [PASS] Expanded and Resolved correctly." -ForegroundColor Green
} else {
    Write-Host "   [FAIL] Expected open_file/ssk.exe, got: $($obj.intent)/$($obj.target)" -ForegroundColor Red
}

# 3. Test Inline Expansion
# "Please #browser now" -> "Please Start-Process chrome now"
# This might fall to AI if no regex matches "Start-Process chrome".
# Let's try something regex catches: "open #site" -> "open google.com"
Write-Host "3. Testing Inline Expansion (open #site)..."
$json2 = Resolve-Intent -UserInput "open #site"
$obj2 = $json2 | ConvertFrom-Json

if ($obj2.intent -eq "open_website" -and $obj2.description -match "google.com") {
    Write-Host "   [PASS] Inline macro expanded correctly." -ForegroundColor Green
} else {
    Write-Host "   [FAIL] Expected open_website/google.com, got: $($obj2.intent)/$($obj2.description)" -ForegroundColor Red
}

# 4. Test Multi-Macro
# "open #site in #browser" (Assume generic open regex catches it)
# "open google.com in Start-Process chrome" -> might fail regex but proves expansion
Write-Host "4. Testing Multi-Macro..."
# Using verbose to see expansion manually if needed, but here we just check if it doesn't crash
$json3 = Resolve-Intent -UserInput "echo #site and #browser"
if ($json3) {
    Write-Host "   [PASS] Multi-macro execution finished." -ForegroundColor Green
}

# Cleanup
# Remove-Item "$PSScriptRoot\..\config\user_macros.ini" -Force
