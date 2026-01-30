#!/bin/bash
# ==========================================
# WINDOWS SCRIPT MIGRATION TOOL
# ==========================================
# Migrates Windows CMD/Batch scripts to
# their own GitHub repositories with
# automatic releases.
#
# Runs on Mac/Linux to migrate Windows scripts
#
# Author: Claude Code
# Version: 1.0.0
# Repository: https://github.com/7onnie/AutoUpdaterWin
# ==========================================

set -e  # Exit on error

# ==========================================
# CONFIGURATION
# ==========================================

SCRIPT_VERSION="1.0.0"
GITHUB_USER="7onnie"  # Default GitHub User
DEFAULT_LOCAL_PATH="$HOME/GitHubRepos"
AUTOUPDATER_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE_DIR="$AUTOUPDATER_ROOT/templates"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==========================================
# UTILITY FUNCTIONS
# ==========================================

log_info() {
    echo -e "${BLUE}ℹ️  $*${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $*${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $*${NC}"
}

log_error() {
    echo -e "${RED}❌ $*${NC}"
}

show_help() {
    cat <<EOF
Windows Script Migration Tool v$SCRIPT_VERSION

Migrates Windows CMD/Batch scripts to GitHub repositories with auto-release.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --script PATH           Path to .cmd/.bat script (required)
    --repo-name NAME        GitHub repository name (required)
    --local-path PATH       Local clone path (default: ~/GitHubRepos)
    --private               Create private repository (default)
    --public                Create public repository
    --installer-mode        Create installer script for Share (default)
    --no-installer-mode     Disable installer mode
    --share-token TOKEN     GitHub token for installer (required in installer mode)
    --help                  Show this help

EXAMPLE:
    # CLI mode
    $0 \\
      --script ~/ZS_Share/Scripts/MyScript.cmd \\
      --repo-name my-script-installer \\
      --private

    # Interactive mode
    $0

REQUIREMENTS:
    - GitHub authenticated (gh auth login)
    - gh CLI installed (brew install gh)
    - Script must be prepared:
      * SET SCRIPT_VERSION=x.y.z in header
      * AutoUpdaterWin bootstrap inserted
      * GITHUB_USER and GITHUB_REPO configured

DOCUMENTATION:
    See: $AUTOUPDATER_ROOT/docs/SCRIPT_MIGRATION.md

EOF
}

# ==========================================
# VALIDATION FUNCTIONS
# ==========================================

validate_windows_script() {
    local script_path="$1"

    log_info "Validating Windows script: $script_path"

    # 1. Check if file exists and is .cmd or .bat
    if [[ ! -f "$script_path" ]]; then
        log_error "Script not found: $script_path"
        exit 1
    fi

    if ! [[ "$script_path" =~ \.(cmd|bat)$ ]]; then
        log_error "File must be .cmd or .bat"
        exit 1
    fi

    # 2. Check for @echo off
    if ! grep -qi '^@echo off' "$script_path"; then
        log_warn "@echo off not found (Windows scripts typically start with this)"
    fi

    # 3. Check for SET SCRIPT_VERSION (Windows style, no quotes!)
    if ! grep -Eiq '^SET SCRIPT_VERSION=' "$script_path"; then
        log_error "SET SCRIPT_VERSION= not found in script"
        log_error "Windows scripts require: SET SCRIPT_VERSION=1.0.0 (no quotes!)"
        exit 1
    fi

    # 4. Check for :auto_update label
    if ! grep -q ':auto_update' "$script_path"; then
        log_warn ":auto_update label not found (required for auto-update)"
    fi

    # 5. Check line endings (should be CRLF for Windows)
    if command -v file >/dev/null 2>&1; then
        if ! file "$script_path" | grep -q "CRLF"; then
            log_warn "Script does not have CRLF line endings"
            log_warn "Windows scripts should use CRLF (\\r\\n) line endings"
            log_warn "Git will convert automatically based on .gitattributes"
        fi
    fi

    # 6. Check for AutoUpdaterWin bootstrap
    if ! grep -q 'auto_update_engine.cmd' "$script_path"; then
        log_warn "AutoUpdaterWin bootstrap not found"
        log_warn "Script may not have auto-update capability"
    fi

    log_success "Windows script validation passed"
}

