@echo off
REM ============================================================================
REM AutoUpdaterWin - Bootstrap Minimal
REM ============================================================================
REM Embed this code in your script to enable auto-updates from GitHub
REM
REM Usage:
REM   1. Set SCRIPT_VERSION=1.0.0
REM   2. Set UPDATE_MODE=github_release
REM   3. Set GITHUB_USER=YourUsername
REM   4. Set GITHUB_REPO=YourRepoName
REM   5. call :auto_update
REM
REM For private repos:
REM   SET GITHUB_TOKEN=ghp_your_token_here
REM
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
REM End of Bootstrap Minimal
REM ============================================================================
