@{
    RootModule        = 'Scriptgeist.psm1'
    ModuleVersion     = '2.0.0'
    GUID              = '953244c8-968e-44ac-a158-d95677d2b8eb'
    Author            = 'Willie Bonner Jr'
    CompanyName       = 'Scriptgeist Security'
    Description       = 'An intelligent PowerShell sentinel for system monitoring, anomaly detection, and proactive defense.'
    PowerShellVersion = '7.0'
    Copyright         = '(c) 2025 Willie Bonner Jr. All rights reserved.'

    # Exported Functions
    FunctionsToExport = @(
        # Core
        'Start-Scriptgeist',

        # Watchers
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

    # Optional Exports
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    # Module Metadata
    PrivateData = @{
        PSData = @{
            Tags         = @('security', 'defense', 'monitoring', 'cybersecurity', 'powershell', 'forensics', 'incident-response')
            ProjectUri   = 'https://github.com/williebonnerjr/Scriptgeist'
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ReleaseNotes = 'v2.0.0 - Added responder module, credential artifact detection, GUI hooks, and CLI enhancements.'
        }
    }

    # Compatibility
    CompatiblePSEditions = @('Core', 'Desktop')
    NestedModules        = @()
    RequiredAssemblies   = @()
    RequiredModules      = @()
    FileList             = @()
    HelpInfoURI          = 'https://github.com/williebonnerjr/Scriptgeist/wiki'
    DefaultCommandPrefix = ''
}
