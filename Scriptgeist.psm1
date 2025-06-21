# ============================
# Scriptgeist.psm1 - Core Loader and Launcher
# ============================

# Prevent duplication when reloading
Remove-Item function:Show-GeistNotification -ErrorAction SilentlyContinue

# ============================
# Utility: Cross-Platform Notification
# ============================
function Show-GeistNotification {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Message
    )

    if ($IsWindows) {
        try {
            Import-Module BurntToast -ErrorAction Stop
            New-BurntToastNotification -Text $Title, $Message
        } catch {
            Write-Warning "Toast notification failed: $_"
            Write-Host "$Title`n$Message" -ForegroundColor Yellow
        }
    } elseif ($IsLinux -or $IsMacOS) {
        if (Get-Command notify-send -ErrorAction SilentlyContinue) {
            Start-Process "notify-send" -ArgumentList @("$Title", "$Message")
        } elseif ($IsMacOS) {
            $osaScript = "display notification `"$Message`" with title `"$Title`""
            osascript -e $osaScript
        } else {
            Write-Host "$Title`n$Message" -ForegroundColor Yellow
        }
    } else {
        Write-Host "$Title`n$Message" -ForegroundColor Yellow
    }
}

# ============================
# Internal: Import all Scriptgeist Modules
# ============================
function Import-ScriptgeistModules {
    [CmdletBinding()]
    param ()

    $moduleRoot = $PSScriptRoot
    $modulePaths = Get-ChildItem -Path "$moduleRoot\Modules" -Recurse -Filter *.ps1 -ErrorAction SilentlyContinue

    foreach ($script in $modulePaths) {
        try {
            . $script.FullName
            Write-Verbose "Loaded module: $($script.FullName)"
        } catch {
            Write-Warning "Failed to import: $($script.FullName) - $_"
        }
    }
}

# Load modules immediately
Import-ScriptgeistModules

# ============================
# Public Entry: Start-Scriptgeist
# ============================
function Start-Scriptgeist {
    [CmdletBinding()]
    param (
        [switch]$VerboseMode
    )

    Write-Host "`n🧠 Starting Scriptgeist Sentinel Mode..." -ForegroundColor Cyan
    Write-Host "----------------------------------------"

    if ($VerboseMode) { $VerbosePreference = "Continue" }

    # Set up logging
    $logPath = Join-Path -Path $PSScriptRoot -ChildPath "Logs"
    if (-not (Test-Path $logPath)) {
        New-Item -Path $logPath -ItemType Directory -Force | Out-Null
    }

    $startTime = Get-Date
    Write-Host "🔄 Boot Time : $startTime"
    Write-Host "🖥️  Platform  : $([System.Runtime.InteropServices.RuntimeInformation]::OSDescription)"
    Write-Host "💡 Edition   : $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)"
    Write-Host "📂 Logs Path : $logPath"

    try {
        Write-Host "`n🛰️  Initializing Watchers..."

        if (Get-Command -Name Watch-ProcessAnomalies -ErrorAction SilentlyContinue) {
            Watch-ProcessAnomalies
        } else {
            Write-Warning "Watch-ProcessAnomalies is not available yet."
        }

        if (Get-Command -Name Watch-NetworkAnomalies -ErrorAction SilentlyContinue) {
            Watch-NetworkAnomalies
        } else {
            Write-Warning "Watch-NetworkAnomalies is not available yet."
        }

        # Future modules
        # Watch-LogTampering
        # Watch-GuestSessions
        # Watch-SystemIntegrity

        Write-Host "`n✅ Scriptgeist is running." -ForegroundColor Green
    } catch {
        Write-Error "❌ Critical failure on start: $_"
    }
}
