# Windows-Specific Implementation Details

AutoUpdaterWin is specifically designed for Windows CMD/Batch scripts with considerations for Windows-specific challenges.

## Table of Contents

1. [File Locking and Self-Replace](#file-locking-and-self-replace)
2. [Line Endings (CRLF vs LF)](#line-endings-crlf-vs-lf)
3. [PowerShell Integration](#powershell-integration)
4. [Variable Syntax](#variable-syntax)
5. [Function Calls vs Source](#function-calls-vs-source)
6. [Cache Location](#cache-location)
7. [Download Methods](#download-methods)
8. [Execution Policy](#execution-policy)
9. [Error Levels](#error-levels)
10. [Path Handling](#path-handling)

---

## File Locking and Self-Replace

### Problem

Windows locks files that are currently executing. Unlike Unix systems where you can overwrite a running script with `echo > "$0"`, Windows prevents modification of `.cmd` files while they're running.

### Solution: Indirection via Temporary Script

AutoUpdaterWin uses a **replacement script** that:
1. Runs as a separate process
2. Waits for the original script to exit
3. Replaces the old file with the new version
4. Restarts the script
5. Deletes itself

**Implementation:**

```batch
:_self_replace
    set REPLACE_SCRIPT=%TEMP%\auto_update_replace_%RANDOM%.cmd

    REM Create temporary replacement script
    (
        echo @echo off
        echo timeout /t 2 /nobreak ^>nul
        echo copy /Y "%NEW_VERSION%" "%TARGET_SCRIPT%" ^>nul
        echo start "" "%TARGET_SCRIPT%"
        echo del "%%~f0" ^>nul
    ) > "%REPLACE_SCRIPT%"

    REM Start replacement script and exit current
    start "" /min "%REPLACE_SCRIPT%"
    exit
```

**Trade-offs:**
- ✅ Reliable on all Windows versions
- ⚠️ Brief delay (2 seconds) before replacement
- ⚠️ New window may flash briefly
- ⚠️ Script exits and restarts (not seamless)

---

## Line Endings (CRLF vs LF)

### Requirement

Windows expects **CRLF** (`\r\n`) line endings for `.cmd` and `.bat` files. Scripts with LF-only endings may have issues.

### Solution: Git Attributes

`.gitattributes` file ensures correct line endings:

```gitattributes
# Windows batch files
*.cmd text eol=crlf
*.bat text eol=crlf
*.ps1 text eol=crlf

# Documentation (Unix-style)
*.md text eol=lf
*.sh text eol=lf
```

### Verification

Check line endings on Mac/Linux:

```bash
file script.cmd
# Should output: "..., with CRLF line terminators"
```

Convert if needed:

```bash
# Install dos2unix
brew install dos2unix

# Convert to CRLF
unix2dos script.cmd
```

### In Migration Tool

The migration tool automatically handles line endings:

```bash
if command -v unix2dos &> /dev/null; then
    unix2dos "$target_script" 2>/dev/null || true
fi
```

---

## PowerShell Integration

### Why PowerShell?

CMD/Batch is limited. PowerShell provides:
- **JSON parsing** (GitHub API responses)
- **Regex matching** (token preservation)
- **Date arithmetic** (cache validity)
- **HTTP downloads** (with headers for private repos)

### Hybrid Architecture

```
CMD Script (Flow Control)
  ├─> PowerShell: Date math
  ├─> PowerShell: JSON parse
  ├─> PowerShell: Token regex
  └─> PowerShell: HTTP download
```

### Calling PowerShell from CMD

**Simple command:**

```batch
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Date"
```

**Capture output:**

```batch
for /f "delims=" %%i in ('powershell -Command "Get-Date"') do set RESULT=%%i
```

**Load and execute functions:**

```batch
powershell -NoProfile -ExecutionPolicy Bypass -Command ". 'helpers.ps1'; Compare-Versions -Version1 '1.0.0' -Version2 '1.0.1'"
```

### Execution Policy Bypass

Always use `-ExecutionPolicy Bypass` to avoid permission issues:

```batch
powershell -NoProfile -ExecutionPolicy Bypass -Command "..."
```

This bypasses restrictions without changing system settings.

---

## Variable Syntax

### CMD vs Bash

| Feature | Bash | CMD |
|---------|------|-----|
| **Declare** | `VAR="value"` | `SET VAR=value` |
| **Use** | `$VAR` or `${VAR}` | `%VAR%` |
| **Quotes** | Required for spaces | Optional |
| **Arrays** | Supported | Not supported |
| **Math** | `$((1+1))` | `set /a RESULT=1+1` |

### Critical: SCRIPT_VERSION Syntax

**Correct (Windows):**

```batch
SET SCRIPT_VERSION=1.0.0
```

**Incorrect (Bash-style):**

```batch
SET SCRIPT_VERSION="1.0.0"  ❌ Includes quotes in value!
```

### Quotes in Variables

CMD includes quotes as part of the value:

```batch
SET VAR="hello"
echo %VAR%
REM Output: "hello" (quotes included)
```

**Best practice:** Don't use quotes unless the value contains spaces.

---

## Function Calls vs Source

### Bash: Source

```bash
source file.sh  # Executes in current shell
. file.sh       # Same as source
```

### CMD: Call

```batch
call file.cmd   REM Executes in subshell, returns to caller
```

**Important:** CMD has no `source` equivalent. `call` is the closest:

```batch
call :function_name      REM Call label as subroutine
call other_script.cmd    REM Execute and return
```

### Labels as Functions

```batch
:my_function
    echo Inside function
    exit /b 0

REM Call it:
call :my_function
```

---

## Cache Location

### Unix/Bash

```bash
CACHE_DIR="/tmp/auto_update_cache"
```

### Windows/CMD

```batch
SET CACHE_DIR=%TEMP%\auto_update_cache
```

### `%TEMP%` Directory

- **Location:** `C:\Users\<user>\AppData\Local\Temp`
- **User-specific:** Multi-user safe
- **Auto-cleanup:** Windows periodically cleans temp files
- **Persistent:** Survives reboots (until cleanup)

### Cache Structure

```
%TEMP%\auto_update_cache\
  ├─ engine.cmd              (Update engine)
  └─ helpers.ps1             (PowerShell helpers)
```

---

## Download Methods

### Windows 10+: curl

Windows 10 (1803+) includes `curl.exe`:

```batch
curl -sSfL "https://example.com/file" -o "output.txt"
```

**Flags:**
- `-s`: Silent
- `-S`: Show errors
- `-f`: Fail on HTTP errors
- `-L`: Follow redirects

### Windows 7+: PowerShell

Fallback for older systems:

```batch
powershell -Command "Invoke-WebRequest -Uri 'https://example.com/file' -OutFile 'output.txt' -UseBasicParsing"
```

### AutoUpdaterWin Approach

Try `curl` first, fallback to PowerShell:

```batch
curl -sSfL "%URL%" -o "%OUTPUT%" >nul 2>&1
if errorlevel 1 (
    powershell -Command "Invoke-WebRequest -Uri '%URL%' -OutFile '%OUTPUT%' -UseBasicParsing"
)
```

### With Authentication (Private Repos)

PowerShell with headers:

```powershell
$headers = @{
    "Authorization" = "Bearer $Token"
}
Invoke-WebRequest -Uri $Url -OutFile $OutFile -Headers $headers -UseBasicParsing
```

---

## Execution Policy

### What is Execution Policy?

Windows security feature that restricts PowerShell script execution.

### Common Policies

- **Restricted**: No scripts (default on some systems)
- **AllSigned**: Only signed scripts
- **RemoteSigned**: Local scripts OK, remote must be signed
- **Unrestricted**: All scripts allowed

### Bypass for AutoUpdaterWin

Use `-ExecutionPolicy Bypass` flag:

```batch
powershell -NoProfile -ExecutionPolicy Bypass -Command "..."
```

This:
- ✅ Works without admin rights
- ✅ Doesn't change system settings
- ✅ Only applies to current command
- ✅ Safe for embedded scripts

### Don't Use: Set-ExecutionPolicy

**Never modify system policy:**

```powershell
Set-ExecutionPolicy Unrestricted  ❌ Requires admin, affects system
```

---

## Error Levels

### CMD Error Handling

```batch
some_command
if %ERRORLEVEL% equ 0 (
    echo Success
) else (
    echo Failed with code %ERRORLEVEL%
)
```

### Exit Codes

- `0`: Success
- Non-zero: Error

### Special: PowerShell Exit Codes

PowerShell functions can return negative values, but CMD sees them as unsigned bytes:

```powershell
exit -1  # Becomes 255 in CMD
```

**Version comparison example:**

```powershell
# PowerShell: Compare-Versions returns -1, 0, or 1
exit $result
```

```batch
REM CMD: Check result
if %ERRORLEVEL% equ 255 (
    echo Version1 is older
)
```

---

## Path Handling

### Windows Path Format

```batch
C:\Users\Name\Documents\script.cmd
```

**Forward slashes work too:**

```batch
C:/Users/Name/Documents/script.cmd  REM Also valid
```

### Special Paths

- `%USERPROFILE%`: User home (e.g., `C:\Users\Name`)
- `%TEMP%`: Temporary files
- `%APPDATA%`: Application data
- `%PROGRAMFILES%`: Program Files
- `%~dp0`: Script directory (in batch)

### Script Self-Reference

```batch
REM Current script path
echo %~f0

REM Script directory
echo %~dp0

REM Script name
echo %~nx0
```

### Path with Spaces

Always quote paths with spaces:

```batch
cd "%USERPROFILE%\My Documents"  ✅
cd %USERPROFILE%\My Documents    ❌ Fails if path has spaces
```

---

## Summary

| Challenge | Solution |
|-----------|----------|
| **File locking** | Indirection via temporary replacement script |
| **Line endings** | `.gitattributes` enforces CRLF |
| **JSON parsing** | PowerShell `ConvertFrom-Json` |
| **Token regex** | PowerShell `-replace` operator |
| **Date math** | PowerShell `New-TimeSpan` |
| **HTTP auth** | PowerShell with headers |
| **Execution policy** | `-ExecutionPolicy Bypass` flag |
| **No source** | Use `call` for subroutines |
| **Variables** | No quotes unless needed |
| **Cache** | `%TEMP%` directory |
| **Download** | `curl` (Win10+) or PowerShell fallback |

---

## Related Documentation

- [SETUP.md](SETUP.md) - Setup guide
- [MODES.md](MODES.md) - Update modes
- [MIGRATION.md](MIGRATION.md) - Migrating from Bash AutoUpdater
- [README.md](../README.md) - Main documentation
