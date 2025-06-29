function Stop-MaliciousProcess {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProcessName
    )

    Write-GeistLog -Message "Attempting to kill process: $ProcessName"

    try {
        $proc = Get-Process -Name $ProcessName -ErrorAction Stop

        if ($PSCmdlet.ShouldProcess("Process: $ProcessName", "Terminate")) {
            $proc | Stop-Process -Force
            Write-GeistLog -Message "Terminated process: $ProcessName" -Type "Response"
        }
    } catch {
        Write-GeistLog -Message "Failed to kill '$ProcessName': $_" -Type Warning
    }
}
