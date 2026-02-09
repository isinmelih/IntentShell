@echo off
setlocal EnableDelayedExpansion

:: ==================================================
:: IntentShell Device Debug Tool
:: Generates a comprehensive diagnostic report for troubleshooting.
:: ==================================================

:: Generate Report Filename with Timestamp
title IntentShell - Debug Service
set "CURRENT_DATE=%DATE%"
set "CURRENT_TIME=%TIME%"
:: Format date/time safely for filename (handling locale differences)
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "TIMESTAMP=%%i"
set "REPORT_FILE=DeviceDebug_Report_%TIMESTAMP%.txt"

:: Initialize Status Flags for Summary
set "SUMMARY_SYS=OK"
set "SUMMARY_PRIV=User (Non-Admin)"
set "SUMMARY_PWSH=OK"
set "SUMMARY_PY=OK"
set "SUMMARY_DEPS=OK"
set "SUMMARY_INTEGRITY=OK"
set "SUMMARY_GPU=N/A"

cls
echo ==================================================
echo       IntentShell Device Debug Tool
echo ==================================================
echo.
echo Generating diagnostic report...
echo Target file: %REPORT_FILE%
echo.

:: Initialize Report
    title IntentShell - Debug Service (Initializing)
(
    echo ==================================================
    echo       IntentShell Device Debug Report
    echo ==================================================
    echo Date: %DATE% %TIME%
    echo Hostname: %COMPUTERNAME%
    echo ==================================================
    echo.
) > "%REPORT_FILE%"

:: 1. System & Privilege Status
echo [1/7] Checking System ^& Privileges...
    title IntentShell - Debug Service (System Scan)
(
    echo [SYSTEM STATUS]
    ver
    echo.
    echo [PRIVILEGE LEVEL]
    whoami /groups | find "S-1-16-12288" >nul && (
        echo [OK] Elevated ^(Admin^)
        set "SUMMARY_PRIV=Admin (Elevated)"
    ) || (
        echo [WARN] Not Elevated ^(User^)
        echo Note: Some advanced IntentShell features require Admin.
    )
    echo.
) >> "%REPORT_FILE%" 2>&1

:: 2. PowerShell 7 Verification
echo [2/7] Checking PowerShell 7...
    title IntentShell - Debug Service (PowerShell 7 Verification)
(
    echo [POWERSHELL 7 DIAGNOSTIC]
    where pwsh >nul 2>&1
    if !errorlevel! equ 0 (
        echo [OK] pwsh found at:
        where pwsh
        echo.
        echo Version info:
        pwsh -Command "$PSVersionTable.PSVersion.ToString()"
    ) else (
        echo [CRITICAL] pwsh ^(PowerShell 7^) NOT found in PATH.
        echo IntentShell requires PowerShell 7+.
        echo Please install from: https://github.com/PowerShell/PowerShell
        set "SUMMARY_PWSH=FAIL (Missing pwsh)"
    )
    echo.
) >> "%REPORT_FILE%" 2>&1

:: 3. Python Diagnosis
echo [3/7] Checking Python Environment...
    title IntentShell - Debug Service (Python Analysis)
(
    echo [PYTHON DIAGNOSTIC]
    where python >nul 2>&1
    if !errorlevel! equ 0 (
        echo [OK] Python found at:
        where python
        echo.
        
        :: Enhancement 1: WindowsApps Shim Detection
        echo [PYTHON EXECUTABLE ANALYSIS]
        powershell -NoProfile -Command "$p = (Get-Command python).Source; if ($p -match 'WindowsApps') { Write-Output '[WARN] Python executable is a WindowsApps shim.'; Write-Output 'This may cause PATH, permission, or pip-related issues.'; Write-Output 'Recommendation: Install Python from python.org or use system-wide install.' } else { Write-Output '[OK] Standard Python installation detected.' }"
        
        :: Check if it was a shim to update summary
        powershell -NoProfile -Command "$p = (Get-Command python).Source; if ($p -match 'WindowsApps') { exit 1 } else { exit 0 }"
        if !errorlevel! equ 1 set "SUMMARY_PY=WARN (WindowsApps Shim)"

        echo.
        echo Active Version:
        python --version
        echo.
        echo Pip Version:
        python -m pip --version
    ) else (
        echo [CRITICAL] Python NOT found in PATH.
        echo Please install Python 3.10+ and add to PATH.
        set "SUMMARY_PY=FAIL (Missing Python)"
    )
    echo.
    echo [PYTHON LAUNCHER]
    py --list 2>nul
    echo.
) >> "%REPORT_FILE%" 2>&1

:: 4. Environment Variables
echo [4/7] Checking Environment Variables...
    title IntentShell - Debug Service (Environmental Variables Verification)
