@echo off
setlocal EnableDelayedExpansion
title IntentShell Overlay

cd /d "%~dp0" 2>nul

if /I "%1"=="/bypass" (
    echo Skip IntentShell installation checks.
    echo This could cause IntentShell to malfunction.
    pause
    goto :CONFIG_CHECK
)

:: Administrator check
net session >nul 2>&1
if %errorlevel% == 0 (
    echo [INFO] Running as Administrator.
    goto :admin_ok
) else (
    echo [INFO] Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:admin_ok
echo [INFO] Administrator privileges granted.

:: PowerShell 7 check
echo [INFO] Checking for PowerShell 7...
pwsh -NoProfile -Command "exit" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [INFO] PowerShell 7 is already installed.
    goto :PS7_READY
)

echo [INFO] PowerShell 7 not found.
echo.
echo [SETUP] Install PowerShell 7 now? (Y/N)
set "choice="
set /p "choice=Your choice (Y/N): "

if /i "!choice!"=="Y"   goto :INSTALL_PS7
if /i "!choice!"=="YES" goto :INSTALL_PS7
if /i "!choice!"=="y"   goto :INSTALL_PS7
if /i "!choice!"=="yes" goto :INSTALL_PS7
if /i "!choice!"=="yep" goto :INSTALL_PS7
if /i "!choice!"=="yeah" goto :INSTALL_PS7

echo [ERROR] PowerShell 7 is required for this application to function properly.
echo Installation cancelled.
pause
exit /b 1

:INSTALL_PS7
title IntentShell - PowerShell 7 Setup Wizard
echo.
echo [SETUP] Downloading and installing latest PowerShell 7...
echo [SETUP] This may take a few minutes...

powershell -NoProfile -Command ^
    "$ErrorActionPreference = 'Stop'; " ^
    "Write-Host '[SETUP] Finding latest PowerShell release...' -ForegroundColor Cyan; " ^
    "try { " ^
    "    $latest = (Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest').tag_name; " ^
    "    $version = $latest.TrimStart('v'); " ^
    "    $url = \"https://github.com/PowerShell/PowerShell/releases/download/$latest/PowerShell-$version-win-x64.msi\"; " ^
    "    Write-Host \"[DOWNLOAD] $url\" -ForegroundColor Yellow; " ^
    "    Invoke-WebRequest -Uri $url -OutFile \"$env:TEMP\PowerShell-latest-x64.msi\" -UseBasicParsing; " ^
    "    Write-Host '[SETUP] Download complete. Installing...' -ForegroundColor Green; " ^
    "    Start-Process msiexec.exe -ArgumentList '/i', \"`\"$env:TEMP\PowerShell-latest-x64.msi`\"\", '/quiet', '/norestart' -Wait -NoNewWindow; " ^
    "    Write-Host '[SETUP] PowerShell 7 installation finished.' -ForegroundColor Green; " ^
    "    Remove-Item \"$env:TEMP\PowerShell-latest-x64.msi\" -Force -EA SilentlyContinue; " ^
    "} catch { " ^
    "    Write-Host '[ERROR] Installation failed!' -ForegroundColor Red; " ^
    "    Write-Host $_.Exception.Message -ForegroundColor Red; " ^
    "    pause; " ^
    "}"

echo.
echo [INFO] PowerShell 7 check/install completed.
echo.

:PS7_READY

rem :: UTF-8 support
rem chcp 65001 >nul

:: Set PYTHONPATH
set "PYTHONPATH=%CD%"

:: Load preferences if exists
if exist "Preferences.bat" (
    call Preferences.bat
)

:: Python check
echo [INFO] Checking Python...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARNING] Python not found or not in PATH.
    goto :ASK_PYTHON
)

python -c "import sys; print(sys.version_info[1])" > "%TEMP%\pyver.txt" 2>nul
set "py_minor="
if exist "%TEMP%\pyver.txt" (
    set /p py_minor=<"%TEMP%\pyver.txt"
    del "%TEMP%\pyver.txt" 2>nul
)
if !py_minor! GEQ 10 (
    echo Python 3.!py_minor! ^(detected and approved^)
    goto :CHECK_DEPS
)

echo [WARNING] Python version is too old (3.!py_minor!).
goto :ASK_PYTHON

:ASK_PYTHON
echo.
set "py_choice="
set /p "py_choice=Install latest Python now? (Y/N): "

if /i "!py_choice!"=="Y"   goto :INSTALL_PYTHON
if /i "!py_choice!"=="YES" goto :INSTALL_PYTHON
if /i "!py_choice!"=="y"   goto :INSTALL_PYTHON
if /i "!py_choice!"=="yes" goto :INSTALL_PYTHON
if /i "!py_choice!"=="yep" goto :INSTALL_PYTHON
if /i "!py_choice!"=="yeah" goto :INSTALL_PYTHON

