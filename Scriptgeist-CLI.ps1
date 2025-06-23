param (
    [string]$Run,
    [string]$ModuleArgs,
    [switch]$List,
    [switch]$Help
)

function Show-Help {
    Write-Host "Scriptgeist CLI Help" -ForegroundColor Cyan
    Write-Host "Usage:"
    Write-Host "  Scriptgeist-CLI.ps1 --list"
    Write-Host "  Scriptgeist-CLI.ps1 --run <ModuleName> [--ModuleArgs '<args>']"
    Write-Host "  Scriptgeist-CLI.ps1 --help"
    Write-Host "`nExamples:"
    Write-Host "  ./Scriptgeist-CLI.ps1 --run Watch-LogTampering"
    Write-Host "  ./Scriptgeist-CLI.ps1 --run Watch-SystemLogs --ModuleArgs '-AttentionOnly -OutputPrompt'"
    exit
}

if ($Help -or (-not $Run -and -not $List)) {
    Show-Help
}

# Load modules
$moduleRoot = Join-Path $PSScriptRoot "Modules"
$logRoot = Join-Path $PSScriptRoot "Logs"
if (-not (Test-Path $logRoot)) { New-Item -ItemType Directory -Path $logRoot | Out-Null }

$moduleFiles = Get-ChildItem -Path $moduleRoot -Recurse -Filter "Watch-*.ps1" -File

$modules = $moduleFiles | ForEach-Object {
    [PSCustomObject]@{
        Name = $_.BaseName
        Path = $_.FullName
        Group = $_.Directory.Name
    }
}

if ($List) {
    Write-Host "`nAvailable Scriptgeist Modules:`n" -ForegroundColor Green
    $modules | Sort-Object Group, Name | ForEach-Object {
        Write-Host "- [$($_.Group)] $($_.Name)"
    }
    exit
}

if ($Run) {
    $selected = $modules | Where-Object { $_.Name -ieq $Run }
    if (-not $selected) {
        Write-Warning "Module '$Run' not found. Use --list to view available modules."
        exit 1
    }

    if (-not (Test-Path $selected.Path)) {
        Write-Warning "Script not found at: $($selected.Path)"
        exit 1
    }

    # Prompt for arguments if missing
    if (-not $ModuleArgs) {
        $ModuleArgs = Read-Host "Enter arguments for $($selected.Name) (or press Enter for none)"
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $logPath = Join-Path $logRoot "CLI-$($selected.Name)-$timestamp.log"

    Write-Host "`n[*] Executing $($selected.Name)..." -ForegroundColor Yellow
    Write-Host "[*] Logging to: $logPath`n"

    $splitArgs = $ModuleArgs -split '\s+'
    
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $selected.Path @splitArgs *>> $logPath
        Write-Host "`n[✓] Execution completed. Output logged to: $logPath" -ForegroundColor Green
    } catch {
        Write-Warning "Error occurred: $_"
        Add-Content -Path $logPath -Value "ERROR: $_"
    }
}
