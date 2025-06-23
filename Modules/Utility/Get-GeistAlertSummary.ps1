function Get-GeistAlertSummary {
    [CmdletBinding()]
    param (
        [int]$MinutesBack = 15
    )

    # Resolve log file path
    $logFile = $PSScriptRoot -replace '\\Modules(\\.*)?$', '\Logs\Scriptgeist.log'

    if (-not (Test-Path $logFile)) {
        Write-Warning "No log file found at $logFile"
        return
    }

    $cutoff = (Get-Date).AddMinutes(-$MinutesBack)
    $regex = '^\[(?<Timestamp>[\d\-:\s]+)\] \[(?<Type>Alert)\] (?<Message>.+)$'
    $alertEntries = @()

    try {
        Get-Content $logFile -Encoding UTF8 | ForEach-Object {
            if ($_ -match $regex) {
                $timestamp = [datetime]$Matches['Timestamp']
                if ($timestamp -ge $cutoff) {
                    $alertEntries += [PSCustomObject]@{
                        Timestamp = $timestamp
                        Message   = $Matches['Message']
                    }
                }
            }
        }
    } catch {
        Write-Warning "Failed to read log file: $_"
        return
    }

    if ($alertEntries.Count -eq 0) {
        Write-Host "✅ No alerts found in the last $MinutesBack minutes." -ForegroundColor Green
    } else {
        Write-Host "`n📊 Anomalies detected in the last $MinutesBack minutes:" -ForegroundColor Cyan
        $alertEntries | Sort-Object Timestamp | Format-Table -AutoSize
    }
}
