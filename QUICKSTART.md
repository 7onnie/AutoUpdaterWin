# Quick Start Guide - AutoUpdaterWin

Get auto-updates working in your Windows script in 5 minutes.

## Step 1: Add Bootstrap Code (2 min)

Open your `.cmd` or `.bat` script and add this at the top:

```batch
@echo off
SET SCRIPT_VERSION=1.0.0
SET UPDATE_MODE=github_release
SET GITHUB_USER=YourUsername
SET GITHUB_REPO=YourRepoName

call :auto_update
REM === Your script starts here ===
echo Hello from my script!
exit /b

REM === Auto-Update Bootstrap ===
:auto_update
    set ENGINE_URL=https://raw.githubusercontent.com/7onnie/AutoUpdaterWin/main/lib/auto_update_engine.cmd
    set CACHE_DIR=%TEMP%\auto_update_cache
    set CACHE_FILE=%CACHE_DIR%\engine.cmd
    set CACHE_LIFETIME_MIN=1440

    if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%"

    REM Check cache validity
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$cache='%CACHE_FILE%'; if (Test-Path $cache) { $age = (New-TimeSpan -Start (Get-Item $cache).LastWriteTime -End (Get-Date)).TotalMinutes; if ($age -lt %CACHE_LIFETIME_MIN%) { exit 0 } }; exit 1"
    if %ERRORLEVEL% equ 0 (
        call "%CACHE_FILE%"
        if not errorlevel 1 (
            call :_auto_update_main
            exit /b
        )
    )

    REM Download engine
    echo [AutoUpdate] Downloading update engine...
    curl -sSfL "%ENGINE_URL%" -o "%CACHE_FILE%" 2>nul
    if errorlevel 1 (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri '%ENGINE_URL%' -OutFile '%CACHE_FILE%'" 2>nul
    )

    if exist "%CACHE_FILE%" (
        call "%CACHE_FILE%"
        if not errorlevel 1 (
            call :_auto_update_main
        )
    )
    exit /b
```

**Important:**
- Replace `YourUsername` with your GitHub username
- Replace `YourRepoName` with your repository name
- Set `SCRIPT_VERSION` to your current version (e.g., `1.0.0`)

## Step 2: Create GitHub Workflow (2 min)

Create `.github/workflows/release.yml` in your repository:

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

      - name: Find and process script
        shell: powershell
        run: |
          # Find first .cmd or .bat file
          $SCRIPT = Get-ChildItem -Filter "*.cmd" | Select-Object -First 1 -ExpandProperty Name
          if (-not $SCRIPT) {
            $SCRIPT = Get-ChildItem -Filter "*.bat" | Select-Object -First 1 -ExpandProperty Name
          }

          if (-not $SCRIPT) {
            Write-Host "No .cmd or .bat file found"
            exit 1
          }

          Write-Host "Found script: $SCRIPT"

          # Extract version
          $CONTENT = Get-Content $SCRIPT -Raw
          if ($CONTENT -match '(?im)^SET SCRIPT_VERSION=(["]?)([^"\r\n]+)\1') {
            $VERSION = $matches[2]
            Write-Host "Current version: $VERSION"

            # Create release
            Write-Host "Creating release v$VERSION..."
            gh release create "v$VERSION" $SCRIPT `
              --title "Release v$VERSION" `
              --notes "Automatic release for version $VERSION" 2>&1 || echo "Release may already exist"
          } else {
            Write-Host "ERROR: SCRIPT_VERSION not found in $SCRIPT"
            exit 1
          }
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Step 3: Push to GitHub (1 min)

```powershell
# Initialize git if needed
git init
git add .
git commit -m "Add auto-update support v1.0.0"

# Create GitHub repo and push (if not exists)
gh repo create my-script --public --source=. --push
```

Or if repo already exists:

```powershell
git add .
git commit -m "Add auto-update support v1.0.0"
git push
```

## Step 4: Test (1 min)

Check that the release was created:

```powershell
gh release list
```

You should see `v1.0.0` in the list.

Now test the auto-update:

```cmd
myscript.cmd
```

The script will:
1. Download the update engine to `%TEMP%\auto_update_cache`
2. Check GitHub for new releases
3. If a newer version exists, download and replace itself
4. Restart with the new version

## Step 5: Update Your Script

When you want to release a new version:

1. Edit your script
2. Increment `SCRIPT_VERSION`:
   ```batch
   SET SCRIPT_VERSION=1.0.1
   ```
3. Commit and push:
   ```powershell
   git add .
   git commit -m "Update to v1.0.1"
   git push
   ```

The GitHub Action automatically creates a new release. Users running the old version will auto-update!

## Private Repositories

If your repository is private, add a GitHub token:

```batch
SET GITHUB_TOKEN=ghp_your_token_here
```

To create a token:
1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Select scopes: `repo` (for private repos)
4. Copy the token and add it to your script

The token is preserved during updates.

## Troubleshooting

### Script doesn't update

1. Check `SCRIPT_VERSION` format: `SET SCRIPT_VERSION=1.0.0` (no quotes!)
2. Verify GitHub release exists: `gh release list`
3. Check cache: `dir %TEMP%\auto_update_cache`

### GitHub Action fails

1. Ensure workflow file is in `.github/workflows/release.yml`
2. Check that `SCRIPT_VERSION` is in the script
3. Verify repository has Actions enabled

### PowerShell errors

If you see "Execution Policy" errors, the bootstrap handles this with `-ExecutionPolicy Bypass`.

## Next Steps

- Read [docs/MODES.md](docs/MODES.md) for other update modes
- See [examples/](examples/) for more examples
- Read [docs/WINDOWS_SPECIFICS.md](docs/WINDOWS_SPECIFICS.md) for implementation details

## Getting Help

- Check [docs/](docs/) for detailed documentation
- Open an issue: https://github.com/7onnie/AutoUpdaterWin/issues
- See [README.md](README.md) for complete reference