(
    echo [ENVIRONMENT VARIABLES]
    echo PYTHONPATH=%PYTHONPATH%
    echo VIRTUAL_ENV=%VIRTUAL_ENV%
    echo.
) >> "%REPORT_FILE%" 2>&1

:: 5. Requirements & Dependencies
echo [5/7] Checking Dependencies...
    title IntentShell - Debug Service (Dependencies Verification)
(
    echo [DEPENDENCY CHECK]
    if exist requirements.txt (
        echo [OK] requirements.txt found.
        echo.
        echo [DEPENDENCY ANALYSIS]
        
        :: Enhancement 2: Detailed Dependency Analysis
        powershell -NoProfile -Command "& { $reqs = Get-Content requirements.txt -ErrorAction SilentlyContinue | Where-Object { $_ -match '^[^#]' }; $inst = python -m pip freeze 2>&1; $missing = @(); $reqs | ForEach-Object { $n = ($_ -split '[>=<]=?')[0].Trim(); if (-not ($inst -match $n)) { $missing += $n } }; if ($missing.Count -eq 0) { Write-Output '[OK] All required packages are installed.'; Write-Output '[INFO] Some installed packages are not listed in requirements.txt.'; Write-Output '       This is not an error (dependencies of dependencies).' } else { Write-Output ('[ERROR] Required package missing: ' + ($missing -join ', ')); exit 1 } }"
        
        if !errorlevel! equ 1 set "SUMMARY_DEPS=FAIL (Missing Packages)"
        
    ) else (
        echo [ERROR] requirements.txt MISSING.
        set "SUMMARY_DEPS=FAIL (Missing requirements.txt)"
    )
    echo.
    echo [INSTALLED PACKAGES SNAPSHOT]
    python -m pip freeze
    echo.
) >> "%REPORT_FILE%" 2>&1

:: 6. GPU / CUDA / Torch Check
echo [6/7] Checking GPU ^& Torch...
    title IntentShell - Debug Service (GPU And Torch Analysis)
(
    echo [GPU/TORCH DIAGNOSTIC]
    
    :: Enhancement 3: Smart Torch Check
    powershell -NoProfile -Command "& { $req = Get-Content requirements.txt -ErrorAction SilentlyContinue; $torchReq = $req -match 'torch'; $out = python -c 'import torch; print(torch.__version__)' 2>$null; if ($torchReq -and -not $out) { Write-Output '[ERROR] Torch is required (in requirements.txt) but could not be imported.'; Write-Output 'CUDA may be missing or incompatible.'; exit 1 } elseif ($torchReq) { Write-Output '[OK] Torch is required and installed.' } elseif ($out) { Write-Output '[INFO] Torch is installed but not explicitly required.' } else { Write-Output '[INFO] Torch is not listed in requirements.txt.'; Write-Output 'GPU acceleration is optional.' } }"
    
    if !errorlevel! equ 1 set "SUMMARY_GPU=FAIL (Required but Missing)"
    
    python -c "import torch; print('Torch Version:', torch.__version__); print('CUDA Available:', torch.cuda.is_available()); print('Device Name:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'N/A')" 2>nul
    echo.
) >> "%REPORT_FILE%" 2>&1

:: 7. IntentShell Specific Files
title IntentShell - Debug Service (Missing Files Analysis)
echo [7/7] Checking Project Integrity...

(
echo [PROJECT INTEGRITY]

for %%f in (
main.py
ui\overlay.py
configure.py
.env
core\powershell_session.py
config\settings.py
ui\security_dialogs.py
engine\intelligence\AIEngine.psm1
engine\modules\SystemCore.psm1
engine\modules\SystemGovernor.psm1
engine\modules\AutoFix.psm1
engine\modules\ContextMood.psm1
engine\modules\CreativeCore.psm1
engine\modules\CreativeStudio.psm1
engine\modules\CreativeSynth.psm1
engine\modules\DecisionExplainer.psm1
engine\modules\Diagnostics.psm1
engine\modules\EnvManager.psm1
engine\modules\ExperimentalLab.psm1
engine\modules\ExplainableActions.psm1
engine\modules\FileOperations.psm1
engine\modules\FlowState.psm1
engine\modules\IdeaScratchpad.psm1
engine\modules\IntentChaining.psm1
engine\modules\IntentHistory.psm1
engine\modules\IntentLearning.psm1
engine\modules\KernelDriverManager.psm1
engine\modules\MacroManager.psm1
engine\modules\MediaOperations.psm1
engine\modules\NetworkAwareness.psm1
engine\modules\OfflineCapabilities.psm1
engine\modules\OutputFormatter.psm1
engine\modules\PathResolution.psm1
engine\modules\PerformanceProfiler.psm1
engine\modules\ProactiveSuggestion.psm1
engine\modules\ProcessIntelligence.psm1
engine\modules\RegistryIntelligence.psm1
engine\modules\SafetyCheck.psm1
engine\modules\SecurityInspection.psm1
engine\modules\SessionMemory.psm1
engine\modules\SmartSearch.psm1
engine\modules\SystemForensics.psm1
engine\modules\WindowOperations.psm1
engine\kernel\CommandGenerator.psm1
engine\kernel\ExecutionEngine.psm1
engine\kernel\IntentResolver.psm1
engine\kernel\NativeOps.psm1
engine\kernel\Registry.psm1
engine\kernel\Sentinel.psm1
core\__init__.py
ui\__init__.py
tests\__init__.py
core\bridge_dispatch.py
core\bridge_nlu.py
core\bridge_runner.py
core\bridge_sentinel.py
core\command_explainer.py
core\sandbox.py
core\schemas.py
core\user_profile.py
) do (
    if exist "%%f" (
        echo [OK] %%f
    ) else (
        echo [MISSING] %%f
    )
)

) >> "%REPORT_FILE%" 2>&1

