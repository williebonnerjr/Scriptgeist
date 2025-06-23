function Watch-LogTampering {
    [CmdletBinding()]
    param (
        [int]$PollIntervalSeconds = 30
    )

    Write-Host "[*] Monitoring for log tampering..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-LogTampering daemon"

    $isAdmin = $false
    try {
        $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        # On Linux/macOS, fallback or assume non-admin
        $isAdmin = $false
    }

    $logPaths = @()

    if ($isAdmin) {
        if ($IsWindows) {
            $logPaths += "C:\Windows\System32\winevt\Logs"
            $logPaths += "C:\ProgramData\Microsoft\Windows\WER\ReportQueue"
        } elseif ($IsLinux -or $IsMacOS) {
            $logPaths += "/var/log"
            if (Test-Path "/var/log/journal") {
                $logPaths += "/var/log/journal"
            }
        }
    } else {
        Write-Warning "Running without admin rights. System-level log monitoring will be skipped."

        if ($IsWindows) {
            $logPaths += "$env:APPDATA"
            $logPaths += "$env:LOCALAPPDATA"
        } elseif ($IsLinux -or $IsMacOS) {
            $logPaths += "$HOME/.logs"
            $logPaths += "$HOME/.local/share"
        }
    }

    $fileSnapshots = @{}
    foreach ($path in $logPaths) {
        if (Test-Path $path) {
            $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue
            foreach ($f in $files) {
                $fileSnapshots[$f.FullName] = @{ Size = $f.Length; LastWriteTime = $f.LastWriteTimeUtc }
            }
        }
    }

    while ($true) {
        Start-Sleep -Seconds $PollIntervalSeconds

        foreach ($path in $logPaths) {
            if (-not (Test-Path $path)) { continue }

            $currentFiles = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue
            foreach ($file in $currentFiles) {
                if ($fileSnapshots.ContainsKey($file.FullName)) {
                    $old = $fileSnapshots[$file.FullName]
                    if ($file.Length -lt $old.Size -or $file.LastWriteTimeUtc -lt $old.LastWriteTime) {
                        $msg = "⚠️ Log tampering suspected: $($file.FullName)"
                        Write-Warning $msg
                        Write-GeistLog -Message $msg -Type "Alert"
                        Show-GeistNotification -Title "Scriptgeist Log Watcher" -Message "Tampering suspected: $($file.Name)"
                    }
                    $fileSnapshots[$file.FullName] = @{ Size = $file.Length; LastWriteTime = $file.LastWriteTimeUtc }
                } else {
                    $msg = "🆕 New log detected: $($file.FullName)"
                    Write-GeistLog -Message $msg
                    $fileSnapshots[$file.FullName] = @{ Size = $file.Length; LastWriteTime = $file.LastWriteTimeUtc }
                }
            }

            # Check for deletions
            $knownKeys = $fileSnapshots.Keys
            foreach ($knownFile in $knownKeys) {
                if (-not (Test-Path $knownFile)) {
                    $msg = "❌ Log file deleted: $knownFile"
                    Write-Warning $msg
                    Write-GeistLog -Message $msg -Type "Alert"
                    Show-GeistNotification -Title "Scriptgeist Log Watcher" -Message "Log deleted: $(Split-Path $knownFile -Leaf)"
                    $fileSnapshots.Remove($knownFile)
                }
            }
        }
    }
}
