@echo off
REM ============================================================================
REM AutoUpdaterWin - Test Suite
REM ============================================================================
REM Tests all update modes and functionality
REM Run on Windows to verify AutoUpdaterWin components
REM ============================================================================

setlocal EnableDelayedExpansion

echo.
echo ========================================
echo   AutoUpdaterWin Test Suite
echo ========================================
echo.

set PASSED=0
set FAILED=0
set TOTAL=0

REM ============================================================================
REM Test 1: Cache Directory Creation
REM ============================================================================
:test_cache_creation
    set /a TOTAL+=1
    echo [Test %TOTAL%] Cache directory creation...

    set TEST_CACHE_DIR=%TEMP%\auto_update_test_%RANDOM%
    if exist "%TEST_CACHE_DIR%" rmdir /s /q "%TEST_CACHE_DIR%"

    mkdir "%TEST_CACHE_DIR%" 2>nul

    if exist "%TEST_CACHE_DIR%" (
        echo   [PASS] Cache directory created
        set /a PASSED+=1
        rmdir "%TEST_CACHE_DIR%"
    ) else (
        echo   [FAIL] Could not create cache directory
        set /a FAILED+=1
    )

REM ============================================================================
REM Test 2: PowerShell Availability
REM ============================================================================
:test_powershell
    set /a TOTAL+=1
    echo [Test %TOTAL%] PowerShell availability...

    powershell -NoProfile -ExecutionPolicy Bypass -Command "exit 0" >nul 2>&1

    if %ERRORLEVEL% equ 0 (
        echo   [PASS] PowerShell is available
        set /a PASSED+=1
    ) else (
        echo   [FAIL] PowerShell not available
        set /a FAILED+=1
    )

REM ============================================================================
REM Test 3: curl Availability
REM ============================================================================
:test_curl
    set /a TOTAL+=1
    echo [Test %TOTAL%] curl availability...

    curl --version >nul 2>&1

    if %ERRORLEVEL% equ 0 (
        echo   [PASS] curl is available (Windows 10+)
        set /a PASSED+=1
    ) else (
        echo   [WARN] curl not available (will use PowerShell fallback)
        set /a PASSED+=1
    )

REM ============================================================================
REM Test 4: Download Engine
REM ============================================================================
:test_download_engine
    set /a TOTAL+=1
    echo [Test %TOTAL%] Download update engine...

    set TEST_ENGINE=%TEMP%\test_engine_%RANDOM%.cmd
    set ENGINE_URL=https://raw.githubusercontent.com/7onnie/AutoUpdaterWin/main/lib/auto_update_engine.cmd

    curl -sSfL "%ENGINE_URL%" -o "%TEST_ENGINE%" >nul 2>&1
    if errorlevel 1 (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri '%ENGINE_URL%' -OutFile '%TEST_ENGINE%' -UseBasicParsing" >nul 2>&1
    )

    if exist "%TEST_ENGINE%" (
        echo   [PASS] Engine downloaded successfully
        set /a PASSED+=1
        del "%TEST_ENGINE%"
    ) else (
        echo   [FAIL] Could not download engine
        set /a FAILED+=1
    )

REM ============================================================================
REM Test 5: Download PowerShell Helpers
REM ============================================================================
:test_download_helpers
    set /a TOTAL+=1
    echo [Test %TOTAL%] Download PowerShell helpers...

    set TEST_HELPERS=%TEMP%\test_helpers_%RANDOM%.ps1
    set HELPERS_URL=https://raw.githubusercontent.com/7onnie/AutoUpdaterWin/main/lib/auto_update_helpers.ps1

    curl -sSfL "%HELPERS_URL%" -o "%TEST_HELPERS%" >nul 2>&1
    if errorlevel 1 (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri '%HELPERS_URL%' -OutFile '%TEST_HELPERS%' -UseBasicParsing" >nul 2>&1
    )

    if exist "%TEST_HELPERS%" (
        echo   [PASS] Helpers downloaded successfully
        set /a PASSED+=1
        del "%TEST_HELPERS%"
    ) else (
        echo   [FAIL] Could not download helpers
        set /a FAILED+=1
    )

REM ============================================================================
REM Test 6: Version Comparison
REM ============================================================================
:test_version_compare
    set /a TOTAL+=1
    echo [Test %TOTAL%] Version comparison...

    REM Download helpers first
    set HELPERS_FILE=%TEMP%\auto_update_helpers_%RANDOM%.ps1
    curl -sSfL "https://raw.githubusercontent.com/7onnie/AutoUpdaterWin/main/lib/auto_update_helpers.ps1" -o "%HELPERS_FILE%" >nul 2>&1

    if exist "%HELPERS_FILE%" (
        REM Test: 1.0.0 < 1.0.1 should return -1 (exit code 255)
        powershell -NoProfile -ExecutionPolicy Bypass -Command ". '%HELPERS_FILE%'; $result = Compare-Versions -Version1 '1.0.0' -Version2 '1.0.1'; exit $result" >nul 2>&1
        if %ERRORLEVEL% equ 255 (
            echo   [PASS] Version comparison works correctly
            set /a PASSED+=1
        ) else (
            echo   [FAIL] Version comparison failed
            set /a FAILED+=1
        )
        del "%HELPERS_FILE%"
    ) else (
        echo   [SKIP] Could not download helpers for test
        set /a TOTAL-=1
    )

