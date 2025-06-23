function Show-GeistNotification {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Message
    )

    try {
        if ($IsWindows) {
            if (-not (Get-Module -Name BurntToast)) {
                Import-Module BurntToast -ErrorAction Stop
            }
            New-BurntToastNotification -Text $Title, $Message
        } elseif ($IsLinux -or $IsMacOS) {
            if (Get-Command notify-send -ErrorAction SilentlyContinue) {
                Start-Process "notify-send" -ArgumentList @("$Title", "$Message") -NoNewWindow
            } elseif ($IsMacOS -and (Get-Command osascript -ErrorAction SilentlyContinue)) {
                $osaScript = "display notification `"$Message`" with title `"$Title`""
                osascript -e $osaScript
            } else {
                Write-Host "[Fallback] $Title`n$Message" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[Unsupported] $Title`n$Message" -ForegroundColor Yellow
        }
    } catch {
        Write-Warning "Notification failed: $_"
        Write-Host "[Error] $Title`n$Message" -ForegroundColor Red
    }
}
