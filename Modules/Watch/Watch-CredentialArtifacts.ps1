function Watch-CredentialArtifacts {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [switch]$AttentionOnly,
        [switch]$OutputPrompt,
        [ValidateSet('Passive', 'Interactive', 'Remedial')]
        [string]$Category = 'Passive'
    )

    Write-Host "[*] Scanning for credential artifacts..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-CredentialArtifacts [$Category]"

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
        $userHomePath = [System.Environment]::GetEnvironmentVariable("HOME")
        $scanPaths = @(
            "$userHomePath/Downloads",
            "$userHomePath/.config",
            "$userHomePath/.local",
            "$userHomePath/.ssh",
            "$userHomePath",
            "/tmp",
            "$userHomePath/.mozilla/firefox",
            "$userHomePath/.config/google-chrome/Default"
        )
    } else {
        Write-Warning "Unsupported platform"
        Write-GeistLog -Message "[Warning][$Category] Unsupported OS in Watch-CredentialArtifacts" -Type "Warning"
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
            $files = $files | Where-Object { $_.Length -lt (5MB) }

            foreach ($file in $files | Sort-Object -Unique) {
                try {
                    $lines = Get-Content -Path $file.FullName -ErrorAction SilentlyContinue
                    foreach ($line in $lines) {
                        foreach ($keyword in $keywords) {
                            $pattern = "$keyword\s*[:=]\s*['""]?[A-Za-z0-9\-_]{6,}"
                            if ($line -match $pattern) {
                                $redacted = $line -replace "(['""']?)[A-Za-z0-9\-_]{4,}(['""']?)", '***'
                                $msg = "[Credential][$Category] $($file.FullName): $redacted"

                                $alerts += [PSCustomObject]@{
                                    File    = $file.FullName
                                    Keyword = $keyword
                                    Line    = $redacted
                                }

                                Write-GeistLog -Message $msg -Type "Alert"
                                if ($AttentionOnly) {
                                    Show-GeistNotification -Title "Credential Artifact" -Message $msg
                                }

                                if ($Category -eq 'Remedial' -and $PSCmdlet.ShouldProcess($file.FullName, "Remediate credential artifact")) {
                                    Write-GeistLog -Message "[Remedial] Would act on: $($file.FullName)" -Type "Warning"
                                }

                                Invoke-ResponderFor 'Watch-CredentialArtifacts'
                                break
                            }
                        }
                    }
                } catch {
                    Write-GeistLog -Message "[Warning][$Category] Error reading $($file.FullName): $_" -Type "Warning"
                }
            }
        } catch {
            Write-GeistLog -Message "[Warning][$Category] Error scanning '$path': $_" -Type "Warning"
        }
    }

    if (-not $alerts) {
        Write-Host "[✓] No credential artifacts found." -ForegroundColor Green
        Write-GeistLog -Message "No findings in Watch-CredentialArtifacts [$Category]"
        return
    }

    Write-GeistLog -Message "Completed Watch-CredentialArtifacts [$Category]"
    Write-Host "[✓] Credential scan complete. Findings: $($alerts.Count)" -ForegroundColor Yellow

    if ($Host.UI.RawUI.WindowTitle -and (Get-Command Out-GridView -ErrorAction SilentlyContinue)) {
        $alerts | Out-GridView -Title "Credential Artifacts Found"
    }

    if ($AttentionOnly) { return }

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
