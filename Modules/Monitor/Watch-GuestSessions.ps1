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
                $queryOutput = (query user 2>$null) -replace "\s{2,}", "," | Where-Object { $_ -match "^>" -or $_ -match "^\s*\w+" }
                foreach ($line in $queryOutput) {
                    $user = ($line -split ",")[0].Trim(">")
                    if ($user -and $user -notmatch "USERNAME") {
                        $currentSessions += $user
                    }
                }
            } elseif ($IsLinux -or $IsMacOS) {
                $currentSessions = who | ForEach-Object {
                    ($_ -split '\s+')[0]
                }
            }

            $newGuests = $currentSessions | Where-Object {
                ($_ -match 'guest|visitor|test') -and ($_ -notin $previousSessions)
            }

            foreach ($user in $newGuests) {
                $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                $msg = "🧍 Guest session detected: $user at $timestamp"
                Write-GeistLog -Message $msg -Type "Alert"
                Show-GeistNotification -Title "Scriptgeist Alert" -Message $msg
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
