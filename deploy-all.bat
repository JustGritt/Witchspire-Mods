@echo off
REM ============================================================================
REM  Deploy ALL Witchspire mods at once.
REM  Runs each mod's scripts\deploy.ps1 (auto-discovered, so new mods are
REM  picked up automatically) plus ReforgeGear's separate GodForge deploy.
REM  Double-click this file, or run it from a terminal.
REM ============================================================================

setlocal enabledelayedexpansion
cd /d "%~dp0"

set "FAILED="
set "COUNT=0"

REM --- Primary deploy for every mod folder ------------------------------------
for /d %%D in (*) do (
    if exist "%%D\scripts\deploy.ps1" (
        set /a COUNT+=1
        echo.
        echo === Deploying %%~nxD ===
        powershell -NoProfile -ExecutionPolicy Bypass -File "%%D\scripts\deploy.ps1"
        if errorlevel 1 set "FAILED=!FAILED! %%~nxD"
    )
)

REM --- ReforgeGear ships GodForge as a separate mod (installs alongside) -------
REM     Delete this block if you don't want GodForge (F8) deployed.
if exist "ReforgeGear\scripts\deploy-godforge.ps1" (
    set /a COUNT+=1
    echo.
    echo === Deploying ReforgeGear ^(GodForge^) ===
    powershell -NoProfile -ExecutionPolicy Bypass -File "ReforgeGear\scripts\deploy-godforge.ps1"
    if errorlevel 1 set "FAILED=!FAILED! ReforgeGear-GodForge"
)

REM --- Summary ----------------------------------------------------------------
echo.
echo ============================================================================
if defined FAILED (
    echo  Deployed !COUNT! mod^(s^), but the following FAILED:!FAILED!
) else (
    echo  All !COUNT! mod^(s^) deployed successfully.
)
echo ============================================================================
echo  Fully restart Witchspire so AngelScript recompiles the mods.
echo.
pause
