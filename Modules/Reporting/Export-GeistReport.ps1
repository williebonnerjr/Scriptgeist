function Export-GeistReport {
    [CmdletBinding()]
    param (
        [string]$OutputPath = "$PSScriptRoot/GeistReport.txt",
        [ValidateSet("Text", "JSON", "HTML")] [string]$Format = "Text",
        [switch]$Redact,
        [switch]$IncludeThreatScore,
        [switch]$EncryptZip,
        [System.Security.SecureString]$ZipPassword,
        [switch]$NoDeleteWithoutPassword,
        [switch]$SendEmail,
        [string]$EmailTo,
        [string]$SmtpServer = "smtp.example.com",
        [switch]$Upload,
        [string]$UploadPath,
        [switch]$AutoOpen
    )

    if (-not (Test-Path (Split-Path $OutputPath))) {
        New-Item -ItemType Directory -Path (Split-Path $OutputPath) -Force | Out-Null
    }

    $logPath = Join-Path $PSScriptRoot 'Logs/Scriptgeist.log'
    if (-not (Test-Path $logPath)) {
        Write-Warning "No log file found to export."
        return
    }

    $lines = Get-Content $logPath
    $alerts = @()
    $regex = '^\[(?<Timestamp>[\d\-:\s]+)\] \[(?<Type>\w+)\] (?<Message>.+)$'

    foreach ($line in $lines) {
        if ($line -match $regex) {
            $msg = $Matches['Message']
            if ($Redact) {
                $msg = $msg -replace '\b(\d{1,3}\.){3}\d{1,3}\b', '[REDACTED-IP]' `
                               -replace '(?i)\buser[:= ]?\w+\b', '[REDACTED-USER]'
            }

            $threatScore = if ($IncludeThreatScore) {
                if ($msg -match 'critical|ransom|rootkit|elevation|tampering') { 9 }
                elseif ($msg -match 'error|fail|unauthorized|anomaly') { 6 }
                else { 2 }
            } else { $null }

            $alerts += [PSCustomObject]@{
                Timestamp   = $Matches['Timestamp']
                Type        = $Matches['Type']
                Message     = $msg
                ThreatScore = $threatScore
            }
        }
    }

    $metadata = @{
        Hostname  = $env:COMPUTERNAME
        Username  = $env:USERNAME
        Uptime    = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
        Generated = (Get-Date)
        EntryCount = $alerts.Count
    }

    $reportContent = switch ($Format) {
        "JSON" {
            [PSCustomObject]@{
                Metadata = $metadata
                Alerts   = $alerts
            } | ConvertTo-Json -Depth 5
        }
        "HTML" {
            $alerts | ConvertTo-Html -Property Timestamp, Type, Message, ThreatScore -PreContent "<h2>Scriptgeist Threat Report</h2><p><strong>Generated:</strong> $(Get-Date)</p>" -PostContent "<hr><p>System: $($metadata.Hostname) | User: $($metadata.Username)</p>"
        }
        default {
            "Scriptgeist Report`nGenerated: $(Get-Date)`nHost: $($metadata.Hostname) | User: $($metadata.Username) | Uptime: $($metadata.Uptime)`n---`n" + ($alerts | ForEach-Object { "[$($_.Timestamp)] [$($_.Type)] $($_.Message)" + ($(if ($IncludeThreatScore) { " (ThreatScore: $($_.ThreatScore))" } else { "" })) }) -join "`n"
        }
    }

    $plainOutputPath = [System.IO.Path]::ChangeExtension($OutputPath, $Format.ToLower())
    $reportContent | Out-File -FilePath $plainOutputPath -Encoding UTF8

    if ($EncryptZip -and $ZipPassword) {
        $zipPath = "$plainOutputPath.zip"
        $passwordPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ZipPassword)
        $passwordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPtr)

        if ($IsWindows) {
            $7zip = "C:\\Program Files\\7-Zip\\7z.exe"
            if (-not (Test-Path $7zip)) { $7zip = "7z" }
            $encCommand = "$7zip a -tzip `"$zipPath`" `"$plainOutputPath`" -p$passwordPlain -mem=AES256"
        } else {
            $encCommand = "zip -P $passwordPlain '$zipPath' '$plainOutputPath'"
        }

        Invoke-Expression $encCommand

        if (Test-Path $zipPath) {
            Remove-Item $plainOutputPath -Force
            Write-Host "🔐 Encrypted ZIP created at: $zipPath"
        }

        if ($NoDeleteWithoutPassword) {
            $lockNote = "$zipPath.protect"
            Set-Content $lockNote "Protected: Cannot delete without password."
        }
    }

    if ($AutoOpen) {
        Start-Process $plainOutputPath -ErrorAction SilentlyContinue
    }

    if ($SendEmail -and $EmailTo) {
        Send-MailMessage -To $EmailTo -From "noreply@scriptgeist.local" -SmtpServer $SmtpServer -Subject "Scriptgeist Report" -Body "Report is attached." -Attachments $zipPath, $plainOutputPath -ErrorAction SilentlyContinue
    }

    if ($Upload -and $UploadPath) {
        try {
            Copy-Item -Path $plainOutputPath -Destination $UploadPath -Force
            Write-Host "📤 Report uploaded to: $UploadPath"
        } catch {
            Write-Warning "Upload failed: $_"
        }
    }

    Write-Host "✅ Report export complete."
}
