function Watch-UserAccountChanges {
    [CmdletBinding()]
    param (
        [int]$PollIntervalSeconds = 60
    )

    Write-Host "[*] Monitoring user account changes..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-UserAccountChanges daemon"

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
                    Name       = $parts[0]
                    UID        = $parts[2]
                    Home       = $parts[5]
                    Shell      = $parts[6]
                }
            }
        } else {
            return @()
        }
    }

    # Initial snapshot
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
                    $msg = "🆕 New user account detected: $($user.Name)"
                    Write-GeistLog -Message $msg -Type "Alert"
                    Show-GeistNotification -Title "User Account Change" -Message $msg
                }
            }

            foreach ($oldUser in $previousUsers.Keys) {
                if (-not $currentUsers.ContainsKey($oldUser)) {
                    $msg = "❌ User account removed: $oldUser"
                    Write-GeistLog -Message $msg -Type "Alert"
                    Show-GeistNotification -Title "User Account Removed" -Message $msg
                }
            }

            $previousUsers = $currentUsers
        } catch {
            Write-GeistLog -Message "Error during user account monitoring loop: $_" -Type "Warning"
        }
    }

    Write-GeistLog -Message "Stopped Watch-UserAccountChanges daemon"
    Write-Host "[x] Watch-UserAccountChanges stopped." -ForegroundColor Yellow
}
