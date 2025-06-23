function Set-Quarantine {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath
    )

    $quarantineDir = Join-Path $PSScriptRoot "..\..\Logs\Quarantine"
    $quarantineDir = (Resolve-Path -Path $quarantineDir -ErrorAction SilentlyContinue)?.Path

    if (-not (Test-Path $FilePath)) {
        Write-GeistLog -Message "Target file does not exist: $FilePath" -Type Error
        Write-Warning "File not found: $FilePath"
        return
    }

    if (-not (Test-Path $quarantineDir)) {
        try {
            New-Item -Path $quarantineDir -ItemType Directory -Force | Out-Null
            Write-GeistLog -Message "Created quarantine directory at $quarantineDir"
        } catch {
            Write-GeistLog -Message "Failed to create quarantine directory: $_" -Type Error
            return
        }
    }

    try {
        $fileName = Split-Path $FilePath -Leaf
        $destination = Join-Path $quarantineDir $fileName

        if ($PSCmdlet.ShouldProcess("Quarantine file", "$FilePath → $destination")) {
            Move-Item -Path $FilePath -Destination $destination -Force
            Write-GeistLog -Message "File quarantined: $FilePath → $destination" -Type Alert
            Write-Host "[✓] Quarantined file: $fileName" -ForegroundColor Yellow
        }
    } catch {
        Write-GeistLog -Message "Failed to quarantine file: $_" -Type Error
        Write-Warning "Quarantine operation failed: $_"
    }
}
