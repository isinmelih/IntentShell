@echo off
setlocal
title IntentShell Settings
cd /d "%~dp0"
chcp 65001 >nul

:menu
cls
echo ===================================================
echo             IntentShell Settings
echo ===================================================
echo.
echo  1. Reset Memory (Wipe DNA And History)
echo  2. Enable Flow Mode (Auto-Start) [COMING SOON]
echo  3. Disable Flow Mode [COMING SOON]
echo  4. Reset User Macros (config\user_macros.ini)
echo  5. Toggle Developer Diagnostics (On/Off)
echo  6. Toggle Learning Freeze Mode (On/Off)
echo  7. Change Hotkey
echo  8. Exit

echo ===================================================
set /p choice="Select an option (1-8): "

if "%choice%"=="1" goto :reset_memory
if "%choice%"=="2" goto :enable_flow
if "%choice%"=="3" goto :disable_flow
if "%choice%"=="4" goto :reset_macros
if "%choice%"=="5" goto :toggle_dev_mode
if "%choice%"=="6" goto :toggle_freeze_mode
if "%choice%"=="7" goto :change_hotkey
if "%choice%"=="8" goto :exit

goto :menu

:change_hotkey
cls
python core/set_hotkey.py
pause
goto :menu

:toggle_freeze_mode
cls
python core/config_manager.py toggle LearningFreeze enabled
pause
goto :menu

:toggle_dev_mode
cls
python core/config_manager.py toggle Developer enabled
pause
goto :menu

:reset_memory
cls
echo [WARNING] This will wipe all user memory, trust scores, and history.
echo Are you sure?
set /p confirm="Type 'YES' to confirm: "
if /i not "%confirm%"=="YES" goto :menu

echo.
echo Wiping Memory...
echo ---------------------------------------------------

:: Reset user_profile.json
echo {"trust_level": 0.0, "command_history": []} > config\user_profile.json
echo #Cache Cleared > cache\intent_cache.json
echo [OK] User Profile Reset.


:: Clear PowerShell Global History (if any persistent file exists)
:: Currently IntentShell stores session memory in memory, not in persistent files.

echo ---------------------------------------------------
echo Memory Reset Complete. IntentShell is now fresh.
pause
goto :menu

:enable_flow
cls
echo Enabling Flow Mode...
:: Check if variable already exists
findstr "set INTENTSHELL_FLOW_MODE=1" Preferences.bat >nul
if %errorlevel% equ 0 (
    echo [INFO] Flow Mode is already enabled.
) else (
    :: Remove disable line if exists
    type Preferences.bat | findstr /v "INTENTSHELL_FLOW_MODE" > Preferences.tmp
    move /y Preferences.tmp Preferences.bat >nul
    echo. >> Preferences.bat
    echo :: Flow Mode Auto-Start >> Preferences.bat
    echo set INTENTSHELL_FLOW_MODE=1 >> Preferences.bat
    echo [OK] Flow Mode Enabled.
)
pause
goto :menu

:disable_flow
cls
echo Disabling Flow Mode...
type Preferences.bat | findstr /v "INTENTSHELL_FLOW_MODE" > Preferences.tmp
move /y Preferences.tmp Preferences.bat >nul
echo [OK] Flow Mode Disabled.
pause
goto :menu

:reset_macros
cls
echo [WARNING] This will wipe all user macros.
echo Are you sure?
set /p confirm="Type 'YES' to confirm: "
if /i not "%confirm%"=="YES" goto :menu

echo.
echo Wiping Macros...
echo ---------------------------------------------------

:: Reset user_macros.ini
echo #Macros Cleared By User via Settings.bat > config\user_macros.ini
echo [OK] Macro Reset.

echo ---------------------------------------------------
echo Macro Reset Complete!
pause
goto :menu

:exit
endlocal
exit /b
