function Write-GeistLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("Info", "Warning", "Error", "Alert", "Log", "Notify")]
        [string]$Type = "Info"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Type] $Message"

    try {
        # Define a fallback log directory if PSScriptRoot is null or not usable
        $logDir = if ($PSScriptRoot -and (Test-Path $PSScriptRoot)) {
            $PSScriptRoot -replace '\\Modules(\\.*)?$', '\Logs'
        } else {
            "$HOME/Scriptgeist/Logs"
        }

        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        $logFile = Join-Path -Path $logDir -ChildPath "Scriptgeist.log"

        Add-Content -Path $logFile -Value $logLine
    } catch {
        Write-Warning "⚠️ Failed to write to Scriptgeist log: $_"
        Write-Host "[Offline Log] $logLine" -ForegroundColor DarkYellow
    }
}
