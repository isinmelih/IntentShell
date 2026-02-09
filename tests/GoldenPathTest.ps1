# Golden Path Test Runner
$LogFile = "$PSScriptRoot\golden_path_result.txt"
Start-Transcript -Path $LogFile -Force

using module ..\engine\modules\SystemCore.psm1

# Simulates "projeyi test et"

$projectRoot = "c:\Users\user\Documents\trae_projects\IntentShell"
Write-Host "Project Root: $projectRoot"

# 1. Load Environment
# SystemCore is already loaded via using module, but we force import others
try {
    Write-Host "Loading modules..."
    Import-Module "$projectRoot\engine\modules\MacroManager.psm1" -Force
    Import-Module "$projectRoot\engine\modules\IntentChaining.psm1" -Force
    Import-Module "$projectRoot\engine\modules\PathResolution.psm1" -Force
    Import-Module "$projectRoot\engine\modules\EnvManager.psm1" -Force
    Import-Module "$projectRoot\engine\modules\SafetyCheck.psm1" -Force
    Import-Module "$projectRoot\engine\kernel\ExecutionEngine.psm1" -Force
    Import-Module "$projectRoot\engine\kernel\Sentinel.psm1" -Force
    Write-Host "Modules loaded."
} catch {
    Write-Error "Module loading failed: $_"
    Stop-Transcript
    exit 1
}

# 2. Define Test Script Path
$testScript = "$projectRoot\tests\test_golden_path.py"

# 3. Simulate Intent
Write-Host "STARTING GOLDEN PATH TEST: 'Run Golden Path Test'" -ForegroundColor Yellow

# Mock IntentChaining Step
$step = @{
    command = "python $testScript"
    description = "Run Golden Path Test Script"
    continue_on_error = $false
}

# 4. Run Chain
try {
    Write-Host "Invoking Intent Chain..."
    $results = Invoke-IntentChain -Steps @($step) -StopOnError
    
    # 5. Verify Results
    if ($results.Count -gt 0 -and $results[0].Status -eq 'Success') {
        Write-Host "GOLDEN PATH PASSED" -ForegroundColor Green
    } else {
        Write-Host "GOLDEN PATH FAILED" -ForegroundColor Red
        $results | Format-Table | Out-String | Write-Host
    }
}
catch {
    Write-Host "GOLDEN PATH CRASHED: $_" -ForegroundColor Red
    $error | Format-List | Out-String | Write-Host
}

# 6. Dump Decision History (Explain Mode)
Write-Host "Decision History (Explain Mode):" -ForegroundColor Cyan
if ([SystemCore]::DecisionHistory.Count -gt 0) {
    [SystemCore]::DecisionHistory | Format-Table -AutoSize | Out-String | Write-Host
} else {
    Write-Warning 'No Decision History found.'
}

Stop-Transcript

