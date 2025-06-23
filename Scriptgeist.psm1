# ============================
# Scriptgeist.psm1 - Core Loader and Launcher
# ============================

if (Get-Command Show-GeistNotification -ErrorAction SilentlyContinue) {
    Remove-Item function:Show-GeistNotification -Force
}

# ============================
# Utility: Logging Function
# ============================
function Write-GeistLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet("Info", "Warning", "Error", "Alert")]
        [string]$Type = "Info"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Type] $Message"

    $root = if ($PSScriptRoot) {
        $PSScriptRoot
    } elseif ($MyInvocation.MyCommand.Path) {
        Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        Get-Location | Select-Object -ExpandProperty Path
    }

    $logPath = Join-Path $root "Logs"
    if (-not (Test-Path $logPath)) {
        New-Item -Path $logPath -ItemType Directory -Force | Out-Null
    }

    $logFile = Join-Path $logPath "Scriptgeist.log"

    try {
        Add-Content -Path $logFile -Value $line
    } catch {
        Write-Warning "Failed to write to log: $logFile - $_"
    }
}

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
    } elseif ($IsLinux) {
        if (Get-Command notify-send -ErrorAction SilentlyContinue) {
            Start-Process "notify-send" -ArgumentList @($Title, $Message)
        } else {
            Write-Host "$Title`n$Message" -ForegroundColor Yellow
        }
    } elseif ($IsMacOS) {
        $osaScript = "display notification `"$Message`" with title `"$Title`""
        try {
            osascript -e $osaScript | Out-Null
        } catch {
            Write-Warning "macOS notification failed: $_"
        }
    } else {
        Write-Host "$Title`n$Message" -ForegroundColor Yellow
    }
}

# ============================
# Resolver Router
# ============================
function Invoke-ResponderFor {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$WatcherName
    )

    switch ($WatcherName) {
        'Watch-ProcessAnomalies'       { Stop-MaliciousProcess }
        'Watch-NetworkAnomalies'       { Block-ThreatIP }
        'Watch-LogTampering'           { Set-Quarantine }
        'Watch-CredentialArtifacts'    { Start-AutoRemediate }
        'Watch-GuestSessions'          { Invoke-Isolation }
        'Watch-SystemIntegrity'        { Start-AutoRemediate }
        'Watch-PersistenceMechanisms'  { Set-Quarantine }
        'Watch-FileSurveillance'       { Stop-MaliciousProcess }
        'Watch-PrivilegedEscalations'  { Invoke-Isolation }
        'Watch-UserAccountChanges'     { Start-AutoRemediate }
        'Watch-ExternalMounts'         { Set-Quarantine }
        'Watch-RemoteAccessChanges'    { Block-ThreatIP }
        'Watch-SystemLogs'             { Start-AutoRemediate }
        default {
            Write-Warning "No responder defined for $WatcherName"
        }
    }
}

# ============================
# Internal: Import all Scriptgeist Modules
# ============================
function Import-ScriptgeistModules {
    [CmdletBinding()]
    param ()

    $moduleRoot = $PSScriptRoot
    $modulesPath = Join-Path $moduleRoot "Modules"

    $modulePaths = Get-ChildItem -Path $modulesPath -Recurse -Filter *.ps1 -ErrorAction SilentlyContinue

    foreach ($script in $modulePaths) {
        try {
            . $script.FullName
            Write-Verbose "Loaded: $($script.FullName)"
        } catch {
            Write-Warning "Failed to import: $($script.FullName) - $_"
        }
    }
}

# Import all modules immediately
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

        $watchers = @(
            "Watch-ProcessAnomalies",
            "Watch-NetworkAnomalies",
            "Watch-LogTampering",
            "Watch-CredentialArtifacts",
            "Watch-GuestSessions",
            "Watch-SystemIntegrity",
            "Watch-PersistenceMechanisms",
            "Watch-FileSurveillance",
            "Watch-PrivilegedEscalations",
            "Watch-UserAccountChanges",
            "Watch-ExternalMounts",
            "Watch-RemoteAccessChanges",
            "Watch-SystemLogs"
        )

        foreach ($watcher in $watchers) {
            Write-Host "[~] Starting $watcher..."
            if (Get-Command -Name $watcher -ErrorAction SilentlyContinue) {
                try {
                    Start-Job -ScriptBlock {
                        param($fn)
                        & $fn
                    } -ArgumentList $watcher | Out-Null

                    Write-GeistLog -Message "Started $watcher as background job" -Type "Info"
                } catch {
                    Write-Warning "$watcher encountered an error: $_"
                    Write-GeistLog -Message "$watcher failed: $_" -Type "Error"
                }
            } else {
                Write-Warning "$watcher is not available."
                Write-GeistLog -Message "$watcher not available." -Type "Warning"
            }
        }

        Write-Host "`n✅ Scriptgeist is running." -ForegroundColor Green
        Write-GeistLog -Message "Scriptgeist startup complete." -Type "Info"
    } catch {
        Write-Error "❌ Critical failure on start: $_"
        Write-GeistLog -Message "Critical startup failure: $_" -Type "Error"
    }
}
