function Watch-SystemIntegrity {
    [CmdletBinding()]
    param (
        [int]$RescanIntervalMinutes = 10
    )

    Write-Host "[*] Monitoring system file integrity..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-SystemIntegrity"

    $global:Scriptgeist_Running = $true

    # Define system-critical paths
    if ($IsWindows) {
        $pathsToWatch = @(
            "C:\Windows\System32",
            "C:\Windows\System32\drivers"
        )
    } elseif ($IsLinux -or $IsMacOS) {
        $pathsToWatch = @(
            "/bin",
            "/sbin",
            "/usr/bin",
            "/etc"
        )
    } else {
        Write-Warning "Unsupported OS for integrity monitoring."
        return
    }

    # Filter out inaccessible paths
    $accessiblePaths = @()
    foreach ($path in $pathsToWatch) {
        if (Test-Path $path) {
            try {
                Get-ChildItem $path -Recurse -ErrorAction Stop | Out-Null
                $accessiblePaths += $path
            } catch {
                Write-Warning "Skipping protected path (admin rights may be required): $path"
                Write-GeistLog -Message "Skipped protected path: $path" -Type "Warning"
            }
        }
    }

    if ($accessiblePaths.Count -eq 0) {
        Write-Warning "No accessible paths found. Admin/root access may be required for full monitoring."
        Show-GeistNotification -Title "Scriptgeist Notice" -Message "System integrity monitoring limited: Run as admin for full scan."
        return
    }

    # Build initial hash map
    $fileHashes = @{}
    foreach ($path in $accessiblePaths) {
        Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $hash = Get-FileHash -Path $_.FullName -Algorithm SHA256 -ErrorAction Stop
                $fileHashes[$hash.Path] = $hash.Hash
            } catch {
                Write-GeistLog -Message "Hashing error for $_.FullName: $_" -Type "Warning"
            }
        }
    }

    while ($global:Scriptgeist_Running) {
        Start-Sleep -Seconds ($RescanIntervalMinutes * 60)
        Write-Host "`n[Scan] Rechecking system files at $(Get-Date -Format 'HH:mm:ss')"

        foreach ($path in $accessiblePaths) {
            Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    $hash = Get-FileHash -Path $_.FullName -Algorithm SHA256 -ErrorAction Stop
                    if ($fileHashes.ContainsKey($hash.Path)) {
                        if ($fileHashes[$hash.Path] -ne $hash.Hash) {
                            $msg = "Integrity violation: $($hash.Path) has changed."
                            Write-GeistLog -Message $msg -Type "Alert"
                            Show-GeistNotification -Title "Scriptgeist Integrity Alert" -Message $msg
                        }
                    } else {
                        $msg = "New file detected: $($hash.Path)"
                        Write-GeistLog -Message $msg -Type "Alert"
                        Show-GeistNotification -Title "Scriptgeist Alert" -Message $msg
                    }
                } catch {
                    Write-GeistLog -Message "Hashing error during rescan: $_" -Type "Warning"
                }
            }
        }
    }

    Write-Host "[x] Watch-SystemIntegrity stopped." -ForegroundColor Yellow
    Write-GeistLog -Message "Stopped Watch-SystemIntegrity"
}
