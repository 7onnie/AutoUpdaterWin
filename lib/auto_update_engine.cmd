@echo off
REM ============================================================================
REM AutoUpdaterWin - Update Engine
REM ============================================================================
REM This is the main update engine loaded by the bootstrap
REM Handles version checking, downloading, and self-replacement
REM ============================================================================

REM Entry point - called from bootstrap
goto :eof

REM ============================================================================
REM Main Auto-Update Logic
REM ============================================================================
:_auto_update_main
    setlocal EnableDelayedExpansion

    REM Validate required variables
    if not defined SCRIPT_VERSION (
        echo [AutoUpdate] ERROR: SCRIPT_VERSION not set
        exit /b 1
    )

    if not defined UPDATE_MODE (
        echo [AutoUpdate] ERROR: UPDATE_MODE not set
        exit /b 1
    )

    REM Default to github_release mode
    if "%UPDATE_MODE%"=="github_release" (
        call :_update_github_release
        exit /b %ERRORLEVEL%
    )

    if "%UPDATE_MODE%"=="direct_url" (
        call :_update_direct_url
        exit /b %ERRORLEVEL%
    )

    if "%UPDATE_MODE%"=="archive" (
        call :_update_archive
        exit /b %ERRORLEVEL%
    )

    echo [AutoUpdate] ERROR: Unknown UPDATE_MODE: %UPDATE_MODE%
    exit /b 1

REM ============================================================================
REM GitHub Release Update Mode
REM ============================================================================
:_update_github_release
    REM Validate GitHub variables
    if not defined GITHUB_USER (
        echo [AutoUpdate] ERROR: GITHUB_USER not set
        exit /b 1
    )

    if not defined GITHUB_REPO (
        echo [AutoUpdate] ERROR: GITHUB_REPO not set
        exit /b 1
    )

    echo [AutoUpdate] Checking for updates...
    echo [AutoUpdate] Current version: %SCRIPT_VERSION%
    echo [AutoUpdate] Repository: %GITHUB_USER%/%GITHUB_REPO%

    REM Get latest release info using PowerShell helper
    set HELPERS_URL=https://raw.githubusercontent.com/7onnie/AutoUpdaterWin/main/lib/auto_update_helpers.ps1
    set HELPERS_FILE=%TEMP%\auto_update_helpers.ps1

    REM Download helpers if not cached
    if not exist "%HELPERS_FILE%" (
        curl -sSfL "%HELPERS_URL%" -o "%HELPERS_FILE%" >nul 2>&1
        if errorlevel 1 (
            powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri '%HELPERS_URL%' -OutFile '%HELPERS_FILE%' -UseBasicParsing" >nul 2>&1
        )
    )

    if not exist "%HELPERS_FILE%" (
        echo [AutoUpdate] ERROR: Failed to download PowerShell helpers
        exit /b 1
    )

    REM Call PowerShell to get latest release
    set RELEASE_INFO=%TEMP%\auto_update_release_%RANDOM%.txt

    if defined GITHUB_TOKEN (
        powershell -NoProfile -ExecutionPolicy Bypass -Command ". '%HELPERS_FILE%'; $release = Get-LatestRelease -User '%GITHUB_USER%' -Repo '%GITHUB_REPO%' -Token '%GITHUB_TOKEN%'; if ($release) { Write-Output \"VERSION=$($release.version)\"; Write-Output \"TAG=$($release.tag_name)\"; Write-Output \"URL=$($release.asset_url)\"; Write-Output \"NAME=$($release.asset_name)\" }" > "%RELEASE_INFO%" 2>nul
    ) else (
        powershell -NoProfile -ExecutionPolicy Bypass -Command ". '%HELPERS_FILE%'; $release = Get-LatestRelease -User '%GITHUB_USER%' -Repo '%GITHUB_REPO%'; if ($release) { Write-Output \"VERSION=$($release.version)\"; Write-Output \"TAG=$($release.tag_name)\"; Write-Output \"URL=$($release.asset_url)\"; Write-Output \"NAME=$($release.asset_name)\" }" > "%RELEASE_INFO%" 2>nul
    )

    REM Parse release info
    if not exist "%RELEASE_INFO%" (
        echo [AutoUpdate] ERROR: Failed to fetch release information
        exit /b 1
    )

    REM Read release info into variables
    for /f "tokens=1,* delims==" %%a in (%RELEASE_INFO%) do (
        if "%%a"=="VERSION" set LATEST_VERSION=%%b
        if "%%a"=="TAG" set LATEST_TAG=%%b
        if "%%a"=="URL" set ASSET_URL=%%b
        if "%%a"=="NAME" set ASSET_NAME=%%b
    )

    del "%RELEASE_INFO%" >nul 2>&1

    if not defined LATEST_VERSION (
        echo [AutoUpdate] ERROR: Could not determine latest version
        exit /b 1
    )

    echo [AutoUpdate] Latest version: %LATEST_VERSION%

    REM Compare versions using PowerShell
    powershell -NoProfile -ExecutionPolicy Bypass -Command ". '%HELPERS_FILE%'; $result = Compare-Versions -Version1 '%SCRIPT_VERSION%' -Version2 '%LATEST_VERSION%'; exit $result" >nul 2>&1
    set VERSION_COMPARE=%ERRORLEVEL%

    REM VERSION_COMPARE: -1 = current < latest, 0 = equal, 1 = current > latest
    REM PowerShell returns this as exit code (0 for equal, others as offset from 0)
    REM We need to interpret: if result is 255 (-1 in signed byte), current < latest

    if %VERSION_COMPARE% equ 0 (
        echo [AutoUpdate] Already up to date
        exit /b 0
    )

    REM If current version < latest version (ERRORLEVEL 255 means -1)
    if %VERSION_COMPARE% equ 255 (
        echo [AutoUpdate] Update available: %SCRIPT_VERSION% -^> %LATEST_VERSION%
        call :_download_and_replace "%ASSET_URL%" "%ASSET_NAME%"
        exit /b %ERRORLEVEL%
    )

    REM If we're on a newer version than latest release
    if %VERSION_COMPARE% equ 1 (
        echo [AutoUpdate] Current version (%SCRIPT_VERSION%) is newer than latest release (%LATEST_VERSION%)
        echo [AutoUpdate] No update needed
        exit /b 0
    )

    REM Fallback: assume we need update if versions don't match
    if not "%SCRIPT_VERSION%"=="%LATEST_VERSION%" (
        echo [AutoUpdate] Update available: %SCRIPT_VERSION% -^> %LATEST_VERSION%
        call :_download_and_replace "%ASSET_URL%" "%ASSET_NAME%"
        exit /b %ERRORLEVEL%
    )

    exit /b 0

