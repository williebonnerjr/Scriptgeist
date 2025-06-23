function Watch-UserAccountChanges {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [int]$PollIntervalSeconds = 60,
        [ValidateSet('Passive', 'Interactive', 'Remedial')]
        [string]$Category = 'Passive'
    )

    Write-Host "[*] Monitoring user account changes..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-UserAccountChanges daemon [$Category]"

    $global:Scriptgeist_UserMonitorRunning = $true
    $previousUsers = @{}

    function Get-CurrentUsers {
        if ($IsWindows) {
            return Get-LocalUser | ForEach-Object {
                [PSCustomObject]@{
                    Name       = $_.Name
                    Enabled    = $_.Enabled
                    LastChange = $_.PasswordLastSet
                }
            }
        } elseif ($IsLinux -or $IsMacOS) {
            return Get-Content /etc/passwd | Where-Object { $_ -match "^([^:]+):" } | ForEach-Object {
                $parts = $_.Split(":")
                [PSCustomObject]@{
                    Name  = $parts[0]
                    UID   = $parts[2]
                    Home  = $parts[5]
                    Shell = $parts[6]
                }
            }
        } else {
            Write-GeistLog -Message "[Warning][$Category] Unsupported platform in Watch-UserAccountChanges" -Type "Warning"
            return @()
        }
    }

    # Take initial snapshot
    foreach ($user in Get-CurrentUsers) {
        $previousUsers[$user.Name] = $user
    }

    while ($global:Scriptgeist_UserMonitorRunning) {
        Start-Sleep -Seconds $PollIntervalSeconds

        try {
            $currentUsers = @{}
            foreach ($user in Get-CurrentUsers) {
                $currentUsers[$user.Name] = $user

                if (-not $previousUsers.ContainsKey($user.Name)) {
                    $msg = "🆕 [$Category] New user account detected: $($user.Name)"
                    Write-GeistLog -Message $msg -Type "Alert"
                    Show-GeistNotification -Title "User Account Change" -Message $msg

                    if ($Category -eq 'Remedial' -and $PSCmdlet.ShouldProcess($user.Name, "Take action on new user account")) {
                        # 🚨 Future action: disable or alert
                        Write-GeistLog -Message "[Remedial] Would act on suspicious new account: $($user.Name)" -Type "Warning"
                    }

                    Invoke-ResponderFor 'Watch-UserAccountChanges'
                }
            }

            foreach ($oldUser in $previousUsers.Keys) {
                if (-not $currentUsers.ContainsKey($oldUser)) {
                    $msg = "❌ [$Category] User account removed: $oldUser"
                    Write-GeistLog -Message $msg -Type "Alert"
                    Show-GeistNotification -Title "User Account Removed" -Message $msg

                    if ($Category -eq 'Remedial' -and $PSCmdlet.ShouldProcess($oldUser, "Review account removal")) {
                        Write-GeistLog -Message "[Remedial] Would investigate removal of user: $oldUser" -Type "Warning"
                    }

                    Invoke-ResponderFor 'Watch-UserAccountChanges'
                }
            }

            $previousUsers = $currentUsers
        } catch {
            Write-GeistLog -Message "[Warning][$Category] Error during user account monitoring loop: $_" -Type "Warning"
        }
    }

    Write-GeistLog -Message "Stopped Watch-UserAccountChanges daemon [$Category]"
    Write-Host "[x] Watch-UserAccountChanges stopped." -ForegroundColor Yellow
}
