function Invoke-ScriptgeistResponder {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Action,

        [string]$Target
    )

    switch ($Action.ToLower()) {
        "kill"       { Respond-KillProcess -ProcessName $Target }
        "quarantine" { Respond-QuarantineFile -FilePath $Target }
        "blockip"    { Respond-BlockIP -IPAddress $Target }
        "isolate"    { Respond-IsolateHost }
        "auto"       { Respond-AutoRemediate -ThreatType $Target }
        default      { Write-GeistLog -Message "Unknown responder action: $Action" -Type Warning }
    }
}
