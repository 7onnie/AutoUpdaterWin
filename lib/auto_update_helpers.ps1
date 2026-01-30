# ============================================================================
# AutoUpdaterWin - PowerShell Helper Functions
# ============================================================================
# These functions provide complex operations that CMD cannot easily handle:
#   - JSON parsing from GitHub API
#   - Token preservation with regex
#   - HTTP downloads with authentication headers
#   - Version comparison (semantic versioning)
# ============================================================================

# ----------------------------------------------------------------------------
# Function: Get-LatestRelease
# ----------------------------------------------------------------------------
# Queries GitHub API for the latest release and returns release info
#
# Parameters:
#   $User      - GitHub username
#   $Repo      - Repository name
#   $Token     - GitHub token (optional, for private repos)
#
# Returns: PSObject with properties:
#   tag_name        - Version tag (e.g., "v1.0.0")
#   version         - Clean version without 'v' prefix
#   asset_url       - Download URL for the script asset
#   asset_name      - Filename of the asset
#   release_name    - Name of the release
#   published_at    - Publication date
#
function Get-LatestRelease {
    param(
        [Parameter(Mandatory=$true)]
        [string]$User,

        [Parameter(Mandatory=$true)]
        [string]$Repo,

        [Parameter(Mandatory=$false)]
        [string]$Token = ""
    )

    $apiUrl = "https://api.github.com/repos/$User/$Repo/releases/latest"

    try {
        # Prepare headers
        $headers = @{
            "Accept" = "application/vnd.github+json"
            "User-Agent" = "AutoUpdaterWin/1.0"
        }

        if ($Token) {
            $headers["Authorization"] = "Bearer $Token"
        }

        # Fetch release info
        $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -UseBasicParsing

        # Extract first asset (should be the script)
        $asset = $response.assets | Select-Object -First 1

        if (-not $asset) {
            Write-Error "No assets found in release"
            return $null
        }

        # Extract version (remove 'v' prefix if present)
        $version = $response.tag_name -replace '^v', ''

        # Return structured data
        return [PSCustomObject]@{
            tag_name     = $response.tag_name
            version      = $version
            asset_url    = $asset.browser_download_url
            asset_name   = $asset.name
            release_name = $response.name
            published_at = $response.published_at
        }

    } catch {
        Write-Error "Failed to fetch release: $_"
        return $null
    }
}

# ----------------------------------------------------------------------------
# Function: Preserve-GitHubToken
# ----------------------------------------------------------------------------
# Extracts GitHub token from old script and injects it into new content
#
# Parameters:
#   $OldScriptPath - Path to the current script
#   $NewContent    - New script content (string)
#
# Returns: Modified content with preserved token
#
function Preserve-GitHubToken {
    param(
        [Parameter(Mandatory=$true)]
        [string]$OldScriptPath,

        [Parameter(Mandatory=$true)]
        [string]$NewContent
    )

    try {
        if (-not (Test-Path $OldScriptPath)) {
            Write-Warning "Old script not found: $OldScriptPath"
            return $NewContent
        }

        $oldContent = Get-Content $OldScriptPath -Raw

        # Extract token from old script
        # Matches: SET GITHUB_TOKEN=value or SET GITHUB_TOKEN="value"
        if ($oldContent -match '(?im)^SET\s+GITHUB_TOKEN=(["]?)([^"\r\n]+)\1') {
            $oldToken = $matches[2].Trim()

            # Only preserve if it's an actual token (starts with ghp_ or github_pat_)
            if ($oldToken -match '^(ghp_|github_pat_|gho_|ghu_|ghs_|ghr_)') {
                Write-Host "[AutoUpdate] Preserving GitHub token"

                # Replace token in new content
                # Match both quoted and unquoted variants
                $NewContent = $NewContent -replace '(?im)^(SET\s+GITHUB_TOKEN=)(["]?)([^"\r\n]*)\2', "`$1$oldToken"
            }
        }

        return $NewContent

    } catch {
        Write-Warning "Failed to preserve token: $_"
        return $NewContent
    }
}

