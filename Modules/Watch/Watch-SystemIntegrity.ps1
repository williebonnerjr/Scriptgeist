function Watch-SystemIntegrity {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [int]$RescanIntervalMinutes = 10,
        [switch]$AttentionOnly,
        [ValidateSet("Passive", "Interactive", "Remedial")]
        [string]$Category = "Passive"
    )

    Write-Host "[*] Monitoring system file integrity..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-SystemIntegrity [$Category]"

    $global:Scriptgeist_Running = $true

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
        Write-GeistLog -Message "[Warning][$Category] Unsupported OS in Watch-SystemIntegrity" -Type Warning
        return
    }

    $accessiblePaths = @()
    foreach ($path in $pathsToWatch) {
        if (Test-Path $path) {
            try {
                Get-ChildItem $path -Recurse -ErrorAction Stop | Out-Null
                $accessiblePaths += $path
            } catch {
                Write-Warning "Skipping protected path: $path"
                Write-GeistLog -Message "[Warning][$Category] Skipped protected path: $path" -Type Warning
            }
        }
    }

    if ($accessiblePaths.Count -eq 0) {
        Write-Warning "No accessible paths found. Try running as admin/root."
        Show-GeistNotification -Title "Scriptgeist Notice" -Message "System integrity scan limited. Use admin/root."
        Write-GeistLog -Message "[Warning][$Category] No accessible paths for system integrity scan" -Type Warning
        return
    }

    $fileHashes = @{}
    foreach ($path in $accessiblePaths) {
        Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $hash = Get-FileHash -Path $_.FullName -Algorithm SHA256 -ErrorAction Stop
                $fileHashes[$hash.Path] = $hash.Hash
            } catch {
                Write-GeistLog -Message "[Warning][$Category] Hash error: $_" -Type Warning
            }
        }
    }

    Write-GeistLog -Message "[$Category] Initial hash snapshot contains $($fileHashes.Count) files."

    while ($global:Scriptgeist_Running) {
        Start-Sleep -Seconds ($RescanIntervalMinutes * 60)
        Write-Host "`n[Scan][$Category] Rechecking integrity at $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray

        foreach ($path in $accessiblePaths) {
            Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    $hash = Get-FileHash -Path $_.FullName -Algorithm SHA256 -ErrorAction Stop
                    $pathKey = $hash.Path

                    if ($fileHashes.ContainsKey($pathKey)) {
                        if ($fileHashes[$pathKey] -ne $hash.Hash) {
                            $msg = "🛑 [$Category] Integrity violation: $pathKey changed."
                            Submit-Alert -Message $msg -Source "Watch-SystemIntegrity" -Category $Category -Attention:$AttentionOnly -ShouldProcess:$($PSCmdlet.ShouldProcess($pathKey, "Flag integrity violation"))
                        }
                    } else {
                        $msg = "🆕 [$Category] New system file detected: $pathKey"
                        Submit-Alert -Message $msg -Source "Watch-SystemIntegrity" -Category $Category -Attention:$AttentionOnly -ShouldProcess:$($PSCmdlet.ShouldProcess($pathKey, "Flag new system file"))
                    }

                    $fileHashes[$pathKey] = $hash.Hash
                } catch {
                    Write-GeistLog -Message "[Warning][$Category] Hashing error during rescan: $_" -Type Warning
                }
            }
        }
    }

    Write-GeistLog -Message "Stopped Watch-SystemIntegrity [$Category]"
    Write-Host "[x] Watch-SystemIntegrity stopped." -ForegroundColor Yellow
}
