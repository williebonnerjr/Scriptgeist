# ScriptgeistGUI.ps1
param (
    [string]$ModulePath = "$PSScriptRoot\Modules"
)

Write-Host "[*] Launching Scriptgeist GUI..." -ForegroundColor Cyan

# Detect platform
$IsWin = $IsWindows
$IsUnix = $IsLinux -or $IsMacOS

# Load module map
$modules = @(
    @{ Name = "Run All Modules"; Path = "ALL" },
    @{ Name = "Watch-CredentialArtifacts"; Path = "$ModulePath\Watch\Watch-CredentialArtifacts.ps1" },
    @{ Name = "Watch-GuestSessions"; Path = "$ModulePath\Watch\Watch-GuestSessions.ps1" },
    @{ Name = "Watch-SystemIntegrity"; Path = "$ModulePath\Watch\Watch-SystemIntegrity.ps1" },
    @{ Name = "Watch-PersistenceMechanisms"; Path = "$ModulePath\Watch\Watch-PersistenceMechanisms.ps1" },
    @{ Name = "Watch-LogTampering"; Path = "$ModulePath\Monitor\Watch-LogTampering.ps1" },
    @{ Name = "Watch-NetworkAnomalies"; Path = "$ModulePath\Monitor\Watch-NetworkAnomalies.ps1" }
)

# --- Windows Forms Interface ---
if ($IsWin) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object Windows.Forms.Form
    $form.Text = "Scriptgeist Security GUI"
    $form.Size = New-Object Drawing.Size(500, 400)
    $form.StartPosition = "CenterScreen"

    $label = New-Object Windows.Forms.Label
    $label.Text = "Select a watcher module:"
    $label.AutoSize = $true
    $label.Location = New-Object Drawing.Point(10, 10)
    $form.Controls.Add($label)

    $listBox = New-Object Windows.Forms.ListBox
    $listBox.Location = New-Object Drawing.Point(10, 40)
    $listBox.Size = New-Object Drawing.Size(460, 200)
    $modules | ForEach-Object { $listBox.Items.Add($_.Name) }
    $form.Controls.Add($listBox)

    $runButton = New-Object Windows.Forms.Button
    $runButton.Text = "Run Selected Module"
    $runButton.Location = New-Object Drawing.Point(10, 260)
    $runButton.Size = New-Object Drawing.Size(200, 30)
    $form.Controls.Add($runButton)

    $runButton.Add_Click({
        $selected = $listBox.SelectedItem
        if ($selected) {
            $mod = $modules | Where-Object { $_.Name -eq $selected }

            if ($mod.Path -eq "ALL") {
                # Launch Scriptgeist.ps1 with -Run All in new window
                Start-Process "powershell" "-NoExit -ExecutionPolicy Bypass -File `"$PSScriptRoot\Scriptgeist.ps1`" -Run All"
            }
            elseif (Test-Path $mod.Path) {
                Start-Process "powershell" "-NoExit -ExecutionPolicy Bypass -File `"$($mod.Path)`""
            }
            else {
                [System.Windows.Forms.MessageBox]::Show("Module not found: $($mod.Path)")
            }
        }
    })

    $form.ShowDialog()
}

# --- Terminal Interface for Linux/macOS ---
elseif ($IsUnix) {
    Write-Host "Available Modules:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $modules.Count; $i++) {
        Write-Host "$($i+1)) $($modules[$i].Name)"
    }

    $selection = Read-Host "Enter the number of the module to run"
    if ($selection -match '^\d+$') {
        $index = [int]$selection - 1
        if ($index -ge 0 -and $index -lt $modules.Count) {
            $mod = $modules[$index]
            if ($mod.Path -eq "ALL") {
                & "$PSScriptRoot/Scriptgeist.ps1" -Run All
            } elseif (Test-Path $mod.Path) {
                . $mod.Path
                & ($mod.Name) -OutputPrompt
            } else {
                Write-Warning "Module not found: $($mod.Path)"
            }
        }
    } else {
        Write-Warning "Invalid selection."
    }
}
else {
    Write-Warning "Unsupported operating system for GUI."
}
