function Watch-NetworkAnomalies {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [int]$IntervalSeconds = 30,
        [int]$SummaryIntervalMinutes = 15,
        [int]$FrequentThreshold = 10,
        [int]$BandwidthThresholdMB = 20,
        [ValidateSet("Passive", "Interactive", "Remedial")]
        [string]$Category = "Passive",
        [switch]$AttentionOnly
    )

    Write-Host "[*] Scriptgeist: Network Sentinel engaged..." -ForegroundColor Cyan
    Write-GeistLog -Message "Started Watch-NetworkAnomalies daemon [$Category]"

    $global:Scriptgeist_NetworkMonitorRunning = $true
    $nextSummaryTime = (Get-Date).AddMinutes($SummaryIntervalMinutes)
    $summaryLog = @()
    $connectionCounts = @{}
    $ipGeoCache = @{}
    $suspiciousTLDs = @(".ru", ".tk", ".cn", ".top", ".xyz")

    function Resolve-GeoIP($ip) {
        if ($ipGeoCache.ContainsKey($ip)) {
            return $ipGeoCache[$ip]
        }
        try {
            $geo = Invoke-RestMethod -Uri "https://ipinfo.io/$ip/json" -UseBasicParsing -TimeoutSec 5
            $info = "$($geo.country) / $($geo.org)"
            $ipGeoCache[$ip] = $info
            return $info
        } catch {
            return "Unknown Geo"
        }
    }

    function Get-BandwidthUsage {
        if ($IsWindows) {
            return (Get-NetAdapterStatistics | Measure-Object -Property ReceivedBytes, SentBytes -Sum)
        } elseif ($IsLinux) {
            $netstat = Get-Content /proc/net/dev | Where-Object { $_ -match ":" }
            $rx = 0; $tx = 0
            foreach ($line in $netstat) {
                if ($line -match ":\s*(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)") {
                    $rx += [int64]$matches[1]
                    $tx += [int64]$matches[2]
                }
            }
            return @{ RX = $rx; TX = $tx }
        } else {
            return @{ RX = 0; TX = 0 }
        }
    }

    $prevBandwidth = Get-BandwidthUsage

    while ($global:Scriptgeist_NetworkMonitorRunning) {
        try {
            $connections = @()
            if ($IsWindows) {
                $connections = Get-NetTCPConnection -State Established |
                    Where-Object { $_.RemoteAddress -notlike "127.*" -and $_.RemoteAddress -ne "::1" } |
                    Select-Object RemoteAddress, RemotePort
            } elseif ($IsLinux -or $IsMacOS) {
                $raw = netstat -nt 2>$null | Select-String "ESTABLISHED"
                $connections = foreach ($line in $raw) {
                    if ($line -match '\s+\d+\.\d+\.\d+\.\d+\:(\d+)\s+(\d+\.\d+\.\d+\.\d+)\:(\d+)\s+ESTABLISHED') {
                        [pscustomobject]@{
                            RemoteAddress = $Matches[2]
                            RemotePort    = [int]$Matches[3]
                        }
                    }
                }
            }

            foreach ($conn in $connections) {
                $key = "$($conn.RemoteAddress):$($conn.RemotePort)"
                if ($connectionCounts.ContainsKey($key)) {
                    $connectionCounts[$key]++
                } else {
                    $connectionCounts[$key] = 1
                    $geo = Resolve-GeoIP $conn.RemoteAddress
                    $msg = "🕵️ [$Category] New IP: $key ($geo)"
                    Write-GeistLog -Message $msg -Type "Alert"
                    if (-not $AttentionOnly) { $summaryLog += $msg }

                    try {
                        $domain = ([System.Net.Dns]::GetHostEntry($conn.RemoteAddress)).HostName
                        if ($suspiciousTLDs | Where-Object { $domain -like "*$_" }) {
                            $alert = "🚨 [$Category] Suspicious TLD in: $domain ($key)"
                            Write-GeistLog -Message $alert -Type "Warning"
                            if (-not $AttentionOnly) { $summaryLog += $alert }

                            if ($Category -eq 'Remedial' -and $PSCmdlet.ShouldProcess($domain, "Isolate suspicious connection")) {
                                Write-GeistLog -Message "[Remedial] Would isolate/drop connection to $domain" -Type "Warning"
                            }

                            Invoke-ResponderFor 'Watch-NetworkAnomalies'
                        }
                    } catch { }
                }

                if ($connectionCounts[$key] -eq $FrequentThreshold) {
                    $warn = "⚠️ [$Category] Frequent connection: $key ($FrequentThreshold+ times)"
                    Write-GeistLog -Message $warn -Type "Warning"
                    if (-not $AttentionOnly) { $summaryLog += $warn }

                    if ($Category -eq 'Remedial' -and $PSCmdlet.ShouldProcess($key, "Throttle or drop frequent connection")) {
                        Write-GeistLog -Message "[Remedial] Would throttle/drop frequent connection: $key" -Type "Warning"
                    }

                    Invoke-ResponderFor 'Watch-NetworkAnomalies'
                }
            }

            $current = Get-BandwidthUsage
            if ($current -is [System.Management.Automation.PSObject]) {
                $deltaRX = ($current.RX - $prevBandwidth.RX) / 1MB
                $deltaTX = ($current.TX - $prevBandwidth.TX) / 1MB
            } else {
                $deltaRX = ($current.Sum.ReceivedBytes - $prevBandwidth.Sum.ReceivedBytes) / 1MB
                $deltaTX = ($current.Sum.SentBytes - $prevBandwidth.Sum.SentBytes) / 1MB
            }

            if ($deltaTX -gt $BandwidthThresholdMB -or $deltaRX -gt $BandwidthThresholdMB) {
                $msg = "📶 [$Category] Bandwidth alert: RX=$([math]::Round($deltaRX,2)) MB, TX=$([math]::Round($deltaTX,2)) MB"
                Write-GeistLog -Message $msg -Type "Warning"
                if (-not $AttentionOnly) { $summaryLog += $msg }

                if ($Category -eq 'Remedial' -and $PSCmdlet.ShouldProcess("Network", "Alert or block bandwidth anomaly")) {
                    Write-GeistLog -Message "[Remedial] Would take network action on bandwidth anomaly." -Type "Warning"
                }

                Invoke-ResponderFor 'Watch-NetworkAnomalies'
            }

            $prevBandwidth = $current

            if ((Get-Date) -ge $nextSummaryTime) {
                if ($summaryLog.Count -gt 0 -and -not $AttentionOnly) {
                    $notif = "$($summaryLog.Count) anomalies in last $SummaryIntervalMinutes min"
                    Show-GeistNotification -Title "Network Sentinel" -Message $notif
                    Write-Host "`n🌐 Summary:" -ForegroundColor Yellow
                    $summaryLog | ForEach-Object { Write-Host "• $_" -ForegroundColor DarkYellow }
                    $summaryLog = @()
                } elseif (-not $AttentionOnly) {
                    Write-Host "`n✅ No network anomalies detected." -ForegroundColor Green
                }
                $nextSummaryTime = (Get-Date).AddMinutes($SummaryIntervalMinutes)
            }

            Start-Sleep -Seconds $IntervalSeconds
        } catch {
            Write-GeistLog -Message "[$Category] Error in network monitor loop: $_" -Type "Error"
        }
    }

    Write-GeistLog -Message "Stopped Watch-NetworkAnomalies daemon [$Category]"
    Write-Host "[x] Network monitor stopped." -ForegroundColor Yellow
}
