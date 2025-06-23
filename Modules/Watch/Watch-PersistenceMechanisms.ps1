function Watch-PersistenceMechanisms {
    [CmdletBinding()]
    param (
        [switch]$AttentionOnly,
        [ValidateSet("Passive", "Interactive", "Remedial")]
        [string]$Category = "Passive"
    )

    Write-Host "[*] Scanning for persistence mechanisms..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-PersistenceMechanisms [$Category]"

    $alerts = @()

    if ($IsWindows) {
        # Registry run keys
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
                        $msg = "[Registry Run] $key → $name = $val"
                        $alerts += $msg
                        Submit-Alert -Message $msg -Title "Registry Persistence" -Responder 'Watch-PersistenceMechanisms' -Category $Category -AttentionOnly:$AttentionOnly
                    }
                }
            } catch {
                Write-GeistLog -Message "Failed to read '$key': $_" -Type Warning
            }
        }

        # Scheduled Tasks
        try {
            $tasks = Get-ScheduledTask | Where-Object { $_.TaskPath -notlike "\Microsoft*" }
            foreach ($task in $tasks) {
                $msg = "[Scheduled Task] $($task.TaskName) at $($task.TaskPath)"
                $alerts += $msg
                Submit-Alert -Message $msg -Title "Scheduled Task" -Responder 'Watch-PersistenceMechanisms' -Category $Category -AttentionOnly:$AttentionOnly
            }
        } catch {
            Write-GeistLog -Message "Error enumerating scheduled tasks: $_" -Type Warning
        }

        # Startup folder
        $startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
        if (Test-Path $startupPath) {
            Get-ChildItem $startupPath -File | ForEach-Object {
                $msg = "[Startup Folder] $($_.FullName)"
                $alerts += $msg
                Submit-Alert -Message $msg -Title "Startup Folder" -Responder 'Watch-PersistenceMechanisms' -Category $Category -AttentionOnly:$AttentionOnly
            }
        }

        # Suspicious service paths
        try {
            $services = Get-CimInstance -Class Win32_Service
            foreach ($svc in $services) {
                $path = $svc.PathName
                if ($path -match "\\Users\\|\\Temp\\|\\AppData\\|\.bat$|\.vbs$|\.ps1$|\.js$") {
                    $msg = "[Service Path] $($svc.Name) ($($svc.DisplayName)) → $path"
                    $alerts += $msg
                    Submit-Alert -Message $msg -Title "Suspicious Service Path" -Responder 'Watch-PersistenceMechanisms' -Category $Category -AttentionOnly:$AttentionOnly
                }
            }
        } catch {
            Write-GeistLog -Message "Error reading service paths: $_" -Type Warning
        }

    } elseif ($IsLinux -or $IsMacOS) {
        # Crontab
        try {
            $cron = & crontab -l 2>$null
            if ($cron) {
                $msg = "[Crontab] User-defined cron entries found"
                $alerts += $msg
                Submit-Alert -Message $msg -Title "Crontab Entry" -Responder 'Watch-PersistenceMechanisms' -Category $Category -AttentionOnly:$AttentionOnly
            }
        } catch {
            Write-GeistLog -Message "Error reading crontab: $_" -Type Warning
        }

        # Common autostart paths
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
                    Get-ChildItem $path -Force -ErrorAction SilentlyContinue | ForEach-Object {
                        $msg = "[Autostart] $path → $($_.Name)"
                        $alerts += $msg
                        Submit-Alert -Message $msg -Title "Autostart Entry" -Responder 'Watch-PersistenceMechanisms' -Category $Category -AttentionOnly:$AttentionOnly
                    }
                } catch {
                    Write-GeistLog -Message "Error reading '$path': $_" -Type Warning
                }
            }
        }

        # Systemd startup
        $systemdPaths = @(
            "$HOME/.config/systemd/user",
            "/etc/systemd/system"
        )

        foreach ($path in $systemdPaths) {
            if (Test-Path $path) {
                try {
                    Get-ChildItem $path -Recurse -Include "*.service" -ErrorAction SilentlyContinue | ForEach-Object {
                        $lines = Get-Content $_.FullName -ErrorAction SilentlyContinue
                        foreach ($line in $lines) {
                            if ($line -match "ExecStart\s*=\s*(.+)") {
                                $exec = $Matches[1].Trim()
                                if ($exec -match "/home|/tmp|\.sh|\.py|\.pl") {
                                    $msg = "[Systemd] $($_.Name) → $exec"
                                    $alerts += $msg
                                    Submit-Alert -Message $msg -Title "Systemd Startup" -Responder 'Watch-PersistenceMechanisms' -Category $Category -AttentionOnly:$AttentionOnly
                                }
                            }
                        }
                    }
                } catch {
                    Write-GeistLog -Message "Error scanning systemd in '$path': $_" -Type Warning
                }
            }
        }

    } else {
        Write-Warning "Unsupported platform"
        Write-GeistLog -Message "Unsupported OS in Watch-PersistenceMechanisms" -Type Warning
        return
    }

    foreach ($a in $alerts) {
        Write-GeistLog -Message $a -Type "Alert"
    }

    if ($alerts.Count -eq 0) {
        Write-Host "[✓] No persistence mechanisms found." -ForegroundColor Green
        Write-GeistLog -Message "No persistence mechanisms found"
    } else {
        Write-Host "[!] Persistence mechanisms found: $($alerts.Count)" -ForegroundColor Yellow
        Write-GeistLog -Message "Persistence scan completed with $($alerts.Count) items"
    }

    Write-GeistLog -Message "Completed Watch-PersistenceMechanisms [$Category]"
}
