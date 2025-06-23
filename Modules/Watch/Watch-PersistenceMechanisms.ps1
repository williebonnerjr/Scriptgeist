function Watch-PersistenceMechanisms {
    [CmdletBinding()]
    param (
        [switch]$AttentionOnly
    )

    Write-Host "[*] Scanning for persistence mechanisms..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-PersistenceMechanisms"

    $alerts = @()

    if ($IsWindows) {
        # Registry Run keys
        $runKeys = @(
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
        )

        foreach ($key in $runKeys) {
            try {
                $entries = Get-ItemProperty -Path $key -ErrorAction Stop
                foreach ($name in $entries.PSObject.Properties.Name) {
                    if ($name -notmatch "^PS") {
                        $val = $entries.$name
                        $msg = "[Registry Run] $key -> $name = $val"
                        $alerts += $msg
                        if ($AttentionOnly) {
                            Show-GeistNotification -Title "Persistence Detected" -Message $msg
                        }
                    }
                }
            } catch {
                Write-GeistLog -Message "Failed to read '{$key}': $_" -Type "Warning"
            }
        }

        # Scheduled tasks
        try {
            $tasks = Get-ScheduledTask | Where-Object { $_.TaskPath -notlike "\Microsoft*" }
            foreach ($task in $tasks) {
                $msg = "[Scheduled Task] $($task.TaskName) in path $($task.TaskPath)"
                $alerts += $msg
                if ($AttentionOnly) {
                    Show-GeistNotification -Title "Scheduled Task" -Message $msg
                }
            }
        } catch {
            Write-GeistLog -Message "Failed to enumerate scheduled tasks: $_" -Type "Warning"
        }

        # Startup folder
        $startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
        if (Test-Path $startupPath) {
            $files = Get-ChildItem $startupPath -File
            foreach ($file in $files) {
                $msg = "[Startup Folder] $($file.Name)"
                $alerts += $msg
                if ($AttentionOnly) {
                    Show-GeistNotification -Title "Startup File" -Message $msg
                }
            }
        }

        # Windows services with user-space paths
        try {
            $services = Get-CimInstance -ClassName Win32_Service
            foreach ($svc in $services) {
                $imagePath = $svc.PathName
                if ($imagePath -and $imagePath -match "\\Users\\|\\Temp\\|\\AppData\\|\.bat$|\.vbs$|\.ps1$|\.js$") {
                    $msg = "[Service Path] $($svc.Name) ($($svc.DisplayName)) → $imagePath"
                    $alerts += $msg
                    if ($AttentionOnly) {
                        Show-GeistNotification -Title "Suspicious Service Path" -Message $msg
                    }
                }
            }
        } catch {
            Write-GeistLog -Message "Error reading service paths: $_" -Type "Warning"
        }

    } elseif ($IsLinux -or $IsMacOS) {
        # Crontab
        try {
            $cron = & crontab -l 2>$null
            if ($cron) {
                $msg = "[Crontab] User entries found"
                $alerts += $msg
                if ($AttentionOnly) {
                    Show-GeistNotification -Title "Crontab" -Message $msg
                }
            }
        } catch {
            Write-GeistLog -Message "Error reading crontab: $_" -Type "Warning"
        }

        # Autostart directories
        $autostartPaths = @(
            "$HOME/.config/autostart",
            "/etc/init.d",
            "/etc/systemd/system",
            "$HOME/.bashrc",
            "$HOME/.profile"
        )

        foreach ($path in $autostartPaths) {
            if (Test-Path $path) {
                try {
                    $items = Get-ChildItem $path -Force -ErrorAction SilentlyContinue
                    foreach ($item in $items) {
                        $msg = "[Autostart] $path -> $($item.Name)"
                        $alerts += $msg
                        if ($AttentionOnly) {
                            Show-GeistNotification -Title "Startup Entry" -Message $msg
                        }
                    }
                } catch {
                    Write-GeistLog -Message "Error reading '{$path}': $_" -Type "Warning"
                }
            }
        }

        # Systemd service files (user/system)
        $systemdPaths = @(
            "$HOME/.config/systemd/user",
            "/etc/systemd/system"
        )
        foreach ($path in $systemdPaths) {
            if (Test-Path $path) {
                try {
                    $services = Get-ChildItem $path -Recurse -Include "*.service" -ErrorAction SilentlyContinue
                    foreach ($svc in $services) {
                        $lines = Get-Content $svc.FullName -ErrorAction SilentlyContinue
                        foreach ($line in $lines) {
                            if ($line -match "ExecStart\s*=\s*(.+)") {
                                $exec = $Matches[1].Trim()
                                if ($exec -match "/home|/tmp|\.sh|\.py|\.pl") {
                                    $msg = "[Systemd] $($svc.Name) → $exec"
                                    $alerts += $msg
                                    if ($AttentionOnly) {
                                        Show-GeistNotification -Title "Systemd ExecStart" -Message $msg
                                    }
                                }
                            }
                        }
                    }
                } catch {
                    Write-GeistLog -Message "Error scanning systemd files in '{$path}': $_" -Type "Warning"
                }
            }
        }
    } else {
        Write-Warning "Unsupported platform"
        Write-GeistLog -Message "Unsupported OS in Watch-PersistenceMechanisms" -Type "Warning"
        return
    }

    # Output results
    foreach ($line in $alerts) {
        Write-GeistLog -Message $line -Type "Alert"
    }

    Write-GeistLog -Message "Completed Watch-PersistenceMechanisms"
    Write-Host "[✓] Persistence scan complete." -ForegroundColor Green
}
