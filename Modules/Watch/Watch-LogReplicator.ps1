function Watch-LogReplicator {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$LogDir = "$PSScriptRoot/../Logs",
        [int]$IntervalSeconds = 30,
        [switch]$EnableNotifications,
        [switch]$AttentionOnly,
        [ValidateSet('Passive', 'Interactive', 'Remedial')]
        [string]$Category = 'Passive'
    )

    Write-Host "[*] Scriptgeist Log Replicator engaged..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-LogReplicator daemon [$Category]"

    $global:Scriptgeist_LogReplicatorRunning = $true
    $prevHashes = @{}

    while ($global:Scriptgeist_LogReplicatorRunning) {
        try {
            $logFiles = Get-ChildItem -Path $LogDir -Filter *.log -File -Recurse -ErrorAction SilentlyContinue

            foreach ($log in $logFiles) {
                $hash = (Get-FileHash -Path $log.FullName -Algorithm SHA256).Hash
                if (-not $prevHashes.ContainsKey($log.FullName) -or $prevHashes[$log.FullName] -ne $hash) {
                    $prevHashes[$log.FullName] = $hash

                    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
                    $platformTag = if ($IsWindows) { "win" } elseif ($IsLinux) { "linux" } elseif ($IsMacOS) { "mac" } else { "unknown" }
                    $archiveName = "LogCopy_${platformTag}_$timestamp.zip"
                    $archivePath = Join-Path $LogDir $archiveName

                    if ($PSCmdlet.ShouldProcess($log.FullName, "Archive modified log as $archiveName")) {
                        try {
                            if ($IsWindows) {
                                Compress-Archive -Path $log.FullName -DestinationPath $archivePath -Force
                            } elseif ($IsLinux -or $IsMacOS) {
                                Push-Location $log.DirectoryName
                                & zip -j -q "$archivePath" "$($log.Name)" 2>$null
                                Pop-Location
                            }

                            Write-GeistLog -Message "[$Category] Archived modified log: $($log.Name) → $archiveName" -Type Info

                            if ($EnableNotifications -and -not $AttentionOnly) {
                                Show-GeistNotification -Title "Log Archive Created" -Message "Backup saved: $archiveName"
                            }

                            if ($Category -eq 'Remedial') {
                                Write-GeistLog -Message "[Remedial] Would initiate upload or vault storage for: $archiveName" -Type Info
                                Invoke-ResponderFor 'Watch-LogReplicator'
                            }

                        } catch {
                            Write-GeistLog -Message "[Warning][$Category] Compression failed for $($log.Name): $_" -Type Warning
                        }
                    }
                }
            }

            Start-Sleep -Seconds $IntervalSeconds
        } catch {
            Write-GeistLog -Message "[Error][$Category] Error in Watch-LogReplicator loop: $_" -Type Error
        }
    }

    Write-GeistLog -Message "Stopped Watch-LogReplicator daemon [$Category]"
    Write-Host "[x] Log replicator stopped." -ForegroundColor Yellow
}
