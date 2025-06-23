function Watch-RemoteAccessChanges {
    [CmdletBinding()]
    param (
        [int]$SinceMinutes = 20,
        [switch]$AttentionOnly
    )

    Write-Host "[*] Monitoring remote access attempts..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-RemoteAccessChanges"

    $cutoffTime = (Get-Date).AddMinutes(-$SinceMinutes)

    if ($IsWindows) {
        try {
            # Event ID 4624: Successful logon, 4625: Failed logon
            $eventIDs = 4624, 4625, 4778, 4779
            $events = Get-WinEvent -FilterHashtable @{
                LogName   = 'Security'
                Id        = $eventIDs
                StartTime = $cutoffTime
            } -ErrorAction Stop

            foreach ($event in $events) {
                $msg = "[$($event.TimeCreated)] [RemoteAccess] $($event.Id): $($event.Message)"

                $shouldReport = -not $AttentionOnly -or ($event.Id -eq 4625 -or $event.Id -eq 4778)

                if ($shouldReport) {
                    Write-GeistLog -Message $msg -Type "Alert"
                    if ($AttentionOnly) {
                        Show-GeistNotification -Title "Remote Access" -Message $msg
                    }
                }
            }

        } catch {
            Write-GeistLog -Message "Failed to query Windows Security log for remote access events: $_" -Type "Warning"
        }

    } elseif ($IsLinux -or $IsMacOS) {
        $logFiles = @("/var/log/auth.log", "/var/log/secure", "/var/log/system.log")
        foreach ($log in $logFiles) {
            if (-not (Test-Path $log)) { continue }

            try {
                $lines = Get-Content $log -Tail 300 -ErrorAction SilentlyContinue
                foreach ($line in $lines) {
                    if ($line -match "sshd|rsh|telnet|vnc|remote|Accepted|Failed password|connection closed") {
                        $msg = "[RemoteAccess] $line"
                        $shouldReport = -not $AttentionOnly -or ($line -match "Failed|unauthorized|denied")

                        if ($shouldReport) {
                            Write-GeistLog -Message $msg -Type "Alert"
                            if ($AttentionOnly) {
                                Show-GeistNotification -Title "Remote Access" -Message $msg
                            }
                        }
                    }
                }
            } catch {
                Write-GeistLog -Message "Error reading '$log': $_" -Type "Warning"
            }
        }
    } else {
        Write-Warning "Unsupported platform for Watch-RemoteAccessChanges"
        Write-GeistLog -Message "Unsupported OS in Watch-RemoteAccessChanges" -Type "Warning"
    }

    Write-GeistLog -Message "Completed Watch-RemoteAccessChanges"
    Write-Host "[✓] Remote access scan complete." -ForegroundColor Green
}
