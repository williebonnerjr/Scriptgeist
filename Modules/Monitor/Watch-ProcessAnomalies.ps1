function Watch-ProcessAnomalies {
    [CmdletBinding()]
    param (
        [int]$CheckIntervalSeconds = 30,
        [switch]$AttentionOnly
    )

    Write-Host "[*] Monitoring for suspicious processes..." -ForegroundColor Yellow
    Write-GeistLog -Message "Started Watch-ProcessAnomalies"

    $global:Scriptgeist_Running = $true
    $knownBadRegex = 'mimikatz|ncat|powershell|certutil|bitsadmin|nmap|meterpreter|mshta|rundll32|cmd|wget|curl'
    $seenPIDs = @{}

    while ($global:Scriptgeist_Running) {
        try {
            $procs = Get-Process -ErrorAction SilentlyContinue

            foreach ($proc in $procs) {
                if ($proc.ProcessName -match $knownBadRegex -and -not $seenPIDs.ContainsKey($proc.Id)) {
                    $msg = "⚠️ Suspicious process detected: $($proc.ProcessName) (PID: $($proc.Id))"
                    Write-Warning $msg
                    Write-GeistLog -Message $msg -Type "Alert"

                    if ($AttentionOnly) {
                        Show-GeistNotification -Title "Suspicious Process" -Message $msg
                    }

                    Invoke-ResponderFor 'Watch-ProcessAnomalies'
                    $seenPIDs[$proc.Id] = $true
                }
            }

            Start-Sleep -Seconds $CheckIntervalSeconds
        } catch {
            Write-GeistLog -Message "Error in Watch-ProcessAnomalies: $_" -Type "Error"
        }
    }

    Write-Host "[x] Watch-ProcessAnomalies stopped." -ForegroundColor Yellow
    Write-GeistLog -Message "Stopped Watch-ProcessAnomalies"
}
