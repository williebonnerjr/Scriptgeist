function Watch-LogReplicator {
    [CmdletBinding()]
    param (
        [string]$LogDir = "$PSScriptRoot/../Logs",
        [int]$IntervalSeconds = 30,
        [switch]$EnableNotifications
    )

    Write-Host "[*] Scriptgeist Log Replicator engaged..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-LogReplicator daemon"

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

                    try {
                        if ($IsWindows) {
                            Compress-Archive -Path $log.FullName -DestinationPath $archivePath -Force
                        } elseif ($IsLinux -or $IsMacOS) {
                            Push-Location $log.DirectoryName
                            & zip -j -q "$archivePath" "$($log.Name)" 2>$null
                            Pop-Location
                        }

                        Write-GeistLog -Message "Archived modified log: $($log.Name) to $archiveName" -Type Info

                        if ($EnableNotifications) {
                            Show-GeistNotification -Title "Log Archive Created" -Message "Backup saved: $archiveName"
                        }
                    } catch {
                        Write-GeistLog -Message "Compression failed for $($log.Name): $_" -Type Warning
                    }
                }
            }

            Start-Sleep -Seconds $IntervalSeconds
        } catch {
            Write-GeistLog -Message "Error in Watch-LogReplicator loop: $_" -Type Error
        }
    }

    Write-GeistLog -Message "Stopped Watch-LogReplicator daemon"
    Write-Host "[x] Log replicator stopped." -ForegroundColor Yellow
}