REM ============================================================================
REM Download and Replace Current Script
REM ============================================================================
:_download_and_replace
    set DOWNLOAD_URL=%~1
    set DOWNLOAD_NAME=%~2

    echo [AutoUpdate] Downloading update...

    REM Determine current script path
    set CURRENT_SCRIPT=%~f0

    REM If we're running from cache, find the actual script
    REM The actual script is the one that contains SCRIPT_VERSION
    if "%CURRENT_SCRIPT%"=="%CACHE_FILE%" (
        REM We need to find the calling script
        REM This is tricky - we'll look for .cmd files in current directory
        for %%F in (*.cmd) do (
            findstr /C:"SCRIPT_VERSION" "%%F" >nul 2>&1
            if not errorlevel 1 (
                set CURRENT_SCRIPT=%%~fF
                goto :found_script
            )
        )
        for %%F in (*.bat) do (
            findstr /C:"SCRIPT_VERSION" "%%F" >nul 2>&1
            if not errorlevel 1 (
                set CURRENT_SCRIPT=%%~fF
                goto :found_script
            )
        )
    )

    :found_script
    echo [AutoUpdate] Target script: %CURRENT_SCRIPT%

    REM Create backup
    set BACKUP_FILE=%CURRENT_SCRIPT%.bak
    copy /Y "%CURRENT_SCRIPT%" "%BACKUP_FILE%" >nul 2>&1
    echo [AutoUpdate] Backup created: %BACKUP_FILE%

    REM Download new version to temp file
    set TEMP_DOWNLOAD=%TEMP%\auto_update_download_%RANDOM%.cmd

    if defined GITHUB_TOKEN (
        powershell -NoProfile -ExecutionPolicy Bypass -Command ". '%HELPERS_FILE%'; Download-FileWithAuth -Url '%DOWNLOAD_URL%' -OutFile '%TEMP_DOWNLOAD%' -Token '%GITHUB_TOKEN%'" >nul 2>&1
    ) else (
        curl -sSfL "%DOWNLOAD_URL%" -o "%TEMP_DOWNLOAD%" >nul 2>&1
        if errorlevel 1 (
            powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%TEMP_DOWNLOAD%' -UseBasicParsing" >nul 2>&1
        )
    )

    if not exist "%TEMP_DOWNLOAD%" (
        echo [AutoUpdate] ERROR: Download failed
        exit /b 1
    )

    echo [AutoUpdate] Download complete

    REM Preserve GitHub token in new version
    set TEMP_WITH_TOKEN=%TEMP%\auto_update_with_token_%RANDOM%.cmd

    powershell -NoProfile -ExecutionPolicy Bypass -Command ". '%HELPERS_FILE%'; $newContent = Get-Content '%TEMP_DOWNLOAD%' -Raw; $preserved = Preserve-GitHubToken -OldScriptPath '%CURRENT_SCRIPT%' -NewContent $newContent; Set-Content -Path '%TEMP_WITH_TOKEN%' -Value $preserved -NoNewline" >nul 2>&1

    if exist "%TEMP_WITH_TOKEN%" (
        move /Y "%TEMP_WITH_TOKEN%" "%TEMP_DOWNLOAD%" >nul 2>&1
    )

    REM Self-replace using indirection (Windows file locking workaround)
    call :_self_replace "%TEMP_DOWNLOAD%" "%CURRENT_SCRIPT%"

    exit /b %ERRORLEVEL%

