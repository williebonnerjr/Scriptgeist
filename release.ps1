<#
.SYNOPSIS
    Automates versioning, changelog, tagging, and GitHub push for Scriptgeist.

.DESCRIPTION
    Suggests version bump based on recent commit messages,
    updates .psd1 and CHANGELOG.md, and pushes everything to GitHub.

.EXAMPLE
    ./release.ps1
#>

param (
    [ValidateSet("major", "minor", "patch")]
    [string]$BumpType
)

$ErrorActionPreference = "Stop"
$modulePath = "Scriptgeist.psd1"
$changelog = "CHANGELOG.md"

# Helper: Detect bump type from recent commits
function Get-SuggestedBump {
    $commits = git log --pretty=format:"%s" -n 10

    $majorTerms = @("BREAKING CHANGE", "core rewrite", "architecture")
    $minorTerms = @("feat", "add", "new watcher", "module")
    $patchTerms = @("fix", "typo", "log", "docs", "refactor")

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

# Get current version
$versionLine = Get-Content $modulePath | Where-Object { $_ -match "ModuleVersion\s*=\s*'(\d+)\.(\d+)\.(\d+)'" }
if (-not $versionLine) {
    throw "Could not find ModuleVersion in $modulePath"
}

[void]($versionLine -match "'(\d+)\.(\d+)\.(\d+)'")
$currentVersion = [int[]]@($Matches[1], $Matches[2], $Matches[3])
$newVersion = $currentVersion.Clone()

# Determine bump
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

# Update .psd1
(Get-Content $modulePath) -replace "'\d+\.\d+\.\d+'", "'$newVersionStr'" |
    Set-Content $modulePath

# Create changelog entry
$date = Get-Date -Format "yyyy-MM-dd"
$recentCommits = git log --pretty=format:"- %s" -n 5
$entry = @"
## v$newVersionStr - $date
$recentCommits

"@
Add-Content $changelog "`n$entry"

# Git commit, tag, push
git add $modulePath $changelog
git commit -m "Release v$newVersionStr"
git tag "v$newVersionStr"
git push origin main --tags

Write-Host "`n🎉 Scriptgeist v$newVersionStr released and pushed!" -ForegroundColor Green
