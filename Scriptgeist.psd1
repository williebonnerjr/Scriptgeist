@{
    RootModule        = 'Scriptgeist.psm1'
    ModuleVersion     = '2.0.0'
    Author            = 'Willie Bonner Jr'
    Description       = 'An intelligent PowerShell sentinel for system monitoring, anomaly detection, and proactive defense.'
    PowerShellVersion = '7.0'
    GUID              = '953244c8-968e-44ac-a158-d95677d2b8eb'
    Copyright         = '(c) 2025 Willie Bonner Jr. All rights reserved.'

    FunctionsToExport = @(
        # Core Launcher
        'Start-Scriptgeist',

        # Watchers (Monitoring Modules)
        'Watch-ProcessAnomalies',
        'Watch-NetworkAnomalies',
        'Watch-LogTampering',
        'Watch-CredentialArtifacts',
        'Watch-GuestSessions',
        'Watch-SystemIntegrity',
        'Watch-PersistenceMechanisms',
        'Watch-FileSurveillance',
        'Watch-PrivilegedEscalations',
        'Watch-UserAccountChanges',
        'Watch-ExternalMounts',
        'Watch-RemoteAccessChanges',
        'Watch-SystemLogs',
        'Get-SystemLogs',

        # Responder Actions
        'Stop-MaliciousProcess',
        'Set-Quarantine',
        'Block-ThreatIP',
        'Invoke-Isolation',
        'Start-AutoRemediate'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('security', 'defense', 'monitoring', 'cybersecurity', 'powershell', 'forensics', 'incident-response')
            ProjectUri   = 'https://github.com/williebonnerjr/Scriptgeist'
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ReleaseNotes = 'v2.0.0 - Added responder module, credential artifact detection, GUI hooks, and CLI enhancements.'
        }
    }
}
