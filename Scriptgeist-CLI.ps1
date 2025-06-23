param (
    [string]$Module,
    [string[]]$ModuleArgs,
    [switch]$List,
    [switch]$Help
)

function Show-Help {
    Write-Host "Scriptgeist CLI Help" -ForegroundColor Cyan
    Write-Host "Usage:"
    Write-Host "  Scriptgeist-CLI.ps1 -List"
    Write-Host "  Scriptgeist-CLI.ps1 -Module <ModuleName> [-ModuleArgs '<args>']"
    Write-Host "  Scriptgeist-CLI.ps1 -Module All [-ModuleArgs '<args>']"
    Write-Host "  Scriptgeist-CLI.ps1 -Help"
    Write-Host "`nExamples:"
    Write-Host "  ./Scriptgeist-CLI.ps1 -Module Watch-LogTampering"
    Write-Host "  ./Scriptgeist-CLI.ps1 -Module Watch-SystemLogs -ModuleArgs '-AttentionOnly','-OutputPrompt'"
    Write-Host "  ./Scriptgeist-CLI.ps1 -Module All -ModuleArgs '-AttentionOnly'"
    exit
}

if ($Help -or (-not $Module -and -not $List)) {
    Show-Help
}

# Safe fallback for script root
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

# Setup required paths
$moduleRoot = Join-Path $scriptRoot "Modules"
$logRoot = Join-Path $scriptRoot "Logs"
if (-not (Test-Path $logRoot)) {
    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
}

# Discover modules
$moduleFiles = Get-ChildItem -Path $moduleRoot -Recurse -Filter "Watch-*.ps1" -File
$modules = $moduleFiles | ForEach-Object {
    [PSCustomObject]@{
        Name  = $_.BaseName
        Path  = $_.FullName
        Group = $_.Directory.Name
    }
}

# List available modules
if ($List) {
    Write-Host "`nAvailable Scriptgeist Modules:`n" -ForegroundColor Green
    $modules | Sort-Object Group, Name | ForEach-Object {
        Write-Host "- [$($_.Group)] $($_.Name)"
    }
    exit
}

# Run all modules in background jobs
if ($Module -ieq "All") {
    Write-Host "`n[*] Executing all Scriptgeist modules..." -ForegroundColor Cyan

    foreach ($mod in $modules) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $logPath = Join-Path $logRoot "CLI-$($mod.Name)-$timestamp.log"

        Write-Host "[+] Launching: $($mod.Name)" -ForegroundColor Yellow
        try {
            Start-Job -ScriptBlock {
                param($path, $modArgs, $log)
                & powershell -NoProfile -ExecutionPolicy Bypass -File $path @modArgs *>> $log
            } -ArgumentList $mod.Path, $ModuleArgs, $logPath
        } catch {
            Write-Warning "Failed to start job for $($mod.Name): $_"
        }
    }

    Write-Host "`n[✓] All modules launched in background jobs. Logs will be stored in 'Logs\' folder." -ForegroundColor Green
    exit
}

# Run selected module
if ($Module) {
    $selected = $modules | Where-Object { $_.Name -ieq $Module }
    if (-not $selected) {
        Write-Warning "Module '$Module' not found. Use -List to view available modules."
        exit 1
    }

    if (-not (Test-Path $selected.Path)) {
        Write-Warning "Script not found at: $($selected.Path)"
        exit 1
    }

    if (-not $ModuleArgs) {
        $argInput = Read-Host "Enter arguments for $($selected.Name) (or press Enter for none)"
        $ModuleArgs = if ($argInput) { $argInput -split '\s+' } else { @() }
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $logPath = Join-Path $logRoot "CLI-$($selected.Name)-$timestamp.log"

    Write-Host "`n[*] Executing $($selected.Name)..." -ForegroundColor Yellow
    Write-Host "[*] Logging to: $logPath`n"

    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $selected.Path @ModuleArgs *>> $logPath
        Write-Host "`n[✓] Execution completed. Output logged to: $logPath" -ForegroundColor Green
    } catch {
        Write-Warning "Error occurred while executing $($selected.Name): $_"
        Add-Content -Path $logPath -Value "ERROR: $_"
    }
}
