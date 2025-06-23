function Invoke-Isolation {
    [CmdletBinding()]
    param ()

    Write-GeistLog -Message "Initiating network isolation..."

    try {
        if ($IsWindows) {
            # Block all outbound traffic (except loopback)
            New-NetFirewallRule -DisplayName "Scriptgeist Host Isolation" `
                -Direction Outbound -Action Block -RemoteAddress "0.0.0.0/0","::/0" `
                -Profile Any -Protocol Any -ErrorAction Stop

            Write-GeistLog -Message "Host isolated from network (Windows firewall rule)" -Type Alert
        }
        elseif ($IsLinux) {
            # Set iptables policy to drop all outbound packets
            sudo iptables -P OUTPUT DROP
            Write-GeistLog -Message "Host isolated from network using iptables (Linux)" -Type Alert
        }
        elseif ($IsMacOS) {
            # Use pfctl with temporary rules to block outbound traffic
            $pfRules = "block drop out all"
            $tempRuleFile = "/tmp/scriptgeist_pf_rules.conf"
            Set-Content -Path $tempRuleFile -Value $pfRules

            sudo pfctl -f $tempRuleFile
            sudo pfctl -e

            Write-GeistLog -Message "Host isolated using pfctl (macOS)" -Type Alert
        }
        else {
            Write-GeistLog -Message "Unsupported OS for isolation" -Type Warning
        }
    } catch {
        Write-GeistLog -Message "Failed to isolate host: $_" -Type Error
    }
}
