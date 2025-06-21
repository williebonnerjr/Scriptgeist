function Write-GeistLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("Info", "Warning", "Error", "Alert")]
        [string]$Type = "Info"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Type] $Message"
    $logFile = Join-Path -Path $PSScriptRoot -Replace '\\Modules\\.*', '\Logs\Scriptgeist.log'

    try {
        Add-Content -Path $logFile -Value $line
    } catch {
        Write-Warning "Failed to write to log: $logFile - $_"
    }
}
