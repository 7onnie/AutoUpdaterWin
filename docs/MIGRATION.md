# Migration from Bash AutoUpdater

Guide for migrating from [AutoUpdater](https://github.com/7onnie/AutoUpdater) (Bash) to AutoUpdaterWin (Windows CMD).

## Table of Contents

1. [Overview](#overview)
2. [Key Differences](#key-differences)
3. [Syntax Translation](#syntax-translation)
4. [Migration Steps](#migration-steps)
5. [Common Patterns](#common-patterns)
6. [Troubleshooting](#troubleshooting)

---

## Overview

### When to Migrate

Migrate from Bash AutoUpdater to AutoUpdaterWin when:
- Moving script from Linux/Mac to Windows
- Supporting cross-platform deployment
- Rewriting Bash logic in CMD/Batch

### What Changes

| Aspect | AutoUpdater (Bash) | AutoUpdaterWin (CMD) |
|--------|-------------------|----------------------|
| **Language** | Bash | CMD/Batch + PowerShell |
| **File extension** | `.sh` | `.cmd` or `.bat` |
| **Line endings** | LF (`\n`) | CRLF (`\r\n`) |
| **Variable syntax** | `VAR="value"` | `SET VAR=value` |
| **Function calls** | `source file.sh` | `call file.cmd` |
| **JSON parsing** | `python3`/`jq` | PowerShell `ConvertFrom-Json` |
| **Self-replace** | Direct overwrite | Indirection via temp script |

### What Stays the Same

- ✅ Overall architecture (Bootstrap → Engine)
- ✅ Update modes (GitHub Release, Direct URL)
- ✅ Token preservation concept
- ✅ Cache mechanism
- ✅ GitHub Actions workflow (adapted for Windows)

---

## Key Differences

### 1. File Locking

**Bash:**
```bash
# Direct overwrite works
echo "$NEW_CONTENT" > "$0"
```

**CMD:**
```batch
REM Must use indirection (Windows locks running files)
REM Create temp script that:
REM   1. Waits for exit
REM   2. Replaces file
REM   3. Restarts script
start "" /min "%REPLACE_SCRIPT%"
exit
```

### 2. Line Endings

**Bash:**
- Uses LF (`\n`)
- Git default on Unix

**CMD:**
- Requires CRLF (`\r\n`)
- Must configure `.gitattributes`:
  ```gitattributes
  *.cmd text eol=crlf
  ```

### 3. Variable Declaration

**Bash:**
```bash
SCRIPT_VERSION="1.0.0"
GITHUB_USER="username"
GITHUB_REPO="repo"
```

**CMD:**
```batch
SET SCRIPT_VERSION=1.0.0
SET GITHUB_USER=username
SET GITHUB_REPO=repo
```

**Note:** No quotes in CMD (unless value has spaces)

### 4. Functions vs Labels

**Bash:**
```bash
auto_update() {
    echo "Updating..."
}

# Call it
auto_update
```

**CMD:**
```batch
:auto_update
    echo Updating...
    exit /b 0

REM Call it
call :auto_update
```

### 5. Sourcing vs Calling

**Bash:**
```bash
source engine.sh  # Executes in current shell
```

**CMD:**
```batch
call engine.cmd  REM Executes in subshell, returns
```

### 6. Cache Location

**Bash:**
```bash
CACHE_DIR="/tmp/auto_update_cache"
```

**CMD:**
```batch
SET CACHE_DIR=%TEMP%\auto_update_cache
```

**Windows:** `%TEMP%` = `C:\Users\<user>\AppData\Local\Temp`

### 7. JSON Parsing

**Bash:**
```bash
# Using python3
VERSION=$(echo "$JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")

# Or using jq
VERSION=$(echo "$JSON" | jq -r '.tag_name')
```

**CMD:**
```batch
REM Using PowerShell
powershell -Command "$json = Get-Content release.json | ConvertFrom-Json; Write-Output $json.tag_name"
```

---

## Syntax Translation

### Variables

| Bash | CMD | Notes |
|------|-----|-------|
| `VAR="value"` | `SET VAR=value` | No quotes in CMD |
| `VAR='value'` | `SET VAR=value` | Single quotes not used |
| `$VAR` | `%VAR%` | Access variable |
| `${VAR}` | `%VAR%` | Braces not needed |
| `VAR=$(cmd)` | `for /f ... do set VAR=...` | Command substitution |
| `export VAR` | `SET VAR=...` | No export needed |

### Control Flow

| Bash | CMD | Notes |
|------|-----|-------|
| `if [ "$VAR" = "value" ]` | `if "%VAR%"=="value"` | Different syntax |
| `if [ -f file ]` | `if exist file` | File test |
| `if [ ! -f file ]` | `if not exist file` | Negation |
| `&&` | `&&` | Same (AND) |
| `\|\|` | `\|\|` | Same (OR) |
| `;` | `&` | Command separator |

### Output

| Bash | CMD | Notes |
|------|-----|-------|
| `echo "text"` | `echo text` | No quotes needed |
| `echo -n "text"` | `echo\|set /p="text"` | No newline |
| `printf "%s" "$VAR"` | `echo %VAR%` | Simple echo |

### Loops

**Bash:**
```bash
for file in *.sh; do
    echo "$file"
done
```

**CMD:**
```batch
for %%F in (*.cmd) do (
    echo %%F
)
```

### Functions

**Bash:**
```bash
my_function() {
    local param="$1"
    echo "$param"
    return 0
}

my_function "hello"
```

**CMD:**
```batch
:my_function
    set param=%~1
    echo %param%
    exit /b 0

call :my_function "hello"
```

---

## Migration Steps

### Step 1: Convert Variable Declarations

**Bash:**
```bash
#!/bin/bash
SCRIPT_VERSION="1.0.0"
UPDATE_MODE="github_release"
GITHUB_USER="username"
GITHUB_REPO="repo"
```

**CMD:**
```batch
@echo off
SET SCRIPT_VERSION=1.0.0
SET UPDATE_MODE=github_release
SET GITHUB_USER=username
SET GITHUB_REPO=repo
```

### Step 2: Convert Bootstrap

**Bash:**
```bash
auto_update() {
    ENGINE_URL="https://raw.githubusercontent.com/7onnie/AutoUpdater/main/lib/auto_update_engine.sh"
    CACHE_DIR="/tmp/auto_update_cache"
    CACHE_FILE="$CACHE_DIR/engine.sh"

    if [ ! -d "$CACHE_DIR" ]; then
        mkdir -p "$CACHE_DIR"
    fi

    # Download and source
    curl -sSfL "$ENGINE_URL" -o "$CACHE_FILE"
    source "$CACHE_FILE"
    _auto_update_main
}

auto_update
```

**CMD:**
```batch
:auto_update
    set ENGINE_URL=https://raw.githubusercontent.com/7onnie/AutoUpdaterWin/main/lib/auto_update_engine.cmd
    set CACHE_DIR=%TEMP%\auto_update_cache
    set CACHE_FILE=%CACHE_DIR%\engine.cmd

    if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%"

    REM Download and call
    curl -sSfL "%ENGINE_URL%" -o "%CACHE_FILE%"
    call "%CACHE_FILE%"
    call :_auto_update_main
    exit /b 0

call :auto_update
```

### Step 3: Convert Main Logic

**Bash:**
```bash
# Main script
echo "Running version $SCRIPT_VERSION"
# Your logic here
exit 0
```

**CMD:**
```batch
REM Main script
echo Running version %SCRIPT_VERSION%
REM Your logic here
exit /b 0
```

### Step 4: Setup Git Attributes

Create `.gitattributes`:

```gitattributes
# CRITICAL: Windows scripts need CRLF
*.cmd text eol=crlf
*.bat text eol=crlf
*.ps1 text eol=crlf

# Docs use LF
*.md text eol=lf
*.sh text eol=lf
```

### Step 5: Convert GitHub Workflow

**Bash Workflow:**
```yaml
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Extract version
        run: |
          VERSION=$(grep '^SCRIPT_VERSION=' script.sh | cut -d'"' -f2)
          gh release create "v$VERSION" script.sh
```

**Windows Workflow:**
```yaml
jobs:
  release:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - name: Extract version
        shell: powershell
        run: |
          $CONTENT = Get-Content script.cmd -Raw
          $VERSION = ($CONTENT -match '^SET SCRIPT_VERSION=(.+)$').Groups[1].Value
          gh release create "v$VERSION" script.cmd
```

---

## Common Patterns

### Pattern 1: Download File

**Bash:**
```bash
curl -sSfL "$URL" -o "$OUTPUT"
```

**CMD:**
```batch
curl -sSfL "%URL%" -o "%OUTPUT%"
if errorlevel 1 (
    powershell -Command "Invoke-WebRequest -Uri '%URL%' -OutFile '%OUTPUT%'"
)
```

### Pattern 2: Check File Age

**Bash:**
```bash
if [ $(find "$FILE" -mmin +1440 | wc -l) -eq 0 ]; then
    echo "Cache valid"
fi
```

**CMD:**
```batch
powershell -Command "$age = (New-TimeSpan -Start (Get-Item '%FILE%').LastWriteTime -End (Get-Date)).TotalMinutes; if ($age -lt 1440) { exit 0 } else { exit 1 }"
if %ERRORLEVEL% equ 0 (
    echo Cache valid
)
```

### Pattern 3: JSON Parsing

**Bash:**
```bash
VERSION=$(echo "$JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")
```

**CMD:**
```batch
powershell -Command "$json = '%JSON%' | ConvertFrom-Json; Write-Output $json.tag_name" > version.txt
set /p VERSION=<version.txt
del version.txt
```

### Pattern 4: Token Preservation

**Bash:**
```bash
OLD_TOKEN=$(grep '^GITHUB_TOKEN=' "$OLD_SCRIPT" | cut -d'"' -f2)
NEW_CONTENT=$(echo "$NEW_CONTENT" | sed "s|^GITHUB_TOKEN=.*|GITHUB_TOKEN=\"$OLD_TOKEN\"|")
```

**CMD:**
```batch
powershell -Command "$old = Get-Content '%OLD_SCRIPT%' -Raw; if ($old -match 'SET GITHUB_TOKEN=(.+)') { $token = $matches[1]; $new = Get-Content '%NEW_SCRIPT%' -Raw; $new -replace '(SET GITHUB_TOKEN=).+', \"`$1$token\" | Set-Content '%NEW_SCRIPT%' }"
```

### Pattern 5: Self-Replace

**Bash:**
```bash
# Direct overwrite
echo "$NEW_CONTENT" > "$0"
exec "$0" "$@"
```

**CMD:**
```batch
REM Indirection required
set REPLACE_SCRIPT=%TEMP%\replace_%RANDOM%.cmd
(
    echo @echo off
    echo timeout /t 2 /nobreak ^>nul
    echo copy /Y "%NEW_FILE%" "%~f0" ^>nul
    echo start "" "%~f0"
    echo del "%%~f0"
) > "%REPLACE_SCRIPT%"
start "" /min "%REPLACE_SCRIPT%"
exit
```

---

## Troubleshooting

### Issue: Line Ending Errors

**Symptoms:**
- Script fails to run on Windows
- "command not found" errors
- Weird characters in output

**Solution:**
```bash
# Convert to CRLF
unix2dos script.cmd

# Or use Git
git add --renormalize .
```

### Issue: Variables Not Working

**Symptoms:**
- Variables are empty
- Quotes included in values

**Solution:**
```batch
REM Wrong (Bash style)
SET VAR="value"  ❌
echo %VAR%       → "value" (includes quotes!)

REM Correct (CMD style)
SET VAR=value    ✅
echo %VAR%       → value
```

### Issue: PowerShell Not Found

**Symptoms:**
- "powershell is not recognized"

**Solution:**
```batch
REM Check PowerShell
powershell -Command "Get-Host"

REM Use full path if needed
%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -Command "..."
```

### Issue: Script Exits Immediately

**Symptoms:**
- Script ends without running

**Solution:**
```batch
REM Wrong
:function
    echo Test
    exit  ❌ Exits entire script

REM Correct
:function
    echo Test
    exit /b 0  ✅ Returns from function
```

### Issue: File Locking

**Symptoms:**
- "File is in use" errors
- Can't replace running script

**Solution:**
- Use indirection pattern (AutoUpdaterWin handles this)
- Don't try to directly overwrite `%~f0`

---

## Complete Example

### Original Bash Script

```bash
#!/bin/bash

SCRIPT_VERSION="1.0.0"
UPDATE_MODE="github_release"
GITHUB_USER="username"
GITHUB_REPO="repo"

auto_update() {
    ENGINE_URL="https://raw.githubusercontent.com/7onnie/AutoUpdater/main/lib/auto_update_engine.sh"
    CACHE_DIR="/tmp/auto_update_cache"
    CACHE_FILE="$CACHE_DIR/engine.sh"

    mkdir -p "$CACHE_DIR"
    curl -sSfL "$ENGINE_URL" -o "$CACHE_FILE"
    source "$CACHE_FILE"
    _auto_update_main
}

auto_update

echo "Running script version $SCRIPT_VERSION"
echo "Hello World!"
```

### Converted CMD Script

```batch
@echo off

SET SCRIPT_VERSION=1.0.0
SET UPDATE_MODE=github_release
SET GITHUB_USER=username
SET GITHUB_REPO=repo

call :auto_update

echo Running script version %SCRIPT_VERSION%
echo Hello World!
exit /b 0

:auto_update
    set ENGINE_URL=https://raw.githubusercontent.com/7onnie/AutoUpdaterWin/main/lib/auto_update_engine.cmd
    set CACHE_DIR=%TEMP%\auto_update_cache
    set CACHE_FILE=%CACHE_DIR%\engine.cmd

    if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%"

    curl -sSfL "%ENGINE_URL%" -o "%CACHE_FILE%" >nul 2>&1
    if errorlevel 1 (
        powershell -Command "Invoke-WebRequest -Uri '%ENGINE_URL%' -OutFile '%CACHE_FILE%'"
    )

    if exist "%CACHE_FILE%" (
        call "%CACHE_FILE%"
        call :_auto_update_main
    )

    exit /b 0
```

---

## Related Documentation

- [WINDOWS_SPECIFICS.md](WINDOWS_SPECIFICS.md) - Windows implementation details
- [SETUP.md](SETUP.md) - Setup guide
- [SCRIPT_MIGRATION.md](SCRIPT_MIGRATION.md) - Migrating existing Windows scripts
- [README.md](../README.md) - Main documentation
- [AutoUpdater (Bash)](https://github.com/7onnie/AutoUpdater) - Original Bash version
