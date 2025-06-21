function Watch-ProcessAnomalies {
    [CmdletBinding()]
    param (
        [int]$IntervalSeconds = 15,
        [int]$CpuThreshold = 50,
        [int]$SummaryIntervalMinutes = 15
    )

    Write-Host "[*] Monitoring process activity (daemon mode)..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-ProcessAnomalies daemon"
    $global:Scriptgeist_Running = $true

    $nextSummaryTime = (Get-Date).AddMinutes($SummaryIntervalMinutes)
    $summaryLog = @()

    while ($global:Scriptgeist_Running) {
        try {
            $baseline = Get-Process | Select-Object Name, Id, CPU
            Start-Sleep -Seconds $IntervalSeconds
            $current = Get-Process | Select-Object Name, Id, CPU

            $delta = Compare-Object $baseline $current -Property Name, Id, CPU -PassThru |
                Where-Object { $_.SideIndicator -eq '=>' -and $_.CPU -gt $CpuThreshold }

            if ($delta) {
                $timestamp = Get-Date -Format "HH:mm:ss"
                $msg = "[$timestamp] Anomaly: $($delta.Count) suspicious processes"
                Write-GeistLog -Message $msg -Type "Alert"
                $summaryLog += $msg
            } else {
                Write-GeistLog -Message "No anomalies this cycle"
            }

            # Show summary every X minutes
            if ((Get-Date) -ge $nextSummaryTime) {
                if ($summaryLog.Count -gt 0) {
                    Write-Host "`n🕒 Summary Report for the last $SummaryIntervalMinutes minute(s):" -ForegroundColor Cyan
                    foreach ($line in $summaryLog) {
                        Write-Host "• $line" -ForegroundColor Yellow
                    }

                    # Toast Notification
                    $notifMsg = "$($summaryLog.Count) anomaly event(s) in the last $SummaryIntervalMinutes minutes."
                    Show-GeistNotification -Title "Scriptgeist Alert" -Message $notifMsg
                } else {
                    Write-Host "`n🕒 No anomalies to report in the last $SummaryIntervalMinutes minute(s)." -ForegroundColor Green
                }

                # Reset summary state
                $summaryLog = @()
                $nextSummaryTime = (Get-Date).AddMinutes($SummaryIntervalMinutes)
            }

        } catch {
            Write-GeistLog -Message "Error in monitoring loop: $_" -Type "Error"
        }
    }

    Write-Host "[x] Watch-ProcessAnomalies daemon stopped." -ForegroundColor Yellow
    Write-GeistLog -Message "Stopped Watch-ProcessAnomalies daemon"
}
