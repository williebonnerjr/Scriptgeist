function Get-GeistAlertSummary {
    [CmdletBinding()]
    param (
        [int]$MinutesBack = 15
    )

    Write-Host "[*] Generating alert summary for the past $MinutesBack minute(s)..." -ForegroundColor Cyan

    # Resolve log file path
    $logFile = Join-Path -Path $PSScriptRoot -ChildPath "..\Logs\Scriptgeist.log"
    $logFile = (Resolve-Path -Path $logFile -ErrorAction SilentlyContinue)?.Path

    if (-not $logFile -or -not (Test-Path $logFile)) {
        Write-Warning "⚠ No log file found at expected path: $logFile"
        return
    }

    $cutoff = (Get-Date).AddMinutes(-$MinutesBack)
    $regex = '^\[(?<Timestamp>[\d\-:\s]+)\] \[(?<Type>Alert)\] (?<Message>.+)$'
    $alertEntries = @()

    try {
        Get-Content -Path $logFile -Encoding UTF8 -ErrorAction Stop | ForEach-Object {
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
        Write-GeistLog -Message "Error parsing alerts in Get-GeistAlertSummary: $_" -Type Warning
        Write-Warning "❌ Failed to read log file: $_"
        return
    }

    if ($alertEntries.Count -eq 0) {
        Write-Host "✅ No alerts found in the last $MinutesBack minutes." -ForegroundColor Green
        Write-GeistLog -Message "No alerts found in last $MinutesBack minutes (summary)"
    } else {
        Write-Host "`n📊 Alerts from the last $MinutesBack minutes:" -ForegroundColor Cyan
        $alertEntries | Sort-Object Timestamp | Format-Table -AutoSize
        Write-GeistLog -Message "Returned $($alertEntries.Count) alert(s) in summary window ($MinutesBack min)"
    }
}
