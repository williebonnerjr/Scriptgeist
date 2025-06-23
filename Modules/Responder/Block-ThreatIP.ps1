function Block-ThreatIP {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory)]
        [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}$')]
        [string]$IPAddress
    )

    Write-GeistLog -Message "Requested block for IP: $IPAddress" -Type "Alert"

    if (-not $PSCmdlet.ShouldProcess($IPAddress, "Block IP address")) {
        return
    }

    try {
        if ($IsWindows) {
            New-NetFirewallRule -DisplayName "Block Threat IP $IPAddress" `
                -Direction Outbound -RemoteAddress $IPAddress `
                -Action Block -Protocol Any -Profile Any -ErrorAction Stop
            Write-GeistLog -Message "✅ Windows firewall rule added to block IP: $IPAddress" -Type "Info"
        } elseif ($IsLinux -or $IsMacOS) {
            $blockCmd = "sudo iptables -A OUTPUT -d $IPAddress -j DROP"
            if ($IsMacOS) {
                $blockCmd = "sudo pfctl -t blocked -T add $IPAddress"
            }

            bash -c $blockCmd
            Write-GeistLog -Message "✅ IP blocking rule added for: $IPAddress" -Type "Info"
        } else {
            Write-GeistLog -Message "❌ Unsupported OS for IP blocking." -Type "Warning"
        }
    } catch {
        Write-GeistLog -Message "❌ Failed to block IP '{$IPAddress}': $_" -Type "Error"
    }
}
