function Watch-ExternalMounts {
    [CmdletBinding()]
    param (
        [int]$PollIntervalSeconds = 30
    )

    Write-Host "[*] Monitoring for external/removable device mounts..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-ExternalMounts daemon"

    $global:Scriptgeist_MountMonitorRunning = $true
    $knownVolumes = @{}

    function Get-ExternalVolumes {
        if ($IsWindows) {
            Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object {
                $_.DriveType -in 2, 3 # Removable (2), Local Disk (3)
            } | ForEach-Object {
                [PSCustomObject]@{
                    Name     = $_.DeviceID
                    Volume   = $_.VolumeName
                    Type     = $_.DriveType
                    FileSystem = $_.FileSystem
                }
            }
        } elseif ($IsLinux -or $IsMacOS) {
            Get-Volume | Where-Object {
                $_.DriveType -eq "Removable" -or $_.DriveType -eq "CD-ROM"
            } | ForEach-Object {
                [PSCustomObject]@{
                    Name     = $_.DriveLetter
                    Volume   = $_.FileSystemLabel
                    Type     = $_.DriveType
                    FileSystem = $_.FileSystem
                }
            }
        } else {
            return @()
        }
    }

    # Take initial snapshot
    foreach ($vol in Get-ExternalVolumes) {
        $knownVolumes[$vol.Name] = $vol
    }

    while ($global:Scriptgeist_MountMonitorRunning) {
        Start-Sleep -Seconds $PollIntervalSeconds

        try {
            $currentVolumes = @{}
            foreach ($vol in Get-ExternalVolumes) {
                $currentVolumes[$vol.Name] = $vol

                if (-not $knownVolumes.ContainsKey($vol.Name)) {
                    $msg = "🛜 New external device mounted: $($vol.Name) [$($vol.Volume)]"
                    Write-GeistLog -Message $msg -Type "Alert"
                    Show-GeistNotification -Title "External Mount Detected" -Message $msg
                }
            }

            foreach ($known in $knownVolumes.Keys) {
                if (-not $currentVolumes.ContainsKey($known)) {
                    $msg = "❌ External device removed: $known"
                    Write-GeistLog -Message $msg -Type "Log"
                    Show-GeistNotification -Title "Device Unmounted" -Message $msg
                }
            }

            $knownVolumes = $currentVolumes
        } catch {
            Write-GeistLog -Message "Error during external mount monitoring loop: $_" -Type "Warning"
        }
    }

    Write-GeistLog -Message "Stopped Watch-ExternalMounts daemon"
    Write-Host "[x] Watch-ExternalMounts stopped." -ForegroundColor Yellow
}
