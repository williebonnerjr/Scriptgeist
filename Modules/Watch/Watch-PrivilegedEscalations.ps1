function Watch-PrivilegedEscalations {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [switch]$AttentionOnly,
        [ValidateSet("Passive", "Interactive", "Remedial")]
        [string]$Category = "Passive"
    )

    Write-Host "[*] Checking for privileged escalation attempts..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-PrivilegedEscalations [$Category]"

    $alerts = @()

    if ($IsWindows) {
        try {
            $admins = Get-LocalGroupMember -Group "Administrators"
            foreach ($member in $admins) {
                $msg = "[Admin Group] $($member.Name) ($($member.ObjectClass)) is a member of Administrators"
                $alerts += $msg
            }
        } catch {
            Write-GeistLog -Message "Failed to enumerate local administrators: $_" -Type Warning
        }

        try {
            $privs = whoami /priv 2>&1
            foreach ($line in $privs) {
                if ($line -match "Se(Debug|Impersonate|TakeOwnership|AssignPrimaryToken)Privilege") {
                    $alerts += "[Token Privilege] $line"
                }
            }
        } catch {
            Write-GeistLog -Message "Error querying privileges: $_" -Type Warning
        }

        try {
            $events = Get-WinEvent -LogName Security -FilterXPath "*[System[(EventID=4672)]]" -MaxEvents 10
            foreach ($event in $events) {
                $alerts += "[UAC Elevation] $($event.TimeCreated): $($event.Message)"
            }
        } catch {
            Write-GeistLog -Message "Error reading Security logs for 4672: $_" -Type Warning
        }

    } elseif ($IsLinux -or $IsMacOS) {
        $sudoFiles = @("/etc/sudoers", "/etc/sudoers.d")
        foreach ($file in $sudoFiles) {
            if (Test-Path $file) {
                try {
                    Get-Content $file -ErrorAction SilentlyContinue | ForEach-Object {
                        if ($_ -match "ALL\s*=\s*\(ALL\)") {
                            $alerts += "[Sudoers] $file → $_"
                        }
                    }
                } catch {
                    Write-GeistLog -Message "Error reading '$file': $_" -Type Warning
                }
            }
        }

        try {
            $groups = id | Out-String
            if ($groups -match "sudo|wheel") {
                $alerts += "[Group Privilege] User is in: $groups"
            }
        } catch {
            Write-GeistLog -Message "Error querying groups: $_" -Type Warning
        }

        $logFiles = @("/var/log/auth.log", "/var/log/secure", "/var/log/system.log")
        foreach ($log in $logFiles) {
            if (Test-Path $log) {
                try {
                    Get-Content $log -Tail 300 -ErrorAction SilentlyContinue | ForEach-Object {
                        if ($_ -match "sudo|su\s|root|wheel") {
                            $alerts += "[Privileged Action] $_"
                        }
                    }
                } catch {
                    Write-GeistLog -Message "Error reading '$log': $_" -Type Warning
                }
            }
        }
    } else {
        Write-Warning "Unsupported platform"
        Write-GeistLog -Message "Unsupported OS in Watch-PrivilegedEscalations" -Type Warning
        return
    }

    foreach ($msg in $alerts) {
        Submit-Alert -Message $msg -Source Watch-PrivilegedEscalations -Category $Category -Attention:$AttentionOnly -ShouldProcess:$($Category -eq 'Remedial')
    }

    if ($alerts.Count -eq 0) {
        Write-Host "[✓] No privileged escalation attempts detected." -ForegroundColor Green
        Write-GeistLog -Message "No escalation attempts found"
    } else {
        Write-Host "[!] $($alerts.Count) privileged escalation event(s) detected." -ForegroundColor Yellow
        Write-GeistLog -Message "Completed Watch-PrivilegedEscalations with $($alerts.Count) alerts"
    }
}
