function Stop-MaliciousProcess {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProcessName
    )

    Write-GeistLog -Message "Attempting to kill process: $ProcessName"

    try {
        $proc = Get-Process -Name $ProcessName -ErrorAction Stop
        $proc | Stop-Process -Force
        Write-GeistLog -Message "Terminated process: $ProcessName" -Type Success
    } catch {
        Write-GeistLog -Message "Failed to kill '{$ProcessName}': $_" -Type Warning
    }
}
