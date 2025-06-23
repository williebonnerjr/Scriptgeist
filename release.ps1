<#
.SYNOPSIS
    Automates versioning, changelog generation, tagging, and GitHub push for Scriptgeist.

.DESCRIPTION
    Suggests a semantic version bump based on recent commit messages.
    Updates Scriptgeist.psd1 with the new version, appends to CHANGELOG.md,
    commits all changes, tags the release, and pushes to GitHub.

.EXAMPLE
    ./release.ps1
    ./release.ps1 -BumpType minor
#>

param (
    [ValidateSet("major", "minor", "patch")]
    [string]$BumpType
)

$ErrorActionPreference = "Stop"
$modulePath = "Scriptgeist.psd1"
$changelog = "CHANGELOG.md"

# Ensure Git is available
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is not installed or not in PATH."
}

# Ensure .psd1 file exists
if (-not (Test-Path $modulePath)) {
    throw "Module manifest '$modulePath' not found."
}

# Create CHANGELOG.md if missing
if (-not (Test-Path $changelog)) {
    New-Item -Path $changelog -ItemType File -Force | Out-Null
    Add-Content $changelog "# Scriptgeist Changelog`n"
    Write-Host "📝 Created new CHANGELOG.md"
}

# Helper: Detect bump type from recent commits
function Get-SuggestedBump {
    $commits = git log --pretty=format:"%s" -n 10

    $majorTerms = @("BREAKING CHANGE", "core rewrite", "architecture")
    $minorTerms = @("feat", "add", "new watcher", "module", "support")
    $patchTerms = @("fix", "typo", "log", "docs", "refactor", "test")

    foreach ($c in $commits) {
        if ($majorTerms | Where-Object { $c -match $_ }) { return "major" }
    }
    foreach ($c in $commits) {
        if ($minorTerms | Where-Object { $c -match $_ }) { return "minor" }
    }
    foreach ($c in $commits) {
        if ($patchTerms | Where-Object { $c -match $_ }) { return "patch" }
    }

    return "patch"
}

# Extract current version from .psd1
$versionLine = Get-Content $modulePath | Where-Object { $_ -match "ModuleVersion\s*=\s*'(\d+)\.(\d+)\.(\d+)'" }
if (-not $versionLine) {
    throw "Could not find ModuleVersion in $modulePath"
}

if ($versionLine -match "'(\d+)\.(\d+)\.(\d+)'") {
    $currentVersion = [int[]]@($Matches[1], $Matches[2], $Matches[3])
} else {
    throw "Unable to parse version from ModuleVersion line."
}
$newVersion = $currentVersion.Clone()

# Determine bump type
if (-not $BumpType) {
    $suggested = Get-SuggestedBump
    Write-Host "`n🔍 Suggested version bump based on recent commits: $suggested" -ForegroundColor Cyan
    $BumpType = Read-Host "Enter bump type to use (press Enter to accept '$suggested')"
    if (-not $BumpType) { $BumpType = $suggested }
}

switch ($BumpType) {
    "major" { $newVersion[0]++; $newVersion[1] = 0; $newVersion[2] = 0 }
    "minor" { $newVersion[1]++; $newVersion[2] = 0 }
    "patch" { $newVersion[2]++ }
    default { throw "Invalid bump type: $BumpType" }
}

$newVersionStr = "$($newVersion[0]).$($newVersion[1]).$($newVersion[2])"

# Update version in .psd1
(Get-Content $modulePath) -replace "'\d+\.\d+\.\d+'", "'$newVersionStr'" |
    Set-Content $modulePath
Write-Host "`n📝 Updated Scriptgeist.psd1 to v$newVersionStr" -ForegroundColor Yellow

# Append to CHANGELOG.md
$date = Get-Date -Format "yyyy-MM-dd"
$recentCommits = git log --pretty=format:"- %s" -n 5
$entry = @"
## v$newVersionStr - $date
$recentCommits

"@
Add-Content $changelog "`n$entry"
Write-Host "🧾 Appended changelog entry for v$newVersionStr" -ForegroundColor Yellow

# Git commit, tag, push
git add .  # add all new and modified files
git commit -m "Release v$newVersionStr"
git tag "v$newVersionStr"
git push origin main --tags

Write-Host "`n🎉 Scriptgeist v$newVersionStr released and pushed to GitHub!" -ForegroundColor Green
