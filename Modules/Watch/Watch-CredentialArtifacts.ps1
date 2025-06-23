function Watch-CredentialArtifacts {
    [CmdletBinding()]
    param (
        [switch]$AttentionOnly,
        [switch]$OutputPrompt
    )

    Write-Host "[*] Scanning for credential artifacts..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-CredentialArtifacts"

    $alerts = @()

    $keywords = @(
        "password", "passphrase", "secret", "token", "apikey", "auth",
        "mnemonic", "wallet", "privatekey", "xpub", "xprv",
        "keystore", "seed", "metamask", "ledger", "trustwallet"
    )

    $extensions = @("*.json", "*.txt", "*.conf", "*.key", "*.pem", "*.ps1", "*.sh")
    $suspiciousFiles = @("vault-data.json", "credentials", "azureProfile.json", "gcloud.json", "Login Data", "Cookies", "Web Data")

    if ($IsWindows) {
        $scanPaths = @(
            "$env:USERPROFILE\Downloads",
            "$env:USERPROFILE\Documents",
            "$env:APPDATA",
            "$env:LOCALAPPDATA",
            "$env:TEMP",
            "$env:APPDATA\Google\Chrome\User Data\Default",
            "$env:APPDATA\Mozilla\Firefox\Profiles"
        )
    } elseif ($IsLinux -or $IsMacOS) {
        $userHome = [System.Environment]::GetEnvironmentVariable("HOME")
        $scanPaths = @(
            "$userHome/Downloads",
            "$userHome/.config",
            "$userHome/.local",
            "$userHome/.ssh",
            "$userHome",
            "/tmp",
            "$userHome/.mozilla/firefox",
            "$userHome/.config/google-chrome/Default"
        )
    } else {
        Write-Warning "Unsupported platform"
        Write-GeistLog -Message "Unsupported OS in Watch-CredentialArtifacts" -Type "Warning"
        return
    }

    foreach ($path in $scanPaths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }

        try {
            $files = Get-ChildItem -Path $path -Recurse -Include $extensions -File -ErrorAction SilentlyContinue
            $extraFiles = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                $suspiciousFiles -contains $_.Name
            }
            $files += $extraFiles

            # Optional size filter: ignore large files (>5MB)
            $files = $files | Where-Object { $_.Length -lt (5MB) }

            foreach ($file in $files | Sort-Object -Unique) {
                try {
                    $lines = Get-Content -Path $file.FullName -ErrorAction SilentlyContinue
                    foreach ($line in $lines) {
                        foreach ($keyword in $keywords) {
                            $pattern = "$keyword\s*[:=]\s*['""]?[A-Za-z0-9\-_]{6,}"
                            if ($line -match $pattern) {
                                $redacted = $line -replace "(['" + '"' + "]?)[A-Za-z0-9\-_]{4,}(['" + '"' + "]?)", '***'
                                $msg = "[Credential] $($file.FullName): $redacted"
                                $alerts += [PSCustomObject]@{
                                    File    = $file.FullName
                                    Keyword = $keyword
                                    Line    = $redacted
                                }
                                if ($AttentionOnly) {
                                    Show-GeistNotification -Title "Credential Artifact" -Message $msg
                                }
                                break
                            }
                        }
                    }
                } catch {
                    Write-GeistLog -Message "Error reading $($file.FullName): $_" -Type "Warning"
                }
            }
        } catch {
            Write-GeistLog -Message "Error scanning '{$path}': $_" -Type "Warning"
        }
    }

    if (-not $alerts) {
        Write-Host "[✓] No credential artifacts found." -ForegroundColor Green
        Write-GeistLog -Message "No findings in Watch-CredentialArtifacts"
        return
    }

    Write-GeistLog -Message "Completed Watch-CredentialArtifacts"
    Write-Host "[✓] Credential scan complete. Findings: $($alerts.Count)" -ForegroundColor Yellow

    # Optional GUI preview
    if ($Host.UI.RawUI.WindowTitle -and (Get-Command Out-GridView -ErrorAction SilentlyContinue)) {
        $alerts | Out-GridView -Title "Credential Artifacts Found"
    }

    # Skip export if AttentionOnly is used
    if ($AttentionOnly) {
        return
    }

    # Prompt for export format
    if ($OutputPrompt) {
        Write-Host ""
        Write-Host "[?] Export format options:" -ForegroundColor Cyan
        Write-Host "1) Text (.txt)"
        Write-Host "2) CSV (.csv)"
        Write-Host "3) JSON (.json)"
        Write-Host "4) Open in VS Code"
        $choice = Read-Host "Enter your choice (1-4)"

        $timestamp = (Get-Date -Format "yyyyMMdd_HHmmss")
        $basePath = "$env:TEMP\CredentialArtifacts_$timestamp"

        switch ($choice) {
            '1' {
                $file = "$basePath.txt"
                $alerts | ForEach-Object {
                    "$($_.File) => $($_.Keyword): $($_.Line)"
                } | Set-Content $file
                Write-Host "Saved to $file" -ForegroundColor Green
            }
            '2' {
                $file = "$basePath.csv"
                $alerts | Export-Csv -Path $file -NoTypeInformation
                Write-Host "Saved to $file" -ForegroundColor Green
            }
            '3' {
                $file = "$basePath.json"
                $alerts | ConvertTo-Json -Depth 5 | Set-Content $file
                Write-Host "Saved to $file" -ForegroundColor Green
            }
            '4' {
                $file = "$basePath.json"
                $alerts | ConvertTo-Json -Depth 5 | Set-Content $file
                if (Get-Command code -ErrorAction SilentlyContinue) {
                    code $file
                    Write-Host "Opened in VS Code: $file" -ForegroundColor Green
                } else {
                    Write-Warning "VS Code is not installed or not available in PATH."
                }
            }
            Default {
                Write-Warning "Invalid choice. No export created."
            }
        }
    }
}
