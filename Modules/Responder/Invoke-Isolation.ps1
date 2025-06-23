function Invoke-Isolation {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param ()

    Write-GeistLog -Message "Request to initiate network isolation received" -Type "Alert"

    if (-not $PSCmdlet.ShouldProcess("Host", "Isolate from network")) {
        return
    }

    try {
        if ($IsWindows) {
            New-NetFirewallRule -DisplayName "Scriptgeist Host Isolation" `
                -Direction Outbound -Action Block `
                -RemoteAddress "0.0.0.0/0","::/0" -Protocol Any -Profile Any `
                -ErrorAction Stop

            Write-GeistLog -Message "✅ Host isolated via Windows Firewall" -Type "Alert"
        }
        elseif ($IsLinux) {
            sudo iptables -P OUTPUT DROP
            Write-GeistLog -Message "✅ Host isolated via iptables (Linux)" -Type "Alert"
        }
        elseif ($IsMacOS) {
            $pfRules = "block drop out all"
            $tempRuleFile = "/tmp/scriptgeist_pf_rules.conf"

            Set-Content -Path $tempRuleFile -Value $pfRules -Force
            sudo pfctl -f $tempRuleFile
            sudo pfctl -e

            Write-GeistLog -Message "✅ Host isolated via pfctl (macOS)" -Type "Alert"
        }
        else {
            Write-GeistLog -Message "❌ Unsupported OS for isolation" -Type "Warning"
        }
    } catch {
        Write-GeistLog -Message "❌ Isolation failed: $_" -Type "Error"
    }
}
