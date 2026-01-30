@echo off
REM ============================================================================
REM Example: Bootstrap Minimal Usage
REM ============================================================================
REM This example shows how to use the minimal bootstrap in your script
REM
REM To use this script:
REM   1. Copy this file to your repository
REM   2. Update GITHUB_USER and GITHUB_REPO
REM   3. Set SCRIPT_VERSION to your version
REM   4. Push to GitHub and let the Action create releases
REM
REM ============================================================================

REM === Configuration ===
SET SCRIPT_VERSION=1.0.0
SET UPDATE_MODE=github_release
SET GITHUB_USER=YourUsername
SET GITHUB_REPO=YourRepoName
REM SET GITHUB_TOKEN=ghp_xxxxxxxxxxxxx

REM === Auto-Update Bootstrap ===
call :auto_update

REM === Your Script Logic Starts Here ===
echo.
echo ========================================
echo   Example Script with Auto-Update
echo ========================================
echo   Version: %SCRIPT_VERSION%
echo   User:    %GITHUB_USER%
echo   Repo:    %GITHUB_REPO%
echo ========================================
echo.
echo This script automatically updates itself from GitHub releases!
echo.
echo When you push a new version to GitHub:
echo   1. GitHub Action creates a release
echo   2. Next run checks for updates
echo   3. Script downloads and replaces itself
echo   4. Restarts with new version
echo.

REM Example: Your actual script functionality
echo Running script functionality...
echo Hello from version %SCRIPT_VERSION%!
echo.

exit /b 0

REM ============================================================================
REM Auto-Update Bootstrap Minimal
REM ============================================================================
REM Copy everything below this line into your script
REM ============================================================================

:auto_update
    REM Configuration
    set ENGINE_URL=https://raw.githubusercontent.com/7onnie/AutoUpdaterWin/main/lib/auto_update_engine.cmd
    set CACHE_DIR=%TEMP%\auto_update_cache
    set CACHE_FILE=%CACHE_DIR%\engine.cmd
    set CACHE_LIFETIME_MIN=1440

    REM Create cache directory if needed
    if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%"

    REM Check if cache is valid (using PowerShell for date math)
    if exist "%CACHE_FILE%" (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$cache='%CACHE_FILE%'; if (Test-Path $cache) { $age = (New-TimeSpan -Start (Get-Item $cache).LastWriteTime -End (Get-Date)).TotalMinutes; if ($age -lt %CACHE_LIFETIME_MIN%) { exit 0 } }; exit 1" >nul 2>&1
        if %ERRORLEVEL% equ 0 (
            REM Cache is valid, use it
            call "%CACHE_FILE%"
            if not errorlevel 1 (
                call :_auto_update_main
                exit /b %ERRORLEVEL%
            )
        )
    )

    REM Cache invalid or doesn't exist - download engine
    echo [AutoUpdate] Downloading update engine...

    REM Try curl first (Windows 10+)
    curl -sSfL "%ENGINE_URL%" -o "%CACHE_FILE%" >nul 2>&1

    REM If curl failed, try PowerShell (Windows 7+)
    if errorlevel 1 (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -Uri '%ENGINE_URL%' -OutFile '%CACHE_FILE%' -UseBasicParsing; exit 0 } catch { exit 1 }" >nul 2>&1
    )

    REM Check if download succeeded
    if exist "%CACHE_FILE%" (
        echo [AutoUpdate] Engine loaded successfully
        call "%CACHE_FILE%"
        if not errorlevel 1 (
            call :_auto_update_main
            exit /b %ERRORLEVEL%
        )
    ) else (
        echo [AutoUpdate] WARNING: Failed to download update engine
        echo [AutoUpdate] Script will run without auto-update capability
    )

    exit /b 0

REM ============================================================================
REM End of Auto-Update Bootstrap
REM ============================================================================
