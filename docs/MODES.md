# Update Modes

AutoUpdaterWin supports multiple update modes for different use cases.

## Table of Contents

1. [GitHub Release Mode](#github-release-mode) (Recommended)
2. [Direct URL Mode](#direct-url-mode)
3. [Archive Mode](#archive-mode) (Planned)
4. [Installer Mode](#installer-mode)
5. [Mode Comparison](#mode-comparison)

---

## GitHub Release Mode

**Recommended for most use cases.**

### Overview

Scripts automatically update from GitHub releases. When you push a new version, GitHub Actions creates a release, and users' scripts auto-update.

### Configuration

```batch
SET UPDATE_MODE=github_release
SET GITHUB_USER=YourUsername
SET GITHUB_REPO=YourRepoName
SET GITHUB_TOKEN=ghp_xxx  REM Optional, for private repos
```

### How It Works

```
1. Script starts
   └─> Bootstrap loads engine

2. Engine checks GitHub API
   └─> GET https://api.github.com/repos/USER/REPO/releases/latest

3. Compare versions
   └─> Current: 1.0.0
   └─> Latest:  1.0.1
   └─> Update available!

4. Download release asset
   └─> GET https://github.com/USER/REPO/releases/download/v1.0.1/script.cmd

5. Self-replace
   └─> Backup old version
   └─> Install new version
   └─> Restart script

6. Script continues with new version
```

### Advantages

- ✅ **Automatic**: Push and forget
- ✅ **Version control**: GitHub tracks all versions
- ✅ **Rollback**: Easy to revert to older releases
- ✅ **Private repo support**: Works with GITHUB_TOKEN
- ✅ **GitHub UI**: Download releases manually via web
- ✅ **Multiple assets**: Can include documentation, etc.

### Disadvantages

- ⚠️ Requires GitHub repository
- ⚠️ Needs GitHub Actions setup
- ⚠️ Internet connection required

### Setup

#### 1. Configure Script

```batch
@echo off
SET SCRIPT_VERSION=1.0.0
SET UPDATE_MODE=github_release
SET GITHUB_USER=myusername
SET GITHUB_REPO=my-script

call :auto_update
REM Script logic...
exit /b 0

:auto_update
    REM Bootstrap code...
```

#### 2. Create GitHub Actions Workflow

`.github/workflows/release.yml`:

```yaml
name: Auto Release

on:
  push:
    branches: [ main ]
    paths: ['*.cmd', '*.bat']

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

#### 3. Push Changes

```cmd
git add .
git commit -m "Add auto-update"
git push
```

### Private Repositories

Add GitHub token:

```batch
SET GITHUB_TOKEN=ghp_xxxxxxxxxxxxx
```

Create token at: https://github.com/settings/tokens
- Scope: `repo` (for private repos)

Token is automatically preserved during updates.

### Example

See: [examples/example_github_release.cmd](../examples/example_github_release.cmd)

---

## Direct URL Mode

Download script directly from a URL.

### Overview

Script always downloads the latest version from a fixed URL. No version checking - always replaces itself.

### Configuration

```batch
SET UPDATE_MODE=direct_url
SET UPDATE_URL=https://example.com/myscript.cmd
```

### How It Works

```
1. Script starts
   └─> Bootstrap loads engine

2. Download from URL
   └─> GET https://example.com/myscript.cmd

3. Self-replace
   └─> Backup old version
   └─> Install new version
   └─> Restart script

4. Script continues
```

### Advantages

- ✅ **Simple**: Just a URL
- ✅ **No GitHub needed**: Works with any web server
- ✅ **Fast**: No API calls, direct download
- ✅ **Flexible**: Host anywhere (Dropbox, CDN, etc.)

### Disadvantages

- ⚠️ No version checking (always updates)
- ⚠️ No rollback capability
- ⚠️ Requires manual version management
- ⚠️ No release history

### Use Cases

1. **Internal servers**:
   ```batch
   SET UPDATE_URL=http://intranet.company.com/scripts/tool.cmd
   ```

2. **Cloud storage** (public link):
   ```batch
   SET UPDATE_URL=https://dl.dropboxusercontent.com/s/xxx/script.cmd
   ```

3. **CDN**:
   ```batch
   SET UPDATE_URL=https://cdn.example.com/latest/tool.cmd
   ```

4. **Raw GitHub** (not recommended - use release mode):
   ```batch
   SET UPDATE_URL=https://raw.githubusercontent.com/user/repo/main/script.cmd
   ```

### Configuration Example

```batch
@echo off
SET SCRIPT_VERSION=1.0.0  REM Still useful for tracking
SET UPDATE_MODE=direct_url
SET UPDATE_URL=https://example.com/latest/myscript.cmd

call :auto_update
echo Running script...
exit /b 0

:auto_update
    REM Bootstrap code...
```

### Considerations

**Always updates:**
- No version comparison
- Downloads every time (unless cached)
- Be careful with rapid updates

**Cache still applies:**
- Engine cached for 24h by default
- Script checks for update on each run
- Set `CACHE_LIFETIME_MIN` to control frequency

**Authentication:**
- For authenticated URLs, modify PowerShell helpers
- Or use pre-authenticated URLs (signed URLs, tokens in URL)

---

## Archive Mode

**Status:** Planned for future release

### Concept

Download script from archive file (ZIP) with dependency folder (`DEP/`).

### Planned Configuration

```batch
SET UPDATE_MODE=archive
SET ARCHIVE_URL=https://example.com/releases/v1.0.0.zip
SET ARCHIVE_SCRIPT=tool.cmd
SET ARCHIVE_EXTRACT_DEP=yes  REM Extract DEP/ folder
```

### Planned Features

- Extract `.cmd` and dependencies from ZIP
- Preserve `DEP/` directory structure
- Support for bundled resources
- Version checking via manifest file

### Current Status

Not yet implemented. Use GitHub Release mode for now.

---

## Installer Mode

Special mode for initial installation from network shares (e.g., ZS_Share).

### Overview

"Installer script" with `VERSION=0.0.0` that always downloads the latest version from GitHub.

### Configuration

```batch
SET SCRIPT_VERSION=0.0.0  REM Special: Installer mode
SET UPDATE_MODE=github_release
SET GITHUB_USER=YourUsername
SET GITHUB_REPO=YourRepoName
SET GITHUB_TOKEN=ghp_xxx  REM Hardcoded for Share
```

### How It Works

```
1. User runs installer from Share
   └─> myscript-installer.cmd

2. Script detects VERSION=0.0.0
   └─> Installer mode activated

3. Downloads latest release
   └─> GET latest from GitHub

4. Replaces itself with real script
   └─> Overwrites 0.0.0 with 1.0.0

5. Real script runs
   └─> Full functionality available

6. Future runs use normal update mode
```

### Advantages

- ✅ Single file in Share
- ✅ Always installs latest version
- ✅ Token embedded (for private repos)
- ✅ No manual downloads needed
- ✅ Self-updating after installation

### Use Case: ZS_Share

**Scenario:**
- Private script in GitHub
- Multiple users on network
- Want easy distribution

**Solution:**

1. Create installer script:
   ```batch
   REM myscript-installer.cmd
   SET SCRIPT_VERSION=0.0.0
   SET UPDATE_MODE=github_release
   SET GITHUB_USER=company
   SET GITHUB_REPO=internal-tool
   SET GITHUB_TOKEN=ghp_company_token

   call :auto_update
   exit /b 0

   :auto_update
       REM Bootstrap...
   ```

2. Place in Share:
   ```
   \\share\Scripts\myscript-installer.cmd
   ```

3. Users run:
   ```cmd
   \\share\Scripts\myscript-installer.cmd
   ```

4. First run:
   - Downloads latest v1.2.3
   - Replaces installer
   - Runs real script

5. Subsequent runs:
   - Normal update checks
   - Auto-updates when new version available

### Migration Tool Support

Generate installer with migration tool:

```bash
./tools/migrate_script_to_repo.sh \
  --script myscript.cmd \
  --repo-name myscript \
  --private \
  --installer-mode \
  --share-token ghp_xxx
```

Creates `myscript-installer.cmd` with:
- `SCRIPT_VERSION=0.0.0`
- Hardcoded token
- Auto-update bootstrap

---

## Mode Comparison

| Feature | GitHub Release | Direct URL | Archive | Installer |
|---------|---------------|------------|---------|-----------|
| **Version checking** | ✅ Yes | ❌ No | 🔄 Planned | ✅ Yes |
| **Requires GitHub** | ✅ Yes | ❌ No | ❌ No | ✅ Yes |
| **Private repo support** | ✅ Yes | ⚠️ Manual | 🔄 Planned | ✅ Yes |
| **Rollback** | ✅ Easy | ❌ Hard | 🔄 Planned | ❌ N/A |
| **Setup complexity** | Medium | Low | 🔄 Planned | Low |
| **Best for** | Main use | Simple needs | Dependencies | Share distribution |

---

## Switching Modes

You can change update mode by editing configuration:

```batch
REM Old:
SET UPDATE_MODE=direct_url
SET UPDATE_URL=https://example.com/script.cmd

REM New:
SET UPDATE_MODE=github_release
SET GITHUB_USER=myuser
SET GITHUB_REPO=myscript
```

Next run will use new mode.

---

## Recommendations

### Use GitHub Release Mode if:
- ✅ You have a GitHub account
- ✅ You want version control
- ✅ You need private repo support
- ✅ You want easy rollback

### Use Direct URL Mode if:
- ✅ Simple deployment needed
- ✅ No GitHub available
- ✅ Hosting on internal server
- ✅ Version checking not important

### Use Installer Mode if:
- ✅ Distributing via network share
- ✅ Private repo with token
- ✅ Want easy first-time setup
- ✅ Users should always get latest

---

## Future Modes

Planned for future releases:

- **Archive Mode**: ZIP files with dependencies
- **Delta Update Mode**: Only download changes
- **Signed Update Mode**: GPG signature verification
- **Multiple Source Mode**: Fallback URLs

---

## Related Documentation

- [SETUP.md](SETUP.md) - Setup guide
- [WINDOWS_SPECIFICS.md](WINDOWS_SPECIFICS.md) - Implementation details
- [examples/](../examples/) - Example scripts
- [README.md](../README.md) - Main documentation
