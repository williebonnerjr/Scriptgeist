function Watch-RemoteAccessChanges {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [int]$SinceMinutes = 20,
        [switch]$AttentionOnly,
        [ValidateSet("Passive", "Interactive", "Remedial")]
        [string]$Category = "Passive"
    )

    Write-Host "[*] Monitoring remote access attempts..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-RemoteAccessChanges [$Category]"

    $cutoffTime = (Get-Date).AddMinutes(-$SinceMinutes)
    $alerts = @()

    if ($IsWindows) {
        try {
            $eventIDs = 4624, 4625, 4778, 4779
            $events = Get-WinEvent -FilterHashtable @{
                LogName   = 'Security'
                Id        = $eventIDs
                StartTime = $cutoffTime
            } -ErrorAction Stop

            foreach ($event in $events) {
                $msg = "[$($event.TimeCreated)] [RemoteAccess][$Category] $($event.Id): $($event.Message)"
                $isSuspicious = $event.Id -in 4625, 4778
                if (-not $AttentionOnly -or $isSuspicious) {
                    $alerts += $msg
                }
            }
        } catch {
            Write-GeistLog -Message "[Warning][$Category] Failed to query Windows Security logs: $_" -Type Warning
        }
    }
    elseif ($IsLinux -or $IsMacOS) {
        $logFiles = @("/var/log/auth.log", "/var/log/secure", "/var/log/system.log")
        foreach ($log in $logFiles) {
            if (-not (Test-Path $log)) { continue }
            try {
                $lines = Get-Content $log -Tail 300 -ErrorAction SilentlyContinue
                foreach ($line in $lines) {
                    if ($line -match "sshd|rsh|telnet|vnc|remote|Accepted|Failed password|connection closed") {
                        $isSuspicious = $line -match "Failed|unauthorized|denied"
                        if (-not $AttentionOnly -or $isSuspicious) {
                            $alerts += "[RemoteAccess][$Category] $line"
                        }
                    }
                }
            } catch {
                Write-GeistLog -Message "[Warning][$Category] Error reading '$log': $_" -Type Warning
            }
        }
    }
    else {
        Write-Warning "Unsupported platform for Watch-RemoteAccessChanges"
        Write-GeistLog -Message "[Warning][$Category] Unsupported OS in Watch-RemoteAccessChanges" -Type Warning
        return
    }

    foreach ($alert in $alerts) {
        Submit-Alert -Message $alert -Source "Watch-RemoteAccessChanges" -Category $Category -Attention:$AttentionOnly -ShouldProcess:$($PSCmdlet.ShouldProcess($alert, "Log remote access event"))
    }

    if ($alerts.Count -eq 0) {
        Write-Host "[✓] No remote access anomalies found." -ForegroundColor Green
        Write-GeistLog -Message "No suspicious remote access activity detected [$Category]"
    } else {
        Write-Host "[!] $($alerts.Count) remote access events detected." -ForegroundColor Yellow
        Write-GeistLog -Message "Completed Watch-RemoteAccessChanges with $($alerts.Count) events [$Category]"
    }
}
