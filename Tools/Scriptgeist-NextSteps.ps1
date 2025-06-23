function New-ModuleIndex {
    <#
    .SYNOPSIS
    Creates an auto-generated index of all Scriptgeist modules.

    .DESCRIPTION
    Scans the Scriptgeist Modules directory for all .ps1 files and builds a categorized index grouped by logical role (Monitor, Watch, Responder, Utility, etc.).

    .EXAMPLE
    New-ModuleIndex
    # Outputs a formatted index of Scriptgeist modules.
    #>

    [CmdletBinding()]
    param ()

    $basePath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $modulesPath = Join-Path $basePath "Modules"

    if (-not (Test-Path $modulesPath)) {
        Write-Warning "Modules directory not found: $modulesPath"
        return
    }

    Write-Host "📦 Building Scriptgeist module index..." -ForegroundColor Cyan
    $index = @{}

    Get-ChildItem -Path $modulesPath -Recurse -Filter '*.ps1' | ForEach-Object {
        $relativePath = $_.FullName.Replace($basePath, '').TrimStart('\','/')
        $category = ($_ | Split-Path -Parent | Split-Path -Leaf)

        if (-not $index.ContainsKey($category)) {
            $index[$category] = @()
        }

        $index[$category] += $relativePath
    }

    foreach ($group in $index.Keys | Sort-Object) {
        Write-Host "`n📁 $group Modules" -ForegroundColor Yellow
        $index[$group] | Sort-Object | ForEach-Object {
            Write-Host "  - $_"
        }
    }

    Write-Host "`n✅ Module index generation complete." -ForegroundColor Green
}
