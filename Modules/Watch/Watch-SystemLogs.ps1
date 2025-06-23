function Watch-SystemLogs {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [int]$SinceMinutes = 15,
        [switch]$AttentionOnly,
        [ValidateSet("Passive", "Interactive", "Remedial")]
        [string]$Category = "Passive"
    )

    Write-Host "[*] Watching system logs from the last $SinceMinutes minutes..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-SystemLogs [$Category]"

    $cutoffTime = (Get-Date).AddMinutes(-$SinceMinutes)

    if ($IsWindows) {
        try {
            $events = Get-WinEvent -FilterHashtable @{
                LogName   = 'System', 'Application', 'Security'
                StartTime = $cutoffTime
            } -ErrorAction Stop
        } catch {
            Write-Warning "Get-WinEvent failed, falling back to Get-EventLog..."
            $events = @()
            foreach ($log in 'System', 'Application', 'Security') {
                try {
                    $events += Get-EventLog -LogName $log -After $cutoffTime
                } catch {
                    Write-GeistLog -Message "[Warning][$Category] Error reading '{$log}': $_" -Type Warning
                }
            }
        }

        foreach ($event in $events) {
            $level = $event.LevelDisplayName
            if (-not $level) { $level = $event.EntryType }

            $isAttention = $level -match 'Error|Warning|Critical|Audit|Fail'
            if (-not $AttentionOnly -or $isAttention) {
                $msg = "[$($event.TimeCreated)] [$($level)] $($event.ProviderName): $($event.Message)"
                Submit-Alert -Message $msg -Source "Watch-SystemLogs" -Category $Category -Attention:$isAttention -ShouldProcess:$($PSCmdlet.ShouldProcess($event.ProviderName, "Flag $level log entry"))
            }
        }

    } elseif ($IsLinux -or $IsMacOS) {
        $logPaths = @(
            "/var/log/syslog", "/var/log/messages",
            "/var/log/auth.log", "/var/log/system.log"
        )

        foreach ($logPath in $logPaths) {
            if (-not (Test-Path $logPath)) { continue }

            try {
                Get-Content $logPath -Tail 500 -ErrorAction SilentlyContinue | ForEach-Object {
                    $line = $_
                    if ($line -match "\d{2}:\d{2}:\d{2}") {
                        $isAttention = $line -match "error|fail|warn|unauthorized|denied|critical|segfault|audit"
                        if (-not $AttentionOnly -or $isAttention) {
                            $msg = "[SystemLog] $line"
                            Submit-Alert -Message $msg -Source "Watch-SystemLogs" -Category $Category -Attention:$isAttention -ShouldProcess:$($PSCmdlet.ShouldProcess($logPath, "Flag suspicious system log line"))
                        }
                    }
                }
            } catch {
                Write-GeistLog -Message "[Warning][$Category] Failed reading '{$logPath}': $_" -Type Warning
            }
        }
    } else {
        Write-Warning "Unsupported platform"
        Write-GeistLog -Message "[Warning][$Category] Unsupported OS in Watch-SystemLogs" -Type Warning
    }

    Write-GeistLog -Message "Completed Watch-SystemLogs [$Category]"
    Write-Host "[✓] System log scan complete." -ForegroundColor Green
}