REM ============================================================================
REM Self-Replace via Indirection
REM ============================================================================
REM Windows locks running .cmd files, so we create a temporary script that:
REM   1. Waits for current script to exit
REM   2. Replaces old script with new version
REM   3. Restarts the script
REM   4. Deletes itself
REM ============================================================================
:_self_replace
    set NEW_VERSION_FILE=%~1
    set TARGET_SCRIPT=%~2

    set REPLACE_SCRIPT=%TEMP%\auto_update_replace_%RANDOM%.cmd

    REM Create the replacement script
    (
        echo @echo off
        echo REM Auto-generated replacement script
        echo timeout /t 2 /nobreak ^>nul 2^>^&1
        echo copy /Y "%NEW_VERSION_FILE%" "%TARGET_SCRIPT%" ^>nul 2^>^&1
        echo if errorlevel 1 ^(
        echo     echo [AutoUpdate] ERROR: Failed to replace script
        echo     pause
        echo     exit /b 1
        echo ^)
        echo del "%NEW_VERSION_FILE%" ^>nul 2^>^&1
        echo echo [AutoUpdate] Update installed successfully!
        echo echo [AutoUpdate] Restarting script...
        echo timeout /t 1 /nobreak ^>nul 2^>^&1
        echo start "" "%TARGET_SCRIPT%"
        echo del "%%~f0" ^>nul 2^>^&1
        echo exit
    ) > "%REPLACE_SCRIPT%"

    echo [AutoUpdate] Installing update...
    echo [AutoUpdate] Script will restart automatically

    REM Start replacement script and exit current script
    start "" /min "%REPLACE_SCRIPT%"

    REM Exit current script to unlock the file
    exit

REM ============================================================================
REM Direct URL Update Mode
REM ============================================================================
:_update_direct_url
    if not defined UPDATE_URL (
        echo [AutoUpdate] ERROR: UPDATE_URL not set for direct_url mode
        exit /b 1
    )

    echo [AutoUpdate] Downloading from: %UPDATE_URL%
    call :_download_and_replace "%UPDATE_URL%" "script.cmd"
    exit /b %ERRORLEVEL%

REM ============================================================================
REM Archive Update Mode (DEP/ directory)
REM ============================================================================
:_update_archive
    echo [AutoUpdate] Archive mode not yet implemented
    exit /b 1

REM ============================================================================
REM End of Auto-Update Engine
REM ============================================================================
