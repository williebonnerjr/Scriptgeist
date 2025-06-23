@{
    RootModule        = 'Scriptgeist.psm1'
    ModuleVersion     = '1.1.0'
    Author            = 'Willie Bonner Jr'
    Description       = 'An intelligent PowerShell sentinel for system monitoring, anomaly detection, and proactive defense.'
    PowerShellVersion = '7.0'
    GUID              = '953244c8-968e-44ac-a158-d95677d2b8eb'
    Prerelease        = 'alpha'
    Copyright         = '(c) 2025 Willie Bonner Jr. All rights reserved.'
    LicenseUri        = 'https://opensource.org/licenses/MIT'
    ProjectUri        = 'https://github.com/wbonnerjr/Scriptgeist'

    FunctionsToExport = @(
        'Start-Scriptgeist',
        'Watch-ProcessAnomalies',
        'Watch-NetworkAnomalies',
        'Watch-LogTampering',
        'Watch-CredentialArtifacts',
        'Watch-GuestSessions',
        'Watch-SystemIntegrity',
        'Watch-PersistenceMechanisms',
        'Watch-FileSurveillance',
        'Watch-PrivilegedEscalations',
        'Get-SystemLogs'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
