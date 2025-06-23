function Invoke-GeistResponder {
    param (
        [string]$Action,
        [string]$Target,
        [switch]$Force
    )

    Write-Host "[*] Executing responder action: $Action on $Target" -ForegroundColor Cyan
    Write-GeistLog -Message "Responder invoked: $Action -> $Target"

    switch ($Action.ToLower()) {
        'terminate' {
            Stop-Process -Id $Target -Force:$Force -ErrorAction SilentlyContinue
            Write-GeistLog -Message "Terminated process ID $Target" -Type "Response"
        }
        'isolate' {
            # Disable network adapter (basic isolation)
            Get-NetAdapter | Disable-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue
            Write-GeistLog -Message "System isolation triggered (network disabled)" -Type "Response"
        }
        'disableuser' {
            Disable-LocalUser -Name $Target -ErrorAction SilentlyContinue
            Write-GeistLog -Message "Disabled user account $Target" -Type "Response"
        }
        'removefile' {
            Remove-Item -Path $Target -Force -ErrorAction SilentlyContinue
            Write-GeistLog -Message "Removed file $Target" -Type "Response"
        }
        default {
            Write-Warning "Unknown responder action: $Action"
        }
    }
}
