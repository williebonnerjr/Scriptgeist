function Get-GeistAlertSummary {
    [CmdletBinding()]
    param (
        [int]$MinutesBack = 15
    )

    $logFile = Join-Path -Path $PSScriptRoot -Replace '\\Modules\\.*', '\Logs\Scriptgeist.log'

    if (-not (Test-Path $logFile)) {
        Write-Warning "No log file found at $logFile"
        return
    }

    $cutoff = (Get-Date).AddMinutes(-$MinutesBack)
    $regex = '^\[(?<Timestamp>[\d\-:\s]+)\] \[(?<Type>Alert)\] (?<Message>.+)$'
    $alertEntries = @()

    foreach ($line in Get-Content $logFile) {
        if ($line -match $regex) {
            $timestamp = [datetime]$Matches['Timestamp']
            if ($timestamp -ge $cutoff) {
                $alertEntries += [PSCustomObject]@{
                    Timestamp = $timestamp
                    Message   = $Matches['Message']
                }
            }
        }
    }

    if ($alertEntries.Count -eq 0) {
        Write-Host "✅ No alerts found in the last $MinutesBack minutes." -ForegroundColor Green
    } else {
        Write-Host "`n📊 Anomalies in the last $MinutesBack minutes:" -ForegroundColor Cyan
        $alertEntries | Sort-Object Timestamp | Format-Table -AutoSize
    }
}
