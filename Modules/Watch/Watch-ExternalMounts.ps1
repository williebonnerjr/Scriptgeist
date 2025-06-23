function Watch-ExternalMounts {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [int]$PollIntervalSeconds = 30,
        [ValidateSet('Passive', 'Interactive', 'Remedial')]
        [string]$Category = 'Passive',
        [switch]$AttentionOnly
    )

    Write-Host "[*] Monitoring for external/removable device mounts..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-ExternalMounts daemon [$Category]"

    $global:Scriptgeist_MountMonitorRunning = $true
    $knownVolumes = @{}

    function Get-ExternalVolumes {
        if ($IsWindows) {
            Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object {
                $_.DriveType -in 2, 3  # Removable or Local Disk
            } | ForEach-Object {
                [PSCustomObject]@{
                    Name       = $_.DeviceID
                    Volume     = $_.VolumeName
                    Type       = $_.DriveType
                    FileSystem = $_.FileSystem
                }
            }
        } elseif ($IsLinux) {
            try {
                lsblk -J | ConvertFrom-Json | Select-Object -ExpandProperty blockdevices | Where-Object {
                    $_.rm -eq $true -and $_.mountpoint
                } | ForEach-Object {
                    [PSCustomObject]@{
                        Name       = $_.name
                        Volume     = $_.mountpoint
                        Type       = "Removable"
                        FileSystem = $_.fstype
                    }
                }
            } catch {
                Write-GeistLog -Message "[Warning][$Category] Failed to parse lsblk output: $_" -Type "Warning"
                return @()
            }
        } elseif ($IsMacOS) {
            try {
                diskutil list | Select-String '/dev/disk[0-9]s[0-9]' | ForEach-Object {
                    $line = $_.Line.Trim()
                    if ($line -match "(/dev/disk\S+)") {
                        $disk = $matches[1]
                        [PSCustomObject]@{
                            Name       = $disk
                            Volume     = "Unknown"
                            Type       = "Removable"
                            FileSystem = "Unknown"
                        }
                    }
                }
            } catch {
                Write-GeistLog -Message "[Warning][$Category] Failed to parse diskutil output: $_" -Type "Warning"
                return @()
            }
        } else {
            Write-GeistLog -Message "[Warning][$Category] Unsupported platform in Watch-ExternalMounts" -Type "Warning"
            return @()
        }
    }

    # Initial snapshot
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
                    $msg = "🛜 [$Category] New external device mounted: $($vol.Name) [$($vol.Volume)]"
                    if (-not $AttentionOnly) {
                        Write-GeistLog -Message $msg -Type "Alert"
                        Show-GeistNotification -Title "External Mount Detected" -Message $msg
                    }

                    if ($Category -eq 'Remedial' -and $PSCmdlet.ShouldProcess($vol.Name, "Remedial action for unauthorized mount")) {
                        # Remedial action placeholder
                        Write-GeistLog -Message "[Remedial] Would attempt to unmount or restrict device: $($vol.Name)" -Type "Warning"
                    }

                    Invoke-ResponderFor 'Watch-ExternalMounts'
                }
            }

            foreach ($known in $knownVolumes.Keys) {
                if (-not $currentVolumes.ContainsKey($known)) {
                    $msg = "❌ [$Category] External device removed: $known"
                    if (-not $AttentionOnly) {
                        Write-GeistLog -Message $msg -Type "Log"
                        Show-GeistNotification -Title "Device Unmounted" -Message $msg
                    }
                }
            }

            $knownVolumes = $currentVolumes
        } catch {
            Write-GeistLog -Message "[Warning][$Category] Error during external mount monitoring: $_" -Type "Warning"
        }
    }

    Write-GeistLog -Message "Stopped Watch-ExternalMounts daemon [$Category]"
    Write-Host "[x] Watch-ExternalMounts stopped." -ForegroundColor Yellow
}
