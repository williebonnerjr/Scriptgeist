function Invoke-ScriptgeistResponder {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory)]
        [string]$Action,

        [string]$Target
    )

    $normalizedAction = $Action.ToLower()

    if (-not $PSCmdlet.ShouldProcess("Responder: $normalizedAction", "Invoke with target: $Target")) {
        return
    }

    switch ($normalizedAction) {
        "kill" {
            if ($Target) {
                Respond-KillProcess -ProcessName $Target
            } else {
                Write-GeistLog -Message "Missing -Target for kill action" -Type Warning
            }
        }
        "quarantine" {
            if ($Target) {
                Respond-QuarantineFile -FilePath $Target
            } else {
                Write-GeistLog -Message "Missing -Target for quarantine action" -Type Warning
            }
        }
        "blockip" {
            if ($Target) {
                Respond-BlockIP -IPAddress $Target
            } else {
                Write-GeistLog -Message "Missing -Target for blockip action" -Type Warning
            }
        }
        "isolate" {
            Respond-IsolateHost
        }
        "auto" {
            if ($Target) {
                Respond-AutoRemediate -ThreatType $Target
            } else {
                Write-GeistLog -Message "Missing -Target for auto action" -Type Warning
            }
        }
        default {
            Write-GeistLog -Message "Unknown responder action: $Action" -Type Warning
            Write-Host "[!] Unknown responder action: $Action" -ForegroundColor Red
        }
    }
}
