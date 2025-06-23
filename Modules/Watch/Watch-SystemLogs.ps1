function Watch-SystemLogs {
    [CmdletBinding()]
    param (
        [int]$SinceMinutes = 15,
        [switch]$AttentionOnly
    )

    Write-Host "[*] Watching system logs for activity in the past $SinceMinutes minutes..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-SystemLogs"

    $cutoffTime = (Get-Date).AddMinutes(-$SinceMinutes)

    if ($IsWindows) {
        try {
            $events = Get-WinEvent -FilterHashtable @{
                LogName   = 'System', 'Application', 'Security'
                StartTime = $cutoffTime
            } -ErrorAction Stop
        } catch {
            Write-Warning "Get-WinEvent failed, using Get-EventLog fallback..."
            $events = @()
            foreach ($log in 'System', 'Application', 'Security') {
                try {
                    $events += Get-EventLog -LogName $log -After $cutoffTime
                } catch {
                    Write-GeistLog -Message "Error accessing $log log: $_" -Type "Warning"
                }
            }
        }

        foreach ($event in $events) {
            $level = if ($event.LevelDisplayName) { $event.LevelDisplayName } else { $event.EntryType }

            $shouldReport = -not $AttentionOnly -or ($level -match 'Error|Warning|Critical|Audit|Fail')

            if ($shouldReport) {
                $msg = "[$($event.TimeCreated)] [$($level)] $($event.ProviderName): $($event.Message)"
                Write-GeistLog -Message $msg -Type "Log"
                if ($AttentionOnly) {
                    Show-GeistNotification -Title "System Log Alert" -Message $msg
                }
            }
        }

    } elseif ($IsLinux -or $IsMacOS) {
        $logPaths = @("/var/log/syslog", "/var/log/messages", "/var/log/auth.log", "/var/log/system.log")

        foreach ($logPath in $logPaths) {
            if (-not (Test-Path $logPath)) { continue }

            try {
                Get-Content $logPath -Tail 500 | ForEach-Object {
                    $line = $_
                    if ($line -match "\d{2}:\d{2}:\d{2}") {
                        if ($AttentionOnly) {
                            if ($line -match "error|fail|warn|unauthorized|denied|critical|segfault|audit") {
                                Write-GeistLog -Message $line -Type "Alert"
                                Show-GeistNotification -Title "System Log Alert" -Message $line
                            }
                        } else {
                            Write-GeistLog -Message $line -Type "Log"
                        }
                    }
                }
            } catch {
                Write-GeistLog -Message "Failed to read log '${logPath}': $_" -Type "Warning"
            }
        }
    } else {
        Write-Warning "Unsupported platform for Watch-SystemLogs"
        Write-GeistLog -Message "Unsupported OS in Watch-SystemLogs" -Type "Warning"
    }

    Write-GeistLog -Message "Finished Watch-SystemLogs scan"
}