if exist "core\_init_.py" (
    echo.
    echo [WARN] core\_init_.py exists ^(typo, should be __init__.py^)
    echo [WARN] core\_init_.py exists, It should actually be __init__.py >> "%REPORT_FILE%" 2>&1
    echo [WARN] It needs to be with two underscores, not one. >> "%REPORT_FILE%" 2>&1
    echo [WARN] Please rename the core\_init_.py file to __init__.py >> "%REPORT_FILE%" 2>&1
)

if exist "ui\_init_.py" (
    echo.
    echo [WARN] ui\_init_.py exists ^(typo, should be __init__.py^)
    echo [WARN] ui\_init_.py exists, It should actually be __init__.py >> "%REPORT_FILE%" 2>&1
    echo [WARN] It needs to be with two underscores, not one. >> "%REPORT_FILE%" 2>&1
    echo [WARN] Please rename the ui\_init_.py file to __init__.py >> "%REPORT_FILE%" 2>&1
)

if exist "tests\_init_.py" (
    echo.
    echo [WARN] tests\_init_.py exists ^(typo, should be __init__.py^)
    echo [WARN] tests\_init_.py exists, It should actually be __init__.py >> "%REPORT_FILE%" 2>&1
    echo [WARN] It needs to be with two underscores, not one. >> "%REPORT_FILE%" 2>&1
    echo [WARN] Please rename the tests\_init_.py file to __init__.py >> "%REPORT_FILE%" 2>&1
)

:: Enhancement 4 & 5: Summary & Action Required
(
    echo.
    echo ==================================================
    echo [SUMMARY]
    echo System requirements: %SUMMARY_SYS%
    echo Privileges: %SUMMARY_PRIV%
    echo PowerShell 7: %SUMMARY_PWSH%
    echo Python: %SUMMARY_PY%
    echo Dependencies: %SUMMARY_DEPS%
    echo Project integrity: %SUMMARY_INTEGRITY%
    echo.
    echo Likely cause of failure:
    if "%SUMMARY_PWSH%" neq "OK" echo - Critical: PowerShell 7 is missing.
    if "%SUMMARY_PY%" neq "OK" echo - Critical: Python Environment issue.
    if "%SUMMARY_DEPS%" neq "OK" echo - Critical: Missing Dependencies.
    if "%SUMMARY_INTEGRITY%" neq "OK" echo - Critical: Corrupt installation (Missing files).
    if "%SUMMARY_PWSH%"=="OK" if "%SUMMARY_PY%"=="OK" if "%SUMMARY_DEPS%"=="OK" if "%SUMMARY_INTEGRITY%"=="OK" (
        echo - Application logic error (Check logs)
        echo - Configuration (.env) issue
    )
    echo.
    echo [ACTION REQUIRED]
    echo When reporting an issue:
    echo - Attach this file to your GitHub issue
    echo - Do not paste screenshots of errors
    echo - Do not omit any sections
    echo ==================================================
) >> "%REPORT_FILE%" 2>&1

:: Finalize
title IntentShell - Debug Service (Completed)
echo. >> "%REPORT_FILE%"
echo [KERNEL MODE] >> "%REPORT_FILE%"
echo [DISABLED] Kernel mode is intentionally locked >> "%REPORT_FILE%"
echo [SECURITY DESIGN] Kernel mode is disabled by architectural decision, not by environment limitation. >> "%REPORT_FILE%"
echo [INFO] No kernel drivers are loaded >> "%REPORT_FILE%"
echo [INFO] No kernel entry points are reachable >> "%REPORT_FILE%"
echo. >> "%REPORT_FILE%"
echo END OF REPORT >> "%REPORT_FILE%"
echo ================================================== >> "%REPORT_FILE%"

echo.
echo [DONE] Report saved to:
echo %CD%\%REPORT_FILE%
echo.
echo Please attach this report when opening an issue on GitHub.
echo.
pause
