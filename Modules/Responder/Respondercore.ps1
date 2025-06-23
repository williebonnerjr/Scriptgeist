function Invoke-GeistResponder {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('Terminate', 'Isolate', 'DisableUser', 'RemoveFile')]
        [string]$Action,

        [Parameter(Mandatory)]
        [string]$Target,

        [switch]$Force
    )

    Write-Host "[*] Executing responder action: $Action on $Target" -ForegroundColor Cyan
    Write-GeistLog -Message "Responder invoked: $Action → $Target"

    switch ($Action.ToLower()) {
        'terminate' {
            if ($PSCmdlet.ShouldProcess("Process ID $Target", "Terminate")) {
                try {
                    Stop-Process -Id $Target -Force:$Force -ErrorAction Stop
                    Write-GeistLog -Message "Terminated process ID $Target" -Type "Response"
                } catch {
                    Write-GeistLog -Message "Failed to terminate process '{$Target}': $_" -Type "Error"
                }
            }
        }

        'isolate' {
            if ($PSCmdlet.ShouldProcess("Network interfaces", "Isolate system")) {
                try {
                    Get-NetAdapter | Disable-NetAdapter -Confirm:$false -ErrorAction Stop
                    Write-GeistLog -Message "System isolation triggered (network disabled)" -Type "Response"
                } catch {
                    Write-GeistLog -Message "Failed to isolate system: $_" -Type "Error"
                }
            }
        }

        'disableuser' {
            if ($PSCmdlet.ShouldProcess("User: $Target", "Disable local account")) {
                try {
                    Disable-LocalUser -Name $Target -ErrorAction Stop
                    Write-GeistLog -Message "Disabled user account $Target" -Type "Response"
                } catch {
                    Write-GeistLog -Message "Failed to disable user '{$Target}': $_" -Type "Error"
                }
            }
        }

        'removefile' {
            if ($PSCmdlet.ShouldProcess("File: $Target", "Delete")) {
                try {
                    Remove-Item -Path $Target -Force -ErrorAction Stop
                    Write-GeistLog -Message "Removed file $Target" -Type "Response"
                } catch {
                    Write-GeistLog -Message "Failed to remove file '{$Target}': $_" -Type "Error"
                }
            }
        }

        default {
            Write-Warning "Unknown responder action: $Action"
            Write-GeistLog -Message "Unknown action '$Action' in Invoke-GeistResponder" -Type "Warning"
        }
    }
}
