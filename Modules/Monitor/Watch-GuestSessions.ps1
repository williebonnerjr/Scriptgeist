function Watch-GuestSessions {
    [CmdletBinding()]
    param (
        [int]$CheckIntervalSeconds = 30
    )

    Write-Host "[*] Watching for guest or low-privilege sessions..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-GuestSessions"

    $global:Scriptgeist_Running = $true
    $previousSessions = @()

    while ($global:Scriptgeist_Running) {
        try {
            $currentSessions = @()

            if ($IsWindows) {
                $currentSessions = query user 2>$null | ForEach-Object {
                    ($_ -split '\s{2,}')[0]
                } | Where-Object { $_ -and $_ -ne "USERNAME" }
            } elseif ($IsLinux -or $IsMacOS) {
                $currentSessions = who | ForEach-Object {
                    ($_ -split '\s+')[0]
                }
            }

            $newGuests = $currentSessions | Where-Object {
                ($_ -match "guest|visitor|test") -and ($_ -notin $previousSessions)
            }

            if ($newGuests.Count -gt 0) {
                foreach ($user in $newGuests) {
                    $msg = "Guest session detected: $user at $(Get-Date -Format 'HH:mm:ss')"
                    Write-GeistLog -Message $msg -Type "Alert"
                    Show-GeistNotification -Title "Scriptgeist Alert" -Message $msg
                }
            }

            $previousSessions = $currentSessions
            Start-Sleep -Seconds $CheckIntervalSeconds
        } catch {
            Write-GeistLog -Message "Error in Watch-GuestSessions: $_" -Type "Error"
        }
    }

    Write-Host "[x] Watch-GuestSessions stopped." -ForegroundColor Yellow
    Write-GeistLog -Message "Stopped Watch-GuestSessions"
}
