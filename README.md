<h1 align="center">AutoUpdaterWin</h1>

<p align="center">
  Windows CMD/Batch auto-update system for GitHub-hosted scripts.
</p>

<!-- BADGES:START -->
<p align="center">
  <a href="https://github.com/7onnie/AutoUpdaterWin/actions/workflows/release.yml"><img alt="CI" src="https://github.com/7onnie/AutoUpdaterWin/actions/workflows/release.yml/badge.svg"></a>
  <a href="https://github.com/7onnie/AutoUpdaterWin/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/7onnie/AutoUpdaterWin?sort=semver"></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/7onnie/AutoUpdaterWin"></a>
  <a href="https://buymeacoffee.com/7onnie"><img alt="Buy me a coffee" src="https://img.shields.io/badge/Buy%20me%20a%20coffee-FFDD00?logo=buymeacoffee&logoColor=black"></a>
</p>
<!-- BADGES:END -->

AutoUpdaterWin enables Windows batch scripts to automatically update themselves from GitHub releases, similar to [AutoUpdater](https://github.com/7onnie/AutoUpdater) for Bash scripts.

## Features

- **Bootstrap Minimal** - Embed ~40 lines of CMD code for auto-updates
- **Private Repository Support** - Works with private GitHub repos using tokens
- **Smart Caching** - Caches update engine locally (24h default)
- **Token Preservation** - GitHub tokens survive updates
- **Self-Replace** - Updates running scripts using Windows-compatible indirection
- **Multiple Update Modes**:
  - GitHub Releases (recommended)
  - Direct URL download
  - Archive mode with DEP/ directory
- **Migration Tool** - Migrate existing .cmd scripts to GitHub repos (runs on Mac/Linux)

## Quick Start

### 1. Add Bootstrap to Your Script

Add these lines to your `.cmd` or `.bat` script:

```batch
@echo off
SET SCRIPT_VERSION=1.0.0
SET UPDATE_MODE=github_release
SET GITHUB_USER=YourUsername
SET GITHUB_REPO=YourRepoName
REM SET GITHUB_TOKEN=ghp_xxxxxxxxxxxxx

call :auto_update
REM Your script logic here
exit /b

REM === Auto-Update Bootstrap (40 lines) ===
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

### 2. Set Up GitHub Release Workflow

Add `.github/workflows/release.yml` to your repository:

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

      - name: Extract version and create release
        shell: powershell
        run: |
          $SCRIPT = Get-ChildItem -Filter "*.cmd" | Select -First 1 -ExpandProperty Name
          $CONTENT = Get-Content $SCRIPT -Raw

          if ($CONTENT -match '(?im)^SET SCRIPT_VERSION=(["]?)([^"\r\n]+)\1') {
            $VERSION = $matches[2]
            echo "Version: $VERSION"

            gh release create "v$VERSION" $SCRIPT `
              --title "Release v$VERSION" `
              --notes "Auto-release for version $VERSION" || echo "Release might already exist"
          }
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 3. Push and Release

```powershell
git add .
git commit -m "Add auto-update support"
git push
```

The GitHub Action automatically creates a release when `SCRIPT_VERSION` changes.

## Installation

### Using Bootstrap Minimal (Recommended)

Copy the bootstrap code from `bootstrap/bootstrap_minimal.cmd` into your script. See [examples/example_bootstrap_minimal.cmd](examples/example_bootstrap_minimal.cmd).

### Using Standalone Engine

Download and include `standalone/auto_update_standalone.cmd` in your script.

## Private Repositories

For private repos, add a GitHub token:

```batch
SET GITHUB_TOKEN=ghp_your_personal_access_token
```

The token is automatically preserved during updates. See [docs/SETUP.md](docs/SETUP.md) for token creation instructions.

## Migration Tool

Migrate existing Windows scripts from Mac/Linux:

```bash
./tools/migrate_script_to_repo.sh --script myscript.cmd --repo-name my-repo
```

Creates a new GitHub repository with auto-release workflow configured for Windows.

## Documentation

- [QUICKSTART.md](QUICKSTART.md) - Get started in 5 minutes
- [docs/SETUP.md](docs/SETUP.md) - Detailed setup guide
- [docs/MODES.md](docs/MODES.md) - Update modes explained
- [docs/WINDOWS_SPECIFICS.md](docs/WINDOWS_SPECIFICS.md) - Windows-specific implementation details
- [docs/SCRIPT_MIGRATION.md](docs/SCRIPT_MIGRATION.md) - Migrating scripts to GitHub
- [docs/MIGRATION.md](docs/MIGRATION.md) - Migrating from Bash AutoUpdater

## Architecture

```
User Script (.cmd)
  ├─ SET SCRIPT_VERSION=1.0.0
  ├─ call :auto_update (Bootstrap ~40 lines)
  └─ [User Logic]
         ↓
Bootstrap Minimal (CMD)
  ├─ Cache Check (%TEMP%)
  ├─ Download Engine (curl/PowerShell)
  └─ call engine.cmd
         ↓
Auto-Update Engine (CMD + PowerShell Hybrid)
  ├─ CMD: Flow Control
  ├─ PowerShell: JSON Parse, HTTP
  ├─ Token Preservation
  └─ Self-Replace via Indirection
```

## Requirements

- Windows 10+ (for `curl` support) or Windows 7+ (PowerShell fallback)
- Git (for version control)
- GitHub repository (public or private)

## Differences from Bash AutoUpdater

| Feature | AutoUpdater (Bash) | AutoUpdaterWin (CMD) |
|---------|-------------------|----------------------|
| Bootstrap Size | 30-40 lines | 40-50 lines |
| Cache Location | `/tmp/auto_update_cache` | `%TEMP%\auto_update_cache` |
| Download Tool | `curl` | `curl` or `Invoke-WebRequest` |
| JSON Parsing | `python3`/`jq` | `ConvertFrom-Json` (PowerShell) |
| Self-Replace | Direct overwrite | Indirection via temp script |
| Line Endings | LF | CRLF |

## Examples

- [examples/example_bootstrap_minimal.cmd](examples/example_bootstrap_minimal.cmd) - Minimal bootstrap
- [examples/example_github_release.cmd](examples/example_github_release.cmd) - GitHub release mode
- [examples/example_private_repo.cmd](examples/example_private_repo.cmd) - Private repository with token

## Testing

Run tests on Windows:

```cmd
cd tests
test_all_modes.cmd
```

## Contributing

Contributions welcome! Please read the contributing guidelines and submit pull requests.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Related Projects

- [AutoUpdater](https://github.com/7onnie/AutoUpdater) - Bash version for Linux/macOS

## Support

- Issues: https://github.com/7onnie/AutoUpdaterWin/issues
- Documentation: [docs/](docs/)
