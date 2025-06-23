function Start-AutoRemediate {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory)]
        [ValidateSet("process", "file", "ip", "isolation")]
        [string]$ThreatType,

        [string]$Target,
        [switch]$Confirm
    )

    Write-GeistLog -Message "Auto-remediation initiated for: $ThreatType"

    switch ($ThreatType.ToLower()) {
        "process" {
            if (-not $Target) {
                Write-GeistLog -Message "Missing -Target for process termination" -Type Error
                return
            }

            if ($Confirm -and -not ((Read-Host "Kill process '$Target'? (y/n)") -match '^y')) {
                Write-GeistLog -Message "User declined process termination"
                return
            }

            if ($PSCmdlet.ShouldProcess("Process '$Target'", "Terminate process")) {
                Respond-KillProcess -ProcessName $Target
            }
        }

        "file" {
            if (-not $Target) {
                Write-GeistLog -Message "Missing -Target for file quarantine" -Type Error
                return
            }

            if ($Confirm -and -not ((Read-Host "Quarantine file '$Target'? (y/n)") -match '^y')) {
                Write-GeistLog -Message "User declined file quarantine"
                return
            }

            if ($PSCmdlet.ShouldProcess("File '$Target'", "Quarantine file")) {
                Respond-QuarantineFile -FilePath $Target
            }
        }

        "ip" {
            if (-not $Target) {
                Write-GeistLog -Message "Missing -Target for IP block" -Type Error
                return
            }

            if ($Confirm -and -not ((Read-Host "Block IP '$Target'? (y/n)") -match '^y')) {
                Write-GeistLog -Message "User declined IP block"
                return
            }

            if ($PSCmdlet.ShouldProcess("IP '$Target'", "Block IP address")) {
                Respond-BlockIP -IPAddress $Target
            }
        }

        "isolation" {
            if ($Confirm -and -not ((Read-Host "Isolate this host from network? (y/n)") -match '^y')) {
                Write-GeistLog -Message "User declined host isolation"
                return
            }

            if ($PSCmdlet.ShouldProcess("System", "Initiate full host network isolation")) {
                Respond-IsolateHost
            }
        }

        default {
            Write-GeistLog -Message "Unknown threat type: $ThreatType" -Type Warning
        }
    }
}
