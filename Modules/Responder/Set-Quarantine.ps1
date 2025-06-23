function Set-Quarantine {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath
    )

    $quarantineDir = Join-Path $PSScriptRoot "..\..\Logs\Quarantine"
    $quarantineDir = (Resolve-Path -Path $quarantineDir).Path

    if (-not (Test-Path $FilePath)) {
        Write-GeistLog -Message "Target file does not exist: $FilePath" -Type Error
        return
    }

    if (-not (Test-Path $quarantineDir)) {
        New-Item -Path $quarantineDir -ItemType Directory -Force | Out-Null
    }

    try {
        $fileName = Split-Path $FilePath -Leaf
        $destination = Join-Path $quarantineDir $fileName

        Move-Item -Path $FilePath -Destination $destination -Force
        Write-GeistLog -Message "File quarantined: $FilePath → $destination" -Type Alert
    } catch {
        Write-GeistLog -Message "Failed to quarantine file: $_" -Type Error
    }
}
