function Watch-FileSurveillance {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param (
        [int]$RescanIntervalSeconds = 10,
        [ValidateSet('Passive', 'Interactive', 'Remedial')]
        [string]$Category = 'Passive',
        [switch]$AttentionOnly
    )

    Write-Host "[*] Starting File Surveillance..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-FileSurveillance [$Category mode]"

    $global:Scriptgeist_Running = $true

    # Define watch paths
    if ($IsWindows) {
        $watchPaths = @(
            "$env:USERPROFILE\Downloads",
            "$env:USERPROFILE\Desktop",
            "$env:TEMP"
        )
    } elseif ($IsLinux -or $IsMacOS) {
        $userHome = [Environment]::GetFolderPath("Home")
        $watchPaths = @(
            "$userHome/Downloads",
            "$userHome/Desktop",
            "/tmp",
            "/var/tmp"
        )
    } else {
        Write-Warning "Unsupported platform"
        Write-GeistLog -Message "[Warning][$Category] Unsupported OS in Watch-FileSurveillance" -Type "Warning"
        return
    }

    $extensionsOfInterest = '\.(exe|sh|dll|bat|ps1|js|jar|zip|tar|py|pl|scr)$'
    $watchers = @()

    foreach ($path in $watchPaths) {
        if (-not (Test-Path $path)) {
            Write-GeistLog -Message "[Warning][$Category] Skipping inaccessible path: $path" -Type "Warning"
            continue
        }

        Write-Host "[+] Watching: $path" -ForegroundColor DarkCyan

        try {
            $watcher = New-Object System.IO.FileSystemWatcher
            $watcher.Path = $path
            $watcher.IncludeSubdirectories = $true
            $watcher.EnableRaisingEvents = $true
            $watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, LastWrite, Size'

            $watchers += $watcher

            Register-ObjectEvent $watcher Created -SourceIdentifier "FileCreated_$($path.GetHashCode())" -Action {
                $f = $Event.SourceEventArgs.FullPath
                if (-not (Test-Path $f)) { return }
                if ($using:AttentionOnly -and ($f -notmatch $using:extensionsOfInterest)) { return }

                $msg = "[Alert][$using:Category] New file created: $f"
                Write-GeistLog -Message $msg -Type "Alert"
                Show-GeistNotification -Title "File Surveillance" -Message $msg

                if ($using:Category -eq "Remedial" -and $PSCmdlet.ShouldProcess($f, "Take remedial action on suspicious file")) {
                    Write-GeistLog -Message "[Remedial] Would take action on: $f" -Type "Log"
                    Invoke-ResponderFor 'Watch-FileSurveillance'
                }
            }

            Register-ObjectEvent $watcher Changed -SourceIdentifier "FileChanged_$($path.GetHashCode())" -Action {
                $f = $Event.SourceEventArgs.FullPath
                if (-not (Test-Path $f)) { return }
                if ($using:AttentionOnly -and ($f -notmatch $using:extensionsOfInterest)) { return }

                $msg = "[Log][$using:Category] File modified: $f"
                Write-GeistLog -Message $msg -Type "Log"
            }

            Register-ObjectEvent $watcher Deleted -SourceIdentifier "FileDeleted_$($path.GetHashCode())" -Action {
                $f = $Event.SourceEventArgs.FullPath
                if ($using:AttentionOnly -and ($f -notmatch $using:extensionsOfInterest)) { return }

                $msg = "[Alert][$using:Category] File deleted: $f"
                Write-GeistLog -Message $msg -Type "Alert"
                Show-GeistNotification -Title "File Deleted" -Message $msg

                if ($using:Category -eq "Remedial") {
                    Invoke-ResponderFor 'Watch-FileSurveillance'
                }
            }

        } catch {
            Write-GeistLog -Message "[Warning][$Category] Error setting up watcher for '$path': $_" -Type "Warning"
        }
    }

    Write-Host "[i] FileSurveillance is active. Use Ctrl+C or stop script to end." -ForegroundColor Yellow

    while ($global:Scriptgeist_Running) {
        Start-Sleep -Seconds $RescanIntervalSeconds
    }

    Write-GeistLog -Message "Stopped Watch-FileSurveillance [$Category]"
    Write-Host "[x] Watch-FileSurveillance stopped." -ForegroundColor DarkYellow
}