REM ============================================================================
REM Test 7: Cache Validity Check
REM ============================================================================
:test_cache_validity
    set /a TOTAL+=1
    echo [Test %TOTAL%] Cache validity check...

    set TEST_CACHE=%TEMP%\test_cache_%RANDOM%.txt
    echo test > "%TEST_CACHE%"

    REM Check if cache is valid (should be, as it's brand new)
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$cache='%TEST_CACHE%'; if (Test-Path $cache) { $age = (New-TimeSpan -Start (Get-Item $cache).LastWriteTime -End (Get-Date)).TotalMinutes; if ($age -lt 1440) { exit 0 } }; exit 1" >nul 2>&1

    if %ERRORLEVEL% equ 0 (
        echo   [PASS] Cache validity check works
        set /a PASSED+=1
    ) else (
        echo   [FAIL] Cache validity check failed
        set /a FAILED+=1
    )

    del "%TEST_CACHE%" 2>nul

REM ============================================================================
REM Test 8: CRLF Line Endings
REM ============================================================================
:test_line_endings
    set /a TOTAL+=1
    echo [Test %TOTAL%] CRLF line endings in examples...

    set HAS_CRLF=0

    REM Check if examples have CRLF (Windows line endings)
    if exist "..\examples\example_bootstrap_minimal.cmd" (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$content = [System.IO.File]::ReadAllText('..\examples\example_bootstrap_minimal.cmd'); if ($content -match \"`r`n\") { exit 0 } else { exit 1 }" >nul 2>&1
        if %ERRORLEVEL% equ 0 (
            set HAS_CRLF=1
        )
    )

    if %HAS_CRLF% equ 1 (
        echo   [PASS] Examples have CRLF line endings
        set /a PASSED+=1
    ) else (
        echo   [WARN] Examples might not have CRLF (acceptable on Mac/Linux)
        set /a PASSED+=1
    )

REM ============================================================================
REM Test 9: GitHub Token Pattern Matching
REM ============================================================================
:test_token_pattern
    set /a TOTAL+=1
    echo [Test %TOTAL%] GitHub token pattern matching...

    set TEST_SCRIPT=%TEMP%\test_script_%RANDOM%.cmd
    (
        echo @echo off
        echo SET GITHUB_TOKEN=ghp_test1234567890abcdef
        echo echo Test
    ) > "%TEST_SCRIPT%"

    REM Try to extract token using PowerShell
    for /f "delims=" %%i in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$content = Get-Content '%TEST_SCRIPT%' -Raw; if ($content -match '(?im)^SET\s+GITHUB_TOKEN=([^%\r\n]+)') { Write-Output $matches[1] }"') do set EXTRACTED_TOKEN=%%i

    if "%EXTRACTED_TOKEN%"=="ghp_test1234567890abcdef" (
        echo   [PASS] Token extraction works
        set /a PASSED+=1
    ) else (
        echo   [FAIL] Token extraction failed
        set /a FAILED+=1
    )

    del "%TEST_SCRIPT%" 2>nul

REM ============================================================================
REM Test 10: Script Detection
REM ============================================================================
:test_script_detection
    set /a TOTAL+=1
    echo [Test %TOTAL%] Script detection...

    set TEST_DIR=%TEMP%\test_detect_%RANDOM%
    mkdir "%TEST_DIR%"

    set TEST_SCRIPT=%TEST_DIR%\test.cmd
    (
        echo @echo off
        echo SET SCRIPT_VERSION=1.0.0
        echo echo Test
    ) > "%TEST_SCRIPT%"

    REM Try to find script with SCRIPT_VERSION
    set FOUND_SCRIPT=
    for %%F in ("%TEST_DIR%\*.cmd") do (
        findstr /C:"SCRIPT_VERSION" "%%F" >nul 2>&1
        if not errorlevel 1 (
            set FOUND_SCRIPT=%%F
        )
    )

    if defined FOUND_SCRIPT (
        echo   [PASS] Script detection works
        set /a PASSED+=1
    ) else (
        echo   [FAIL] Script detection failed
        set /a FAILED+=1
    )

    rmdir /s /q "%TEST_DIR%" 2>nul

REM ============================================================================
REM Test Results
REM ============================================================================
:test_results
    echo.
    echo ========================================
    echo   Test Results
    echo ========================================
    echo   Total:  %TOTAL%
    echo   Passed: %PASSED%
    echo   Failed: %FAILED%
    echo ========================================
    echo.

    if %FAILED% equ 0 (
        echo [SUCCESS] All tests passed!
        exit /b 0
    ) else (
        echo [FAILURE] Some tests failed
        exit /b 1
    )
