function Watch-LogTampering {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [int]$PollIntervalSeconds = 30,
        [ValidateSet('Passive', 'Interactive', 'Remedial')]
        [string]$Category = 'Passive',
        [switch]$AttentionOnly
    )

    Write-Host "[*] Monitoring for log tampering..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-LogTampering daemon [$Category]"

    $global:Scriptgeist_LogTamperingRunning = $true
    $isAdmin = $false

    try {
        $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        $isAdmin = $false
        Write-GeistLog -Message "[Warning][$Category] Could not determine admin rights: $_" -Type "Warning"
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
        Write-Warning "Running without admin rights. System-level log monitoring will be limited."
        Write-GeistLog -Message "[Warning][$Category] Running without admin rights. Limited log coverage." -Type "Warning"

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
            Write-GeistLog -Message "[$Category] Loaded snapshot from $path with $($files.Count) files."
        } else {
            Write-GeistLog -Message "[Warning][$Category] Log path not found: $path" -Type "Warning"
        }
    }

    if ($fileSnapshots.Count -eq 0) {
        Write-Host "[!] No initial log files found to monitor." -ForegroundColor Yellow
        Write-GeistLog -Message "[Warning][$Category] No log files found during initial snapshot."
    } else {
        Write-Host "[+] Monitoring initialized with $($fileSnapshots.Count) files." -ForegroundColor Green
        Write-GeistLog -Message "[$Category] Monitoring initialized with $($fileSnapshots.Count) files."
    }

    while ($global:Scriptgeist_LogTamperingRunning) {
        Start-Sleep -Seconds $PollIntervalSeconds

        foreach ($path in $logPaths) {
            if (-not (Test-Path $path)) { continue }

            $currentFiles = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue
            foreach ($file in $currentFiles) {
                if ($fileSnapshots.ContainsKey($file.FullName)) {
                    $old = $fileSnapshots[$file.FullName]
                    if ($file.Length -lt $old.Size -or $file.LastWriteTimeUtc -lt $old.LastWriteTime) {
                        $msg = "⚠️ [$Category] Log tampering suspected: $($file.FullName)"
                        Write-Warning $msg
                        Write-GeistLog -Message $msg -Type "Alert"
                        Show-GeistNotification -Title "Scriptgeist Log Watcher" -Message "Tampering suspected: $($file.Name)"

                        if ($Category -eq 'Remedial' -and $PSCmdlet.ShouldProcess($file.FullName, "Remedial action for tampered log")) {
                            Write-GeistLog -Message "[Remedial] Would isolate/log quarantine action for: $($file.FullName)" -Type "Warning"
                        }

                        Invoke-ResponderFor 'Watch-LogTampering'
                    }
                    $fileSnapshots[$file.FullName] = @{ Size = $file.Length; LastWriteTime = $file.LastWriteTimeUtc }
                } else {
                    $msg = "🆕 [$Category] New log detected: $($file.FullName)"
                    if (-not $AttentionOnly) {
                        Write-GeistLog -Message $msg -Type "Info"
                    }
                    $fileSnapshots[$file.FullName] = @{ Size = $file.Length; LastWriteTime = $file.LastWriteTimeUtc }
                }
            }

            foreach ($knownFile in $fileSnapshots.Keys.Clone()) {
                if (-not (Test-Path $knownFile)) {
                    $msg = "❌ [$Category] Log file deleted: $knownFile"
                    Write-Warning $msg
                    Write-GeistLog -Message $msg -Type "Alert"
                    Show-GeistNotification -Title "Scriptgeist Log Watcher" -Message "Log deleted: $(Split-Path $knownFile -Leaf)"
                    $fileSnapshots.Remove($knownFile)

                    if ($Category -eq 'Remedial' -and $PSCmdlet.ShouldProcess($knownFile, "Flag deleted log for audit")) {
                        Write-GeistLog -Message "[Remedial] Would trigger audit review for deleted log: $knownFile" -Type "Warning"
                    }

                    Invoke-ResponderFor 'Watch-LogTampering'
                }
            }
        }
    }

    Write-GeistLog -Message "Stopped Watch-LogTampering daemon [$Category]"
    Write-Host "[x] Watch-LogTampering stopped." -ForegroundColor Yellow
}