echo [ERROR] Python 3.10+ is required for this application.
pause
exit /b 1

:INSTALL_PYTHON
title IntentShell - Python Setup Wizard
echo.
echo [SETUP] Detecting and installing latest Python version...

powershell -NoProfile -Command ^
    "$ErrorActionPreference = 'Stop'; " ^
    "Write-Host '[SETUP] Searching for latest Python version...' -ForegroundColor Cyan; " ^
    "try { " ^
    "    $html = Invoke-WebRequest -Uri 'https://www.python.org/downloads/' -UseBasicParsing; " ^
    "    if ($html.Content -match 'Download Python ([\d\.]+)') { $ver = $Matches[1] } " ^
    "    else { $ver = '3.12.8' } " ^
    "    $url = \"https://www.python.org/ftp/python/$ver/python-$ver-amd64.exe\"; " ^
    "    Write-Host \"[DOWNLOAD] Python $ver\" -ForegroundColor Yellow; " ^
    "    Invoke-WebRequest -Uri $url -OutFile \"$env:TEMP\python-latest.exe\"; " ^
    "    Write-Host '[SETUP] Installing (silent, add to PATH)...' -ForegroundColor Green; " ^
    "    Start-Process -FilePath \"$env:TEMP\python-latest.exe\" -ArgumentList '/quiet','InstallAllUsers=1','PrependPath=1','Include_launcher=1','Include_test=0' -Wait -NoNewWindow; " ^
    "    Remove-Item \"$env:TEMP\python-latest.exe\" -Force -EA SilentlyContinue; " ^
    "    Write-Host '[SETUP] Python installation completed.' -ForegroundColor Green; " ^
    "} catch { " ^
    "    Write-Host '[ERROR]' $_.Exception.Message -ForegroundColor Red; " ^
    "    Write-Host 'Please download manually: https://www.python.org/downloads/' -ForegroundColor Yellow; " ^
    "    pause; " ^
    "}"

timeout /t 6 >nul

python --version >nul 2>&1 || (
    echo [WARNING] Python still not detected in PATH.
    echo Please close and re-open this batch file after installation.
    timeout /t 4 >nul
)

:CHECK_DEPS

echo.
echo [INFO] Checking requirements.txt packages...

if not exist "requirements.txt" (
    echo [ERROR] requirements.txt not found in current directory!
    pause
    exit /b 1
)

:: Simplified Dependency Check - Reliable and Safe
:: Instead of complex parsing, we rely on pip's built-in check or just sync
echo [INFO] Ensuring dependencies are up to date...
echo [INFO] This might take a moment if updates are needed.

python -m pip install -r requirements.txt --upgrade --quiet >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARNING] Automatic dependency check failed or needs permission.
    echo [INFO] Attempting verbose install...
    python -m pip install -r requirements.txt --upgrade
    if %errorlevel% neq 0 (
         echo [ERROR] Failed to install dependencies.
         echo Please check your internet connection.
         pause
         exit /b 1
    )
)
echo [INFO] Dependencies are ready.
:CONFIG_CHECK
if not exist ".env" (
    echo [INFO] .env file not found. Starting configuration...
    python configure.py
    if errorlevel 1 (
        echo [ERROR] Configuration failed.
        pause
        exit /b 1
    )
)

title IntentShell Overlay
echo.
echo [INFO] Starting IntentShell Overlay...
echo [INFO] Loading Phase 10 Modules...
echo [INFO] Initializing NLU Engine...

echo.
echo [INFO] Running: python ui\overlay.py
python ui\overlay.py

if errorlevel 1 (
    echo.
    echo [ERROR] overlay.py exited with error code %errorlevel%
    echo Possible reasons:
    echo   - Missing dependencies
    echo   - Syntax error in overlay.py
    echo   - .env file problem
    echo   - GPU/Driver issue (if using torch etc.)
    echo   --- SUGGESTION: Try Starting Application with Start-IntentShell-CLI.bat
    echo   --- If overlay.py is corrupted, the application should still work when started with the Start-IntentShell-CLI.bat file.
    echo   --- If it still doesn't work, check the possible causes listed above. If it still doesn't work, take a screenshot of the error message and report it via GitHub.
    echo.
    echo Press any key to see more details...
    pause
    :: Hata detayını görmek için tekrar çalıştırmayı dene
    python ui\overlay.py
    pause
) else (
    echo [INFO] overlay.py finished normally.
)

endlocal
exit /b 0