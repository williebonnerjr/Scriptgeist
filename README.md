# Scriptgeist

![Scriptgeist Logo](Assets/Images/Scriptgeist%20Logo%20Design.png)

**Scriptgeist** is a smart, real-time sentinel that observes your system, detects anomalies, and alerts you like a personal JARVIS.
It can detect silent crypto miners, unauthorized processes, credential artifacts, and suspicious system behavior using modular PowerShell scripts.

---

## 🚦 Modules Overview

| Group                     | Purpose                                               |
| ------------------------- | ----------------------------------------------------- |
| **Monitor**               | Real-time system surveillance and forensic checks     |
| **Watch**                 | Targeted anomaly detection (logs, creds, persistence) |
| **Responder** *(planned)* | Countermeasures and auto-remediation                  |
| **AI** *(planned)*        | Log summarization and behavior analysis               |
| **GUI**                   | WinForms/Avalonia interface for interaction           |

---

## ✅ Current Modules

### 🔍 Monitor

* `Watch-NetworkAnomalies.ps1` – Detects DNS anomalies, suspicious TLDs, frequent external IPs, bandwidth spikes
* `Watch-LogTampering.ps1` – Detects evidence of log clearance, overwrites, or deletions
* `Watch-ProcessAnomalies.ps1` – Flags unsigned binaries, injection behavior, or suspicious execution
* `Watch-SystemLogs.ps1` – Analyzes system logs (Windows Event Log, Linux `journalctl`, etc.)
* `Watch-GuestSessions.ps1` – Detects use of guest accounts or temporary login patterns

### 🕵️ Watch

* `Watch-CredentialArtifacts.ps1` – Searches for secrets (passwords, wallets, API keys, vaults, browser profiles) in local files
* `Watch-SystemIntegrity.ps1` – Monitors core OS files and protected paths for tampering
* `Watch-PersistenceMechanisms.ps1` – Finds persistence via registry, startup folders, cron jobs, systemd services
* `Watch-FileSurveillance.ps1` – Monitors user and system directories for unauthorized or unexpected changes
* `Watch-PrivilegedEscalations.ps1` – Detects privilege escalation techniques (SUID files, UAC bypass, sudo misconfigs)
* `Watch-ExternalMounts.ps1` – Detects newly mounted removable media, remote shares, or unknown devices
* `Watch-RemoteAccessChanges.ps1` – Detects changes to RDP, SSH, or remote desktop configurations
* `Watch-LogReplicator.ps1` – Monitors duplication or sync of logs to untrusted locations
* `Watch_UserAccountChanges.ps1` – Detects addition, deletion, or modification of local user accounts

---

## 🖥️ Interfaces

### 🟢 GUI Mode

```powershell
.\GUI\ScriptgeistGUI.ps1
```

Launches a cross-platform graphical interface to explore and run modules interactively.

### ⚙️ CLI Mode

```powershell
.\Scriptgeist-CLI.ps1 --list
.\Scriptgeist-CLI.ps1 --run Watch-CredentialArtifacts --ModuleArgs "-AttentionOnly"
```

You can interactively provide arguments or pass them inline.
All CLI activity is automatically logged.

---

## 🧾 Logging Best Practice

⚠️ Always use the CLI tool to run modules when logs are important.

Using `Scriptgeist-CLI.ps1` ensures:

* Logs are saved to: `Logs/CLI-<Module>-<timestamp>.log`
* Output is preserved even if the module fails
* No need to specify `-LogPath` manually

❌ Do not pass `-LogPath` to modules directly.
✅ Let the CLI handle logging.

---

## 🧱 Project Structure

```
Scriptgeist/
├── .gitattributes
├── CHANGELOG.md
├── LICENSE
├── README.md
├── release.ps1
├── Scriptgeist-CLI.ps1
├── Scriptgeist.psd1
├── Scriptgeist.psm1
│
├── Assets/
│   ├── Fonts/
│   ├── Icons/
│   │   ├── Global Network in Minimalist Design.png
│   │   ├── Minimalist Document Icon on Paper Texture.png
│   │   └── Warning Icon with Exclamation Mark.png
│   ├── Images/
│   ├── Sounds/
│   ├── Status/
│   │   └── Star and Checkmark Symbol.png
│   ├── Styles/
│   └── Templates/
│
├── Docs/
│   └── Scriptgeist Docs
│
├── GUI/
│   └── ScriptgeistGUI.ps1
│
├── Logs/
│
├── Modules/
│   ├── AI/
│   ├── Monitor/
│   │   ├── Watch-GuestSessions.ps1
│   │   ├── Watch-ProcessAnomalies.ps1
│   │   └── Watch-SystemLogs.ps1
│   ├── Reporting/
│   │   ├── Export-GeistReport.ps1
│   │   └── Invoke-ReportScheduler.ps1
│   ├── Responder/
│   │   ├── Block-ThreatIP.ps1
│   │   ├── Invoke-Isolation.ps1
│   │   ├── Invoke-ScriptgeistResponder.ps1
│   │   ├── Responder.psm1
│   │   ├── Respondercore.ps1
│   │   ├── Set-Quarantine.ps1
│   │   ├── Start-AutoRemediation.ps1
│   │   └── Stop-MaliciousProcess.ps1
│   ├── Utility/
│   │   ├── GeistLog.ps1
│   │   ├── Get-GeistAlertSummary.ps1
│   │   └── Show-GeistNotification.ps1
│   └── Watch/
│       ├── Watch-CredentialArtifacts.ps1
│       ├── Watch-ExternalMounts.ps1
│       ├── Watch-FileSurveillance.ps1
│       ├── Watch-LogReplicator.ps1
│       ├── Watch-LogTampering.ps1
│       ├── Watch-NetworkAnomalies.ps1
│       ├── Watch-PersistenceMechanisms.ps1
│       ├── Watch-PrivilegedEscalations.ps1
│       ├── Watch-RemoteAccessChanges.ps1
│       ├── Watch-SystemIntegrity.ps1
│       ├── Watch-SystemLogs.ps1
│       └── Watch_UserAccountChanges.ps1
│
└── Tests/
```

---

## 🚧 Status

**Status:** Alpha
Modules are functional with full CLI+GUI support and persistent logging.
AI and Responder integration coming soon.

---

## 📜 License

MIT License
