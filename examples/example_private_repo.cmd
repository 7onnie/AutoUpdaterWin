@echo off
REM ============================================================================
REM Example: Private Repository with Token
REM ============================================================================
REM This example shows how to use auto-updates with private GitHub repositories
REM
REM Requirements:
REM   - GitHub Personal Access Token with 'repo' scope
REM   - Private repository on GitHub
REM
REM Token Creation:
REM   1. Go to: https://github.com/settings/tokens
REM   2. Click "Generate new token (classic)"
REM   3. Select scope: repo (Full control of private repositories)
REM   4. Copy token (ghp_xxxxxxxxxxxxx)
REM   5. Add it to SET GITHUB_TOKEN= below
REM
REM Security:
REM   - Token is preserved during updates (not overwritten)
REM   - Token grants access to private repository releases
REM   - Keep token secure, don't commit to public repos
REM
REM ============================================================================

REM === Configuration ===
SET SCRIPT_VERSION=1.0.0
SET UPDATE_MODE=github_release
SET GITHUB_USER=YourUsername
SET GITHUB_REPO=YourPrivateRepo
SET GITHUB_TOKEN=ghp_your_token_here_replace_this

REM === Auto-Update Bootstrap ===
call :auto_update

REM === Script Logic ===
echo.
echo ============================================
echo   Private Repository Example
echo ============================================
echo   Version: %SCRIPT_VERSION%
echo   Repository: %GITHUB_USER%/%GITHUB_REPO% (PRIVATE)
echo   Token: %GITHUB_TOKEN:~0,7%********** (preserved)
echo ============================================
echo.

echo This script demonstrates auto-updates from a PRIVATE repository.
echo.
echo Key features:
echo   - Uses GitHub Personal Access Token for authentication
echo   - Token is automatically preserved during updates
echo   - Works with private repositories
echo   - Secure token handling
echo.

REM Example: Private script functionality
echo Running private script logic...
echo This could be proprietary code, internal tools, etc.
echo.

REM Demonstrate token preservation
echo Token preservation test:
echo   Current token (first 10 chars): %GITHUB_TOKEN:~0,10%...
echo   This token will be preserved when script updates itself
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

REM ============================================================================
REM Token Security Notes
REM ============================================================================
REM
REM The GITHUB_TOKEN is automatically preserved during updates:
REM
REM 1. When update is available:
REM    - New version is downloaded from GitHub
REM    - PowerShell helper extracts token from current script
REM    - Token is injected into new version
REM    - Old script is replaced with new version (with token)
REM
REM 2. Pattern matching:
REM    - Matches: SET GITHUB_TOKEN=value
REM    - Matches: SET GITHUB_TOKEN="value"
REM    - Validates: Token starts with ghp_, github_pat_, etc.
REM
REM 3. Security:
REM    - Token never leaves local machine
REM    - Not sent to any server (except GitHub API)
REM    - Preserved across all updates
REM
REM ============================================================================
