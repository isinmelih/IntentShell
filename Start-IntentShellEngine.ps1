
# IntentShell Core Engine Loader
# Imports all necessary modules

$engineRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Import AI Layer (Intelligence)
Import-Module "$engineRoot\engine\intelligence\AIEngine.psm1" -Force

# Import Core (Kernel)
Import-Module "$engineRoot\engine\kernel\Registry.psm1" -Force
Import-Module "$engineRoot\engine\kernel\Sentinel.psm1" -Force
Import-Module "$engineRoot\engine\kernel\IntentResolver.psm1" -Force
Import-Module "$engineRoot\engine\kernel\CommandGenerator.psm1" -Force
Import-Module "$engineRoot\engine\kernel\ExecutionEngine.psm1" -Force

# Import Modules
$modules = Get-ChildItem "$engineRoot\engine\modules\*.psm1"
foreach ($mod in $modules) {
    Import-Module $mod.FullName -Force
}

Write-Host ">>> POWERSHELL VERSION:" $PSVersionTable.PSVersion
Write-Host ">>> EDITION:" $PSVersionTable.PSEdition
Write-Host "IntentShell PowerShell Engine Loaded Successfully." -ForegroundColor Green
Write-Host "AI Engine: Ready (Ollama)" -ForegroundColor Cyan
Write-Host "Registry: Loaded" -ForegroundColor Cyan
Write-Host "Execution Engine: Secure" -ForegroundColor Cyan

# Check for Flow Mode
if ($env:INTENTSHELL_FLOW_MODE -eq "1") {
    Write-Host "Auto-Activating Flow Mode..." -ForegroundColor Magenta
    Enter-FlowMode -Task "Auto-Start Session"
}


