function Watch-ProcessAnomalies {
    [CmdletBinding()]
    param ()

    Write-Host "[*] Monitoring process activity..." -ForegroundColor Cyan

    \ = Get-Process | Select-Object Name, Id, CPU
    Start-Sleep -Seconds 10
    \ = Get-Process | Select-Object Name, Id, CPU

    \ = Compare-Object \ \ -Property Name, Id, CPU -PassThru | 
        Where-Object { \.SideIndicator -eq '=>' -and \.CPU -gt 50 }

    if (\) {
        Write-Warning "⚠️ Anomaly detected in process behavior:"
        \ | Format-Table
    } else {
        Write-Host "✅ No anomalies detected." -ForegroundColor Green
    }
}
