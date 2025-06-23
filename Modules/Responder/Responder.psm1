# Responder.psm1

# Import individual responder function files
. "$PSScriptRoot\Stop-MaliciousProcess.ps1"
. "$PSScriptRoot\Set-Quarantine.ps1"
. "$PSScriptRoot\Block-ThreatIP.ps1"
. "$PSScriptRoot\Invoke-Isolation.ps1"
. "$PSScriptRoot\Start-AutoRemediate.ps1"
. "$PSScriptRoot\Invoke-ScriptgeistResponder.ps1"

# Export public functions
Export-ModuleMember -Function `
    Stop-MaliciousProcess, `
    Set-Quarantine, `
    Block-ThreatIP, `
    Invoke-Isolation, `
    Start-AutoRemediate, `
    Invoke-ScriptgeistResponder
