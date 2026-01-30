# Script Migration Guide

Guide for migrating existing Windows batch scripts to use AutoUpdaterWin.

## Table of Contents

1. [Overview](#overview)
2. [Manual Migration](#manual-migration)
3. [Automated Migration Tool](#automated-migration-tool)
4. [Preparation](#preparation)
5. [Migration Steps](#migration-steps)
6. [Post-Migration](#post-migration)
7. [Troubleshooting](#troubleshooting)

---

## Overview

### What is Script Migration?

Migrating a script means:
1. Adding auto-update capability to existing script
2. Creating a GitHub repository for the script
3. Setting up automatic releases via GitHub Actions
4. Optional: Creating installer for network share distribution

### Migration Methods

| Method | Best For | Time Required |
|--------|----------|---------------|
| **Manual** | Single script, learning | 15-30 min |
| **Automated Tool** | Multiple scripts, consistency | 5 min per script |

### What You'll Get

After migration:
- ✅ Script auto-updates from GitHub
- ✅ Version control with Git
- ✅ Automatic releases on version change
- ✅ Optional installer for Share distribution
- ✅ GitHub backup of your script

---

## Manual Migration

Step-by-step guide for manual migration.

### Step 1: Prepare Script

#### 1.1. Add Script Header

Add to the top of your `.cmd` file:

```batch
@echo off
REM ============================================================================
REM Your Script Name
REM Description of what it does
REM ============================================================================

SET SCRIPT_VERSION=1.0.0
SET UPDATE_MODE=github_release
SET GITHUB_USER=YourUsername
SET GITHUB_REPO=YourRepoName
```

#### 1.2. Add Bootstrap Call

After the configuration, before your main logic:

```batch
call :auto_update

REM === Main Script Logic ===
echo Running script...
REM Your existing code here
exit /b 0
```

#### 1.3. Add Bootstrap Function

At the end of your script:

```batch
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
        call "%CACHE_FILE%"
        if not errorlevel 1 (
            call :_auto_update_main
        )
    )

    exit /b 0
```

### Step 2: Create GitHub Repository

#### 2.1. Initialize Git

```cmd
cd C:\path\to\your\script
git init
```

#### 2.2. Create .gitattributes

Create `.gitattributes` file:

```gitattributes
*.cmd text eol=crlf
*.bat text eol=crlf
*.ps1 text eol=crlf
*.md text eol=lf
```

#### 2.3. Create .gitignore

Create `.gitignore` file:

```gitignore
*.bak
*.tmp
*.log
.DS_Store
Thumbs.db
```

#### 2.4. Initial Commit

```cmd
git add .
git commit -m "Initial commit: Add auto-update support v1.0.0"
```

#### 2.5. Create GitHub Repository

**Using gh CLI:**

```cmd
gh repo create myscript --private --source=. --push
```

**Manual:**
1. Go to https://github.com/new
2. Create repository (private or public)
3. Follow instructions to push existing repository

### Step 3: Setup GitHub Actions

#### 3.1. Create Workflow Directory

```cmd
mkdir .github\workflows
```

#### 3.2. Create Workflow File

Create `.github\workflows\release.yml`:

```yaml
name: Auto Release on Version Change

on:
  push:
    branches: [ main ]
    paths:
      - '*.cmd'
      - '*.bat'

permissions:
  contents: write

jobs:
  check-and-release:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 2

      - name: Find and process script
        shell: powershell
        run: |
          $SCRIPT = Get-ChildItem -Filter "*.cmd" | Select-Object -First 1 -ExpandProperty Name
          if (-not $SCRIPT) {
            $SCRIPT = Get-ChildItem -Filter "*.bat" | Select-Object -First 1 -ExpandProperty Name
          }

          $CONTENT = Get-Content $SCRIPT -Raw
          if ($CONTENT -match '(?im)^SET\s+SCRIPT_VERSION=(["]?)([^"\r\n]+)\1') {
            $VERSION = $matches[2].Trim()

            gh release view "v$VERSION" 2>$null
            if ($LASTEXITCODE -eq 0) {
              Write-Host "Release already exists"
              exit 0
            }

            gh release create "v$VERSION" $SCRIPT `
              --title "Release v$VERSION" `
              --notes "Release $VERSION" `
              --latest
          }
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

#### 3.3. Commit and Push

```cmd
git add .github\workflows\release.yml
git commit -m "Add auto-release workflow"
git push
```

### Step 4: Verify

1. Check GitHub Actions tab - should see successful run
2. Check Releases - should have v1.0.0 release
3. Run script locally - should see auto-update messages

---

## Automated Migration Tool

Use the migration tool for faster, consistent migrations.

### Prerequisites

**On Mac/Linux:**
- `gh` CLI installed and authenticated
- Script files accessible (via Share or local copy)

### Usage

#### Interactive Mode

```bash
cd ~/GitHubRepos/AutoUpdaterWin
./tools/migrate_script_to_repo.sh
```

Follow prompts:
1. Path to Windows script
2. Repository name
3. Visibility (private/public)
4. Installer mode (yes/no)
5. GitHub token (for installer)

#### CLI Mode

```bash
./tools/migrate_script_to_repo.sh \
  --script ~/ZS_Share/Scripts/MyScript.cmd \
  --repo-name my-script \
  --private \
  --installer-mode \
  --share-token ghp_xxxxx
```

### What It Does

1. **Validates script**:
   - Checks for `.cmd` or `.bat` extension
   - Verifies `SET SCRIPT_VERSION=` exists
   - Checks for `@echo off`
   - Validates CRLF line endings

2. **Creates repository**:
   - Initializes Git
   - Creates `.gitattributes` and `.gitignore`
   - Creates `README.md`
   - Creates GitHub repository (private/public)

3. **Copies script**:
   - Copies script to repository
   - Preserves line endings
   - Extracts version

4. **Adds workflow**:
   - Creates `.github/workflows/release.yml`
   - Configured for Windows runner
   - Automatic release on version change

5. **Creates installer** (if requested):
   - Creates `script-installer.cmd`
   - Sets `SCRIPT_VERSION=0.0.0`
   - Embeds GitHub token
   - Ready for Share distribution

6. **Initial release**:
   - Commits all files
   - Pushes to GitHub
   - Creates initial release

### Example Output

```
ℹ️  Starting migration process...
ℹ️  Script: /Users/user/ZS_Share/Scripts/MyScript.cmd
ℹ️  Repository: my-script
ℹ️  Visibility: private
ℹ️  Validating Windows script: /Users/user/ZS_Share/Scripts/MyScript.cmd
✅ Windows script validation passed
ℹ️  Creating GitHub repository: my-script
✅ Repository created: https://github.com/7onnie/my-script
ℹ️  Copying script to repository...
✅ Script copied: MyScript.cmd
ℹ️  Detected version: 1.2.0
ℹ️  Creating GitHub Actions workflow...
✅ GitHub Actions workflow created
ℹ️  Creating installer script for Share...
✅ Installer script created: my-script-installer.cmd
ℹ️  Creating initial release v1.2.0...
✅ Migration completed successfully!
✅ Repository: https://github.com/7onnie/my-script
✅ Local path: /Users/user/GitHubRepos/my-script
```

---

## Preparation

### Before Migration

#### 1. Review Script

- Remove hardcoded paths that won't work for others
- Check for dependencies (other scripts, files)
- Verify script works correctly
- Document any prerequisites

#### 2. Choose Version Number

Use semantic versioning:
- `1.0.0` - First stable release
- `0.9.0` - Pre-release/beta
- `2.0.0` - Major changes/breaking

#### 3. Decide Visibility

**Private:**
- ✅ Script is proprietary/internal
- ✅ Contains sensitive logic
- ✅ Requires GitHub token for updates

**Public:**
- ✅ Open-source friendly
- ✅ No sensitive information
- ✅ Community can contribute

#### 4. Private Repo Token

For private repositories, create GitHub token:
1. Go to https://github.com/settings/tokens
2. "Generate new token (classic)"
3. Scope: `repo`
4. Copy token (starts with `ghp_`)

---

## Migration Steps

### Standard Migration

1. **Prepare script** (add version, bootstrap)
2. **Create repository** (git init, gh repo create)
3. **Add workflow** (GitHub Actions)
4. **Push and verify** (git push, check Actions)

### With Installer (for Share)

1-4. Same as standard migration

5. **Create installer**:
   ```batch
   REM myscript-installer.cmd
   SET SCRIPT_VERSION=0.0.0
   SET UPDATE_MODE=github_release
   SET GITHUB_USER=youruser
   SET GITHUB_REPO=myscript
   SET GITHUB_TOKEN=ghp_sharetoken

   call :auto_update
   exit /b 0

   :auto_update
       REM Bootstrap...
   ```

6. **Place in Share**:
   ```cmd
   copy myscript-installer.cmd \\share\Scripts\
   ```

7. **Test from Share**:
   ```cmd
   \\share\Scripts\myscript-installer.cmd
   ```

---

## Post-Migration

### Verify Auto-Update

#### Test 1: Initial Run

```cmd
myscript.cmd
```

Should see:
```
[AutoUpdate] Downloading update engine...
[AutoUpdate] Checking for updates...
[AutoUpdate] Already up to date
```

#### Test 2: Update

1. Change version in script:
   ```batch
   SET SCRIPT_VERSION=1.0.1
   ```

2. Commit and push:
   ```cmd
   git add .
   git commit -m "Update to v1.0.1"
   git push
   ```

3. Wait for GitHub Action

4. Run old version - should auto-update

### Documentation

Add `README.md` to repository:

```markdown
# MyScript

Description of what the script does.

## Usage

\`\`\`cmd
myscript.cmd
\`\`\`

## Auto-Update

This script uses [AutoUpdaterWin](https://github.com/7onnie/AutoUpdaterWin) for automatic updates.

## Version History

- v1.0.0 - Initial release
```

### Share Distribution

If using installer:

1. Copy installer to Share:
   ```cmd
   copy myscript-installer.cmd \\share\Scripts\
   ```

2. Document for users:
   ```
   To use MyScript:
   1. Run: \\share\Scripts\myscript-installer.cmd
   2. First run downloads latest version
   3. Script auto-updates on future runs
   ```

---

## Troubleshooting

### Script Version Not Detected

**Problem:** GitHub Action can't find `SCRIPT_VERSION`

**Solution:** Verify syntax:

```batch
REM Correct
SET SCRIPT_VERSION=1.0.0

REM Wrong
SET SCRIPT_VERSION="1.0.0"  ❌
SCRIPT_VERSION=1.0.0        ❌
```

### Line Ending Issues

**Problem:** Script fails on Windows

**Solution:** Convert to CRLF:

```bash
unix2dos script.cmd
```

Or use `.gitattributes`:

```gitattributes
*.cmd text eol=crlf
```

### Token Not Preserved

**Problem:** Token lost after update

**Solution:** Verify token format:

```batch
REM Correct formats
SET GITHUB_TOKEN=ghp_xxxxxxxxxxxxx
SET GITHUB_TOKEN=github_pat_xxxxx

REM Also works (but not recommended)
SET GITHUB_TOKEN="ghp_xxxx"
```

Token must start with known prefix:
- `ghp_` - Personal access token
- `github_pat_` - Fine-grained token
- `gho_`, `ghu_`, `ghs_`, `ghr_` - OAuth tokens

### Workflow Fails

**Check 1: Permissions**

Workflow needs write permission:

```yaml
permissions:
  contents: write
```

**Check 2: Script Exists**

Verify script is in repository root (not subfolder).

**Check 3: Logs**

Check GitHub Actions logs for detailed error.

---

## Related Documentation

- [SETUP.md](SETUP.md) - Detailed setup guide
- [MODES.md](MODES.md) - Update modes
- [WINDOWS_SPECIFICS.md](WINDOWS_SPECIFICS.md) - Implementation details
- [README.md](../README.md) - Main documentation
