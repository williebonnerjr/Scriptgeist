function Watch-PrivilegedEscalations {
    [CmdletBinding()]
    param (
        [switch]$AttentionOnly
    )

    Write-Host "[*] Checking for privileged escalation attempts..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-PrivilegedEscalations"

    $alerts = @()

    if ($IsWindows) {
        # Check for new local administrators
        try {
            $admins = Get-LocalGroupMember -Group "Administrators"
            foreach ($member in $admins) {
                $msg = "[Admin Group] $($member.Name) ($($member.ObjectClass)) is a member of Administrators"
                $alerts += $msg
                if ($AttentionOnly) {
                    Show-GeistNotification -Title "Admin Privilege" -Message $msg
                }
            }
        } catch {
            Write-GeistLog -Message "Failed to enumerate local administrators: $_" -Type "Warning"
        }

        # Check for Se* privilege rights (requires admin)
        try {
            $privs = whoami /priv 2>&1
            foreach ($line in $privs) {
                if ($line -match "SeDebugPrivilege|SeImpersonatePrivilege|SeTakeOwnershipPrivilege|SeAssignPrimaryTokenPrivilege") {
                    $msg = "[Token Privilege] $line"
                    $alerts += $msg
                    if ($AttentionOnly) {
                        Show-GeistNotification -Title "High Privilege Detected" -Message $msg
                    }
                }
            }
        } catch {
            Write-GeistLog -Message "Error querying privileges: $_" -Type "Warning"
        }

        # Optional: Check UAC bypass traces from event logs (ID 4672)
        try {
            $events = Get-WinEvent -LogName Security -FilterXPath "*[System[(EventID=4672)]]" -MaxEvents 10
            foreach ($event in $events) {
                $msg = "[UAC Elevation] $($event.TimeCreated): $($event.Message)"
                $alerts += $msg
                if ($AttentionOnly) {
                    Show-GeistNotification -Title "UAC Elevation" -Message $msg
                }
            }
        } catch {
            Write-GeistLog -Message "Error reading Security logs for 4672: $_" -Type "Warning"
        }

    } elseif ($IsLinux -or $IsMacOS) {
        # sudoers file check
        $sudoFiles = @("/etc/sudoers", "/etc/sudoers.d")
        foreach ($file in $sudoFiles) {
            if (Test-Path $file) {
                try {
                    $lines = Get-Content $file -ErrorAction SilentlyContinue
                    foreach ($line in $lines) {
                        if ($line -match "ALL\s*=\s*\(ALL\)") {
                            $msg = "[Sudoers] $file contains: $line"
                            $alerts += $msg
                            if ($AttentionOnly) {
                                Show-GeistNotification -Title "Sudoers Escalation" -Message $msg
                            }
                        }
                    }
                } catch {
                    Write-GeistLog -Message "Error reading '{$file}': $_" -Type "Warning"
                }
            }
        }

        # Check if current user is in sudo or wheel group
        try {
            $groups = id | Out-String
            if ($groups -match "sudo|wheel") {
                $msg = "[Group Privilege] User is in: $groups"
                $alerts += $msg
                if ($AttentionOnly) {
                    Show-GeistNotification -Title "Privileged Group" -Message $msg
                }
            }
        } catch {
            Write-GeistLog -Message "Error querying groups: $_" -Type "Warning"
        }

        # Check auth log for 'sudo', 'su', 'root' activity
        $logFiles = @("/var/log/auth.log", "/var/log/secure", "/var/log/system.log")
        foreach ($log in $logFiles) {
            if (Test-Path $log) {
                try {
                    $lines = Get-Content $log -Tail 300 -ErrorAction SilentlyContinue
                    foreach ($line in $lines) {
                        if ($line -match "sudo|su\s|root|wheel") {
                            $msg = "[Privileged Action] $line"
                            $alerts += $msg
                            if ($AttentionOnly) {
                                Show-GeistNotification -Title "Escalation Log" -Message $msg
                            }
                        }
                    }
                } catch {
                    Write-GeistLog -Message "Error reading '{$log}': $_" -Type "Warning"
                }
            }
        }
    } else {
        Write-Warning "Unsupported platform"
        Write-GeistLog -Message "Unsupported OS in Watch-PrivilegedEscalations" -Type "Warning"
        return
    }

    foreach ($line in $alerts) {
        Write-GeistLog -Message $line -Type "Alert"
    }

    Write-GeistLog -Message "Completed Watch-PrivilegedEscalations"
    Write-Host "[✓] Privilege escalation scan complete." -ForegroundColor Green
}
