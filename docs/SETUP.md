# Setup Guide

Complete guide to setting up AutoUpdaterWin for your Windows batch scripts.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Setup (5 minutes)](#quick-setup-5-minutes)
3. [Detailed Setup](#detailed-setup)
4. [GitHub Token Setup (Private Repos)](#github-token-setup-private-repos)
5. [Testing Your Setup](#testing-your-setup)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required

- **Windows 10+** (or Windows 7+ with PowerShell 3.0+)
- **Git** installed
- **GitHub account**

### Optional

- **GitHub CLI** (`gh`) for easier repository management
- **Visual Studio Code** or text editor with CRLF support

### Verify Prerequisites

```cmd
REM Check Windows version
ver

REM Check PowerShell
powershell -Command "$PSVersionTable.PSVersion"

REM Check git
git --version

REM Check gh CLI (optional)
gh --version

REM Check curl (Windows 10+)
curl --version
```

---

## Quick Setup (5 minutes)

### Step 1: Add Bootstrap to Script

Add this to the top of your `.cmd` file:

```batch
@echo off
SET SCRIPT_VERSION=1.0.0
SET UPDATE_MODE=github_release
SET GITHUB_USER=YourUsername
SET GITHUB_REPO=YourRepoName

call :auto_update

REM === Your script code here ===
echo Hello World!
exit /b 0

REM === Bootstrap code (copy from bootstrap/bootstrap_minimal.cmd) ===
:auto_update
    REM ... bootstrap code ...
    exit /b 0
```

### Step 2: Create GitHub Repository

```powershell
# Initialize git
git init
git add .
git commit -m "Initial commit v1.0.0"

# Create GitHub repo
gh repo create my-script --public --source=. --push
```

### Step 3: Add Workflow

Create `.github/workflows/release.yml`:

```yaml
name: Auto Release

on:
  push:
    branches: [ main ]
    paths:
      - '*.cmd'
      - '*.bat'

permissions:
  contents: write

jobs:
  release:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3

      - name: Create Release
        shell: powershell
        run: |
          $SCRIPT = (Get-ChildItem -Filter "*.cmd")[0].Name
          $VERSION = (Select-String -Path $SCRIPT -Pattern "^SET SCRIPT_VERSION=(.+)$").Matches.Groups[1].Value.Trim()
          gh release create "v$VERSION" $SCRIPT --title "v$VERSION" --notes "Release $VERSION"
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Step 4: Push and Test

```powershell
git add .
git commit -m "Add auto-update"
git push
```

Done! Your script now auto-updates.

---

## Detailed Setup

### 1. Prepare Your Script

#### 1.1. Add Version Variable

At the top of your script, add:

```batch
SET SCRIPT_VERSION=1.0.0
```

**Important:**
- Use semantic versioning: `MAJOR.MINOR.PATCH`
- **No quotes** around the value
- Must be early in the script (before `:auto_update`)

#### 1.2. Add Update Configuration

```batch
SET UPDATE_MODE=github_release
SET GITHUB_USER=YourGitHubUsername
SET GITHUB_REPO=your-repo-name
```

**For private repositories:**

```batch
SET GITHUB_TOKEN=ghp_your_personal_access_token
```

#### 1.3. Add Bootstrap Code

Copy the bootstrap from `bootstrap/bootstrap_minimal.cmd` and add it as a function:

```batch
call :auto_update

REM Your script logic here

exit /b 0

REM === Bootstrap code ===
:auto_update
    set ENGINE_URL=https://raw.githubusercontent.com/7onnie/AutoUpdaterWin/main/lib/auto_update_engine.cmd
    REM ... (full bootstrap code)
    exit /b 0
```

#### 1.4. Example Complete Script

```batch
@echo off
REM ============================================================================
REM My Script
REM ============================================================================

SET SCRIPT_VERSION=1.0.0
SET UPDATE_MODE=github_release
SET GITHUB_USER=myusername
SET GITHUB_REPO=my-script

call :auto_update

REM === Main Script ===
echo Running My Script v%SCRIPT_VERSION%
REM Your code here
exit /b 0

REM === Auto-Update Bootstrap ===
:auto_update
    REM ... bootstrap code from bootstrap_minimal.cmd ...
    exit /b 0
```

### 2. Create GitHub Repository

#### 2.1. Initialize Git

```cmd
cd \path\to\your\script
git init
```

#### 2.2. Create .gitattributes

Important for Windows line endings:

```gitattributes
*.cmd text eol=crlf
*.bat text eol=crlf
*.ps1 text eol=crlf
*.md text eol=lf
```

#### 2.3. Create .gitignore

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

**Using GitHub CLI:**

```cmd
gh repo create my-script --public --source=. --push
```

**Manual method:**
1. Go to https://github.com/new
2. Create repository
3. Follow push instructions

### 3. Setup GitHub Actions Workflow

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
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          fetch-depth: 2

      - name: Find script and create release
        shell: powershell
        run: |
          # Find first .cmd file
          $SCRIPT = Get-ChildItem -Filter "*.cmd" | Select-Object -First 1 -ExpandProperty Name
          if (-not $SCRIPT) {
            $SCRIPT = Get-ChildItem -Filter "*.bat" | Select-Object -First 1 -ExpandProperty Name
          }

          if (-not $SCRIPT) {
            Write-Error "No .cmd or .bat file found"
            exit 1
          }

          # Extract version
          $CONTENT = Get-Content $SCRIPT -Raw
          if ($CONTENT -match '(?im)^SET\s+SCRIPT_VERSION=(["]?)([^"\r\n]+)\1') {
            $VERSION = $matches[2].Trim()
            Write-Host "Version: $VERSION"

            # Check if release exists
            gh release view "v$VERSION" 2>$null
            if ($LASTEXITCODE -eq 0) {
              Write-Host "Release already exists"
              exit 0
            }

            # Create release
            gh release create "v$VERSION" $SCRIPT `
              --title "Release v$VERSION" `
              --notes "Automatic release for version $VERSION" `
              --latest

          } else {
            Write-Error "SCRIPT_VERSION not found"
            exit 1
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

### 4. Verify Setup

#### 4.1. Check GitHub Actions

1. Go to your repository on GitHub
2. Click "Actions" tab
3. Verify workflow ran successfully
4. Check "Releases" for v1.0.0

#### 4.2. Test Script

Run your script:

```cmd
myscript.cmd
```

You should see:
```
[AutoUpdate] Downloading update engine...
[AutoUpdate] Engine loaded successfully
[AutoUpdate] Checking for updates...
[AutoUpdate] Current version: 1.0.0
[AutoUpdate] Already up to date
```

---

## GitHub Token Setup (Private Repos)

### Why Tokens?

GitHub tokens allow your script to:
- Access private repositories
- Download private releases
- Authenticate with GitHub API

### Creating a Token

#### Step 1: Go to GitHub Settings

Visit: https://github.com/settings/tokens

#### Step 2: Generate New Token

1. Click **"Generate new token (classic)"**
2. Give it a descriptive name: "AutoUpdaterWin - MyScript"
3. Set expiration (or "No expiration" for scripts)

#### Step 3: Select Scopes

For **private repositories**:
- ✅ `repo` - Full control of private repositories

For **public repositories** (if needed):
- ✅ `public_repo` - Access public repositories only

#### Step 4: Generate and Copy

1. Click "Generate token"
2. **Copy the token** (starts with `ghp_` or `github_pat_`)
3. **Save it securely** - you won't see it again!

### Adding Token to Script

#### Method 1: Hardcode (Simple)

```batch
SET GITHUB_TOKEN=ghp_your_token_here
```

**Pros:**
- Simple
- Token preserved during updates

**Cons:**
- Token visible in script
- Don't commit to public repos

#### Method 2: Environment Variable

Set system environment variable:

```cmd
setx GITHUB_TOKEN "ghp_your_token_here"
```

Then in script:

```batch
REM Token will be read from environment
if not defined GITHUB_TOKEN (
    echo ERROR: GITHUB_TOKEN not set
    exit /b 1
)
```

#### Method 3: Separate Config File

Create `config.cmd`:

```batch
@echo off
SET GITHUB_TOKEN=ghp_your_token_here
```

Add to `.gitignore`:

```gitignore
config.cmd
```

In main script:

```batch
call config.cmd
call :auto_update
```

### Token Security

**DO:**
- ✅ Use minimum required scopes
- ✅ Set expiration date
- ✅ Add `config.cmd` to `.gitignore`
- ✅ Rotate tokens periodically

**DON'T:**
- ❌ Commit tokens to public repositories
- ❌ Share scripts with tokens included
- ❌ Use tokens with excessive permissions

---

## Testing Your Setup

### Test 1: Initial Run

```cmd
myscript.cmd
```

Expected output:
```
[AutoUpdate] Downloading update engine...
[AutoUpdate] Engine loaded successfully
[AutoUpdate] Checking for updates...
[AutoUpdate] Already up to date
```

### Test 2: Cache Test

Run again immediately:

```cmd
myscript.cmd
```

Should use cached engine (no download message).

### Test 3: Update Test

1. Edit script, change version:
   ```batch
   SET SCRIPT_VERSION=1.0.1
   ```

2. Commit and push:
   ```cmd
   git add .
   git commit -m "Update to v1.0.1"
   git push
   ```

3. Wait for GitHub Action (check Actions tab)

4. Run old version - should auto-update:
   ```cmd
   REM Manually revert local version to 1.0.0 for testing
   REM Then run script
   myscript.cmd
   ```

   Expected:
   ```
   [AutoUpdate] Update available: 1.0.0 -> 1.0.1
   [AutoUpdate] Downloading update...
   [AutoUpdate] Installing update...
   [AutoUpdate] Script will restart automatically
   ```

### Test 4: Token Preservation (Private Repos)

1. Add token to script
2. Trigger update
3. Verify token still present after update

---

## Troubleshooting

### Script doesn't update

**Check 1: Version format**

```batch
REM Correct
SET SCRIPT_VERSION=1.0.0

REM Wrong
SET SCRIPT_VERSION="1.0.0"  ❌ Includes quotes
```

**Check 2: GitHub release exists**

```cmd
gh release list
```

**Check 3: Cache**

Clear cache and retry:

```cmd
rmdir /s /q %TEMP%\auto_update_cache
myscript.cmd
```

### GitHub Action fails

**Check 1: Workflow file location**

Must be: `.github\workflows\release.yml`

**Check 2: Permissions**

Workflow needs:

```yaml
permissions:
  contents: write
```

**Check 3: Script has SCRIPT_VERSION**

```cmd
findstr "SCRIPT_VERSION" myscript.cmd
```

### PowerShell errors

**Error:** "Execution policy"

**Solution:** Bootstrap already uses `-ExecutionPolicy Bypass`

If still failing:

```cmd
powershell -ExecutionPolicy Bypass -File test.ps1
```

### Download fails

**Check curl:**

```cmd
curl --version
```

If not available, PowerShell fallback activates automatically.

**Check connectivity:**

```cmd
curl -I https://raw.githubusercontent.com
```

### Token issues

**Error:** "Bad credentials"

- Token expired → Generate new one
- Wrong token → Verify copy-paste
- Wrong scopes → Need `repo` scope

---

## Next Steps

- Read [MODES.md](MODES.md) for other update modes
- See [WINDOWS_SPECIFICS.md](WINDOWS_SPECIFICS.md) for implementation details
- Check [examples/](../examples/) for complete examples
- Review [SCRIPT_MIGRATION.md](SCRIPT_MIGRATION.md) for migration guide

---

## Support

- Issues: https://github.com/7onnie/AutoUpdaterWin/issues
- Examples: [../examples/](../examples/)
- Main Docs: [../README.md](../README.md)