# ----------------------------------------------------------------------------
# Function: Download-FileWithAuth
# ----------------------------------------------------------------------------
# Downloads a file with optional GitHub authentication
#
# Parameters:
#   $Url           - Download URL
#   $OutFile       - Destination file path
#   $Token         - GitHub token (optional)
#
# Returns: $true on success, $false on failure
#
function Download-FileWithAuth {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,

        [Parameter(Mandatory=$true)]
        [string]$OutFile,

        [Parameter(Mandatory=$false)]
        [string]$Token = ""
    )

    try {
        $headers = @{
            "User-Agent" = "AutoUpdaterWin/1.0"
        }

        if ($Token) {
            $headers["Authorization"] = "Bearer $Token"
        }

        Invoke-WebRequest -Uri $Url -OutFile $OutFile -Headers $headers -UseBasicParsing | Out-Null

        if (Test-Path $OutFile) {
            return $true
        }

        return $false

    } catch {
        Write-Error "Download failed: $_"
        return $false
    }
}

# ----------------------------------------------------------------------------
# Function: Compare-Versions
# ----------------------------------------------------------------------------
# Compares two semantic version strings
#
# Parameters:
#   $Version1 - First version (e.g., "1.0.0")
#   $Version2 - Second version (e.g., "1.0.1")
#
# Returns:
#   -1 if Version1 < Version2
#    0 if Version1 = Version2
#    1 if Version1 > Version2
#
function Compare-Versions {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Version1,

        [Parameter(Mandatory=$true)]
        [string]$Version2
    )

    try {
        # Remove 'v' prefix if present
        $v1 = $Version1 -replace '^v', ''
        $v2 = $Version2 -replace '^v', ''

        # Split into components
        $v1Parts = $v1 -split '\.' | ForEach-Object { [int]$_ }
        $v2Parts = $v2 -split '\.' | ForEach-Object { [int]$_ }

        # Compare major, minor, patch
        for ($i = 0; $i -lt [Math]::Max($v1Parts.Count, $v2Parts.Count); $i++) {
            $part1 = if ($i -lt $v1Parts.Count) { $v1Parts[$i] } else { 0 }
            $part2 = if ($i -lt $v2Parts.Count) { $v2Parts[$i] } else { 0 }

            if ($part1 -lt $part2) { return -1 }
            if ($part1 -gt $part2) { return 1 }
        }

        return 0

    } catch {
        Write-Warning "Version comparison failed: $_"
        return 0
    }
}

# ----------------------------------------------------------------------------
# Function: Test-CacheValid
# ----------------------------------------------------------------------------
# Checks if a cached file is still valid based on age
#
# Parameters:
#   $FilePath      - Path to cached file
#   $MaxAgeMinutes - Maximum age in minutes
#
# Returns: $true if cache is valid, $false otherwise
#
function Test-CacheValid {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [int]$MaxAgeMinutes
    )

    if (-not (Test-Path $FilePath)) {
        return $false
    }

    try {
        $fileInfo = Get-Item $FilePath
        $age = (New-TimeSpan -Start $fileInfo.LastWriteTime -End (Get-Date)).TotalMinutes

        return ($age -lt $MaxAgeMinutes)

    } catch {
        return $false
    }
}

# ----------------------------------------------------------------------------
# Function: Write-OutputForBatch
# ----------------------------------------------------------------------------
# Writes output in a format that CMD can parse
# Format: KEY=VALUE (one per line)
#
# Parameters:
#   $Data - Hashtable or PSObject with key-value pairs
#
function Write-OutputForBatch {
    param(
        [Parameter(Mandatory=$true)]
        $Data
    )

    if ($Data -is [hashtable]) {
        foreach ($key in $Data.Keys) {
            Write-Output "$key=$($Data[$key])"
        }
    } elseif ($Data -is [PSCustomObject]) {
        $Data.PSObject.Properties | ForEach-Object {
            Write-Output "$($_.Name)=$($_.Value)"
        }
    }
}

# ============================================================================
# Export functions for use in CMD scripts
# ============================================================================

# When called directly with -Command parameter from CMD, execute the function
if ($args.Count -gt 0) {
    $functionName = $args[0]
    $functionArgs = $args[1..($args.Count-1)]

    if (Get-Command $functionName -ErrorAction SilentlyContinue) {
        & $functionName @functionArgs
    }
}
