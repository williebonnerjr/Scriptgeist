function Show-GeistNotification {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Message
    )

    Write-GeistLog -Message "[Notify] $Title → $Message"

    try {
        if ($IsWindows) {
            if (-not (Get-Module -Name BurntToast -ListAvailable)) {
                Write-Warning "BurntToast module not found. Falling back to console notification."
                Write-Host "[Windows Notification] $Title`n$Message" -ForegroundColor Yellow
            } else {
                Import-Module BurntToast -ErrorAction Stop
                New-BurntToastNotification -Text $Title, $Message
            }
        } elseif ($IsLinux) {
            if (Get-Command notify-send -ErrorAction SilentlyContinue) {
                Start-Process "notify-send" -ArgumentList @("$Title", "$Message") -NoNewWindow
            } else {
                Write-Host "[Linux Notification] $Title`n$Message" -ForegroundColor Yellow
            }
        } elseif ($IsMacOS) {
            if (Get-Command osascript -ErrorAction SilentlyContinue) {
                $osaScript = "display notification `"$Message`" with title `"$Title`""
                osascript -e $osaScript
            } else {
                Write-Host "[macOS Notification] $Title`n$Message" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[Unsupported OS] $Title`n$Message" -ForegroundColor Yellow
        }
    } catch {
        Write-GeistLog -Message "Notification failure: $_" -Type Warning
        Write-Warning "Notification failed: $_"
        Write-Host "[Error] $Title`n$Message" -ForegroundColor Red
    }
}
