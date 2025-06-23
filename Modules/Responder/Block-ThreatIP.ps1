function Block-ThreatIP {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}$')]
        [string]$IPAddress
    )

    Write-GeistLog -Message "Blocking IP: $IPAddress"

    try {
        if ($IsWindows) {
            New-NetFirewallRule -DisplayName "Block Threat IP $IPAddress" -Direction Outbound `
                -RemoteAddress $IPAddress -Action Block -Protocol Any -Profile Any -ErrorAction Stop
            Write-GeistLog -Message "Firewall rule added to block IP: $IPAddress" -Type Success
        } elseif ($IsLinux -or $IsMacOS) {
            sudo iptables -A OUTPUT -d $IPAddress -j DROP
            Write-GeistLog -Message "iptables rule added to block IP: $IPAddress" -Type Success
        } else {
            Write-GeistLog -Message "Unsupported OS for IP blocking." -Type Warning
        }
    } catch {
        Write-GeistLog -Message "Failed to block IP: $_" -Type Error
    }
}
