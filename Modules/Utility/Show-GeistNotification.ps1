function Show-GeistNotification {
    [CmdletBinding()]
    param (
        [string]$Title,
        [string]$Message
    )

    if ($IsWindows) {
        try {
            Import-Module BurntToast -ErrorAction Stop
            New-BurntToastNotification -Text $Title, $Message
        } catch {
            Write-Warning "Toast notification failed: $_"
            Write-Host "$Title`n$Message" -ForegroundColor Yellow
        }
    } elseif ($IsLinux -or $IsMacOS) {
        if (Get-Command notify-send -ErrorAction SilentlyContinue) {
            Start-Process "notify-send" -ArgumentList @("$Title", "$Message")
        } elseif ($IsMacOS) {
            $osaScript = "display notification `"$Message`" with title `"$Title`""
            osascript -e $osaScript
        } else {
            Write-Host "$Title`n$Message" -ForegroundColor Yellow
        }
    } else {
        Write-Host "$Title`n$Message" -ForegroundColor Yellow
    }
}