extract_version_windows() {
    local script_path="$1"

    # Extract version from: SET SCRIPT_VERSION=1.0.0
    # Note: Windows style has no quotes around value
    local version=$(grep -Ei '^SET SCRIPT_VERSION=' "$script_path" | head -1 | sed -E 's/^SET SCRIPT_VERSION=["'"'"']?([^"'"'"'\r\n]+)["'"'"']?.*/\1/' | tr -d '\r')

    if [[ -z "$version" ]]; then
        log_error "Could not extract SCRIPT_VERSION from script"
        exit 1
    fi

    echo "$version"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check gh CLI
    if ! command -v gh &> /dev/null; then
        log_error "gh CLI not found. Install with: brew install gh"
        exit 1
    fi

    # Check authentication
    if ! gh auth status &> /dev/null; then
        log_error "GitHub not authenticated. Run: gh auth login"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# ==========================================
# MIGRATION FUNCTIONS
# ==========================================

create_repository() {
    local repo_name="$1"
    local visibility="$2"  # "private" or "public"
    local local_path="$3"

    log_info "Creating GitHub repository: $repo_name"

    # Create local directory
    mkdir -p "$local_path"
    cd "$local_path"

    # Initialize git
    git init

    # Create .gitattributes for Windows line endings
    cat > .gitattributes <<EOF
# AutoUpdaterWin - Git Attributes
# Windows scripts require CRLF line endings

# Windows batch files
*.cmd text eol=crlf
*.bat text eol=crlf

# PowerShell scripts
*.ps1 text eol=crlf

# Documentation
*.md text eol=lf
*.txt text eol=lf
EOF

    # Create .gitignore
    cat > .gitignore <<EOF
# Temporary files
*.tmp
*.bak
*.swp
*~

# Windows
Thumbs.db
Desktop.ini

# macOS
.DS_Store

# Cache
cache/
.cache/

# Test outputs
*.log
EOF

    # Create README
    cat > README.md <<EOF
# $repo_name

Windows batch script with auto-update capability using [AutoUpdaterWin](https://github.com/7onnie/AutoUpdaterWin).

## Usage

Run the script:

\`\`\`cmd
$repo_name.cmd
\`\`\`

The script automatically checks for updates from GitHub releases.

## Auto-Update

This script uses AutoUpdaterWin for automatic updates:

- Checks for new releases on every run
- Downloads and installs updates automatically
- Preserves configuration and tokens
- Creates backup before updating

## Version

Current version is managed via \`SET SCRIPT_VERSION=x.y.z\` in the script.

## License

See LICENSE file.
EOF

    git add .gitattributes .gitignore README.md
    git commit -m "Initial commit: Repository setup"

    # Create GitHub repository
    local visibility_flag=""
    if [[ "$visibility" == "private" ]]; then
        visibility_flag="--private"
    else
        visibility_flag="--public"
    fi

    gh repo create "$repo_name" $visibility_flag --source=. --remote=origin --push

    log_success "Repository created: https://github.com/$GITHUB_USER/$repo_name"
}

copy_and_configure_script() {
    local source_script="$1"
    local target_dir="$2"
    local repo_name="$3"

    log_info "Copying script to repository..."

    local script_name=$(basename "$source_script")
    local target_script="$target_dir/$script_name"

    # Copy script (preserve line endings)
    cp "$source_script" "$target_script"

    # Ensure CRLF line endings (if dos2unix/unix2dos available)
    if command -v unix2dos &> /dev/null; then
        unix2dos "$target_script" 2>/dev/null || true
    fi

    log_success "Script copied: $script_name"

    # Extract version
    local version=$(extract_version_windows "$target_script")
    log_info "Detected version: $version"

    echo "$version"
}

create_github_workflow() {
    local target_dir="$1"
    local script_name="$2"

    log_info "Creating GitHub Actions workflow..."

    mkdir -p "$target_dir/.github/workflows"

    # Create Windows-specific workflow
    cat > "$target_dir/.github/workflows/release.yml" <<'EOF'
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
            Write-Host "ERROR: No .cmd or .bat file found"
            exit 1
          }

          Write-Host "Found script: $SCRIPT"

          # Extract version from SET SCRIPT_VERSION=x.y.z
          $CONTENT = Get-Content $SCRIPT -Raw

          if ($CONTENT -match '(?im)^SET\s+SCRIPT_VERSION=(["]?)([^"\r\n]+)\1') {
            $VERSION = $matches[2].Trim()
            Write-Host "Current version: $VERSION"

            # Check if this version already has a release
            $EXISTING = gh release view "v$VERSION" 2>&1
            if ($LASTEXITCODE -eq 0) {
              Write-Host "Release v$VERSION already exists, skipping"
              exit 0
            }

            # Create release
            Write-Host "Creating release v$VERSION..."
            gh release create "v$VERSION" $SCRIPT `
              --title "Release v$VERSION" `
              --notes "Automatic release for version $VERSION" `
              --latest

            if ($LASTEXITCODE -eq 0) {
              Write-Host "✅ Release v$VERSION created successfully"
            } else {
              Write-Host "❌ Failed to create release"
              exit 1
            }
          } else {
            Write-Host "ERROR: SCRIPT_VERSION not found in $SCRIPT"
            Write-Host "Expected format: SET SCRIPT_VERSION=1.0.0"
            exit 1
          }
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
EOF

    log_success "GitHub Actions workflow created"
}

create_installer_script() {
    local target_dir="$1"
    local repo_name="$2"
    local share_token="$3"

    log_info "Creating installer script for Share..."

    local installer_name="${repo_name}-installer.cmd"

    cat > "$target_dir/$installer_name" <<EOF
@echo off
REM ============================================================================
REM Installer Script for $repo_name
REM ============================================================================
REM This installer downloads the latest version from GitHub
REM Designed to run from ZS_Share
REM
REM Version: 0.0.0 (Installer always version 0.0.0)
REM ============================================================================

SET SCRIPT_VERSION=0.0.0
SET UPDATE_MODE=github_release
SET GITHUB_USER=$GITHUB_USER
SET GITHUB_REPO=$repo_name
SET GITHUB_TOKEN=$share_token

call :auto_update

REM After update, the real script takes over
exit /b

REM === Auto-Update Bootstrap ===
:auto_update
    set ENGINE_URL=https://raw.githubusercontent.com/7onnie/AutoUpdaterWin/main/lib/auto_update_engine.cmd
    set CACHE_DIR=%TEMP%\auto_update_cache
    set CACHE_FILE=%CACHE_DIR%\engine.cmd
    set CACHE_LIFETIME_MIN=1440

    if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%"

    REM Check cache validity
    if exist "%CACHE_FILE%" (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "\$cache='%CACHE_FILE%'; if (Test-Path \$cache) { \$age = (New-TimeSpan -Start (Get-Item \$cache).LastWriteTime -End (Get-Date)).TotalMinutes; if (\$age -lt %CACHE_LIFETIME_MIN%) { exit 0 } }; exit 1" >nul 2>&1
        if %ERRORLEVEL% equ 0 (
            call "%CACHE_FILE%"
            if not errorlevel 1 (
                call :_auto_update_main
                exit /b %ERRORLEVEL%
            )
        )
    )

    REM Download engine
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
EOF

    # Convert to CRLF if possible
    if command -v unix2dos &> /dev/null; then
        unix2dos "$target_dir/$installer_name" 2>/dev/null || true
    fi

    log_success "Installer script created: $installer_name"
}

# ==========================================
# MAIN MIGRATION WORKFLOW
# ==========================================

migrate_script() {
    local script_path="$1"
    local repo_name="$2"
    local local_path="$3"
    local visibility="$4"
    local installer_mode="$5"
    local share_token="$6"

    log_info "Starting migration process..."
    log_info "Script: $script_path"
    log_info "Repository: $repo_name"
    log_info "Visibility: $visibility"

    # Validate script
    validate_windows_script "$script_path"

    # Create repository
    local repo_path="$local_path/$repo_name"
    create_repository "$repo_name" "$visibility" "$repo_path"

    # Copy script
    local version=$(copy_and_configure_script "$script_path" "$repo_path" "$repo_name")

    # Create GitHub workflow
    local script_name=$(basename "$script_path")
    create_github_workflow "$repo_path" "$script_name"

    # Create installer if requested
    if [[ "$installer_mode" == "yes" ]]; then
        if [[ -z "$share_token" ]]; then
            log_warn "No share token provided, skipping installer creation"
        else
            create_installer_script "$repo_path" "$repo_name" "$share_token"
        fi
    fi

    # Commit and push
    cd "$repo_path"
    git add .
    git commit -m "Add script and workflow v$version"
    git push origin main

    # Create initial release
    log_info "Creating initial release v$version..."
    gh release create "v$version" "$script_name" \
        --title "Release v$version" \
        --notes "Initial release of $repo_name" \
        --latest || log_warn "Release creation failed (may need to be done manually)"

    log_success "Migration completed successfully!"
    log_success "Repository: https://github.com/$GITHUB_USER/$repo_name"
    log_success "Local path: $repo_path"
}

# ==========================================
# INTERACTIVE MODE
# ==========================================

interactive_mode() {
    echo ""
    echo "=========================================="
    echo "  Windows Script Migration - Interactive"
    echo "=========================================="
    echo ""

    # Get script path
    read -p "Path to Windows script (.cmd/.bat): " script_path
    script_path="${script_path/#\~/$HOME}"  # Expand ~

    if [[ ! -f "$script_path" ]]; then
        log_error "Script not found: $script_path"
        exit 1
    fi

    # Get repository name
    local default_repo_name=$(basename "$script_path" .cmd)
    default_repo_name=$(basename "$default_repo_name" .bat)
    read -p "Repository name [$default_repo_name]: " repo_name
    repo_name="${repo_name:-$default_repo_name}"

    # Get local path
    read -p "Local clone path [$DEFAULT_LOCAL_PATH]: " local_path
    local_path="${local_path:-$DEFAULT_LOCAL_PATH}"
    local_path="${local_path/#\~/$HOME}"

    # Get visibility
    read -p "Repository visibility (private/public) [private]: " visibility
    visibility="${visibility:-private}"

    # Installer mode
    read -p "Create installer for Share? (y/n) [y]: " installer_choice
    installer_choice="${installer_choice:-y}"

    local installer_mode="no"
    local share_token=""

    if [[ "$installer_choice" =~ ^[Yy] ]]; then
        installer_mode="yes"
        read -p "GitHub token for Share installer: " share_token
    fi

    # Confirm
    echo ""
    echo "Summary:"
    echo "  Script:     $script_path"
    echo "  Repository: $repo_name"
    echo "  Visibility: $visibility"
    echo "  Installer:  $installer_mode"
    echo ""
    read -p "Proceed with migration? (y/n): " confirm

    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        log_info "Migration cancelled"
        exit 0
    fi

    migrate_script "$script_path" "$repo_name" "$local_path" "$visibility" "$installer_mode" "$share_token"
}

# ==========================================
# MAIN
# ==========================================

main() {
    # Parse command line arguments
    local script_path=""
    local repo_name=""
    local local_path="$DEFAULT_LOCAL_PATH"
    local visibility="private"
    local installer_mode="yes"
    local share_token=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --script)
                script_path="$2"
                shift 2
                ;;
            --repo-name)
                repo_name="$2"
                shift 2
                ;;
            --local-path)
                local_path="$2"
                shift 2
                ;;
            --private)
                visibility="private"
                shift
                ;;
            --public)
                visibility="public"
                shift
                ;;
            --installer-mode)
                installer_mode="yes"
                shift
                ;;
            --no-installer-mode)
                installer_mode="no"
                shift
                ;;
            --share-token)
                share_token="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Check prerequisites
    check_prerequisites

    # If no arguments, run interactive mode
    if [[ -z "$script_path" ]] || [[ -z "$repo_name" ]]; then
        interactive_mode
    else
        migrate_script "$script_path" "$repo_name" "$local_path" "$visibility" "$installer_mode" "$share_token"
    fi
}

# Run main
main "$@"
