@echo off
REM ============================================================================
REM Example: GitHub Release Mode
REM ============================================================================
REM This example demonstrates using GitHub releases for auto-updates
REM
REM How it works:
REM   1. Script checks GitHub for latest release
REM   2. Compares current version with latest
REM   3. If newer version available, downloads and replaces itself
REM   4. Restarts with new version
REM
REM Setup:
REM   1. Create a GitHub repository
REM   2. Set GITHUB_USER and GITHUB_REPO below
REM   3. Push this script to the repository
REM   4. Use GitHub Actions to create releases (see workflow in templates/)
REM
REM ============================================================================

REM === Configuration ===
SET SCRIPT_VERSION=1.2.0
SET UPDATE_MODE=github_release
SET GITHUB_USER=YourUsername
SET GITHUB_REPO=YourRepoName
REM For private repos, uncomment and set token:
REM SET GITHUB_TOKEN=ghp_xxxxxxxxxxxxx

REM === Auto-Update Bootstrap ===
call :auto_update

REM === Script Logic ===
echo.
echo ============================================
echo   GitHub Release Mode Example
echo ============================================
echo   Version: %SCRIPT_VERSION%
echo   Repository: %GITHUB_USER%/%GITHUB_REPO%
echo   Update Mode: %UPDATE_MODE%
echo ============================================
echo.

REM Your actual script functionality here
echo This script uses GitHub releases for updates.
echo.
echo Version history:
echo   - v1.0.0: Initial release
echo   - v1.1.0: Added feature X
echo   - v1.2.0: Current version (improved feature Y)
echo.
echo When you push a new version to GitHub:
echo   1. GitHub Action creates a release automatically
echo   2. Next run detects the new version
echo   3. Script downloads and replaces itself
echo   4. Restarts with the new version
echo.

REM Example: Do something useful
echo Running main functionality...
timeout /t 2 /nobreak >nul
echo Done!
echo.

exit /b 0

REM ============================================================================
REM Auto-Update Bootstrap
REM ============================================================================

:auto_update
    set ENGINE_URL=https://raw.githubusercontent.com/7onnie/AutoUpdaterWin/main/lib/auto_update_engine.cmd
    set CACHE_DIR=%TEMP%\auto_update_cache
    set CACHE_FILE=%CACHE_DIR%\engine.cmd
    set CACHE_LIFETIME_MIN=1440

    if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%"

    if exist "%CACHE_FILE%" (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$cache='%CACHE_FILE%'; if (Test-Path $cache) { $age = (New-TimeSpan -Start (Get-Item $cache).LastWriteTime -End (Get-Date)).TotalMinutes; if ($age -lt %CACHE_LIFETIME_MIN%) { exit 0 } }; exit 1" >nul 2>&1
        if %ERRORLEVEL% equ 0 (
            call "%CACHE_FILE%"
            if not errorlevel 1 (
                call :_auto_update_main
                exit /b %ERRORLEVEL%
            )
        )
    )

    echo [AutoUpdate] Downloading update engine...
    curl -sSfL "%ENGINE_URL%" -o "%CACHE_FILE%" >nul 2>&1
    if errorlevel 1 (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri '%ENGINE_URL%' -OutFile '%CACHE_FILE%' -UseBasicParsing" >nul 2>&1
    )

    if exist "%CACHE_FILE%" (
        echo [AutoUpdate] Engine loaded successfully
        call "%CACHE_FILE%"
        if not errorlevel 1 (
            call :_auto_update_main
        )
    ) else (
        echo [AutoUpdate] WARNING: Failed to download update engine
    )

    exit /b 0
