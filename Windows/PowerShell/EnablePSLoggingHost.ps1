<#
Purpose:
This script simplifies enabling PowerShell logging on Windows systems, especially non-domain joined servers where centralized GPO-based audit configurations are commonly missed (e.g., DMZ environments).

The script supports two modes:
1. Guided mode:
   - Prompts the user interactively before enabling each logging option.

2. Parameter/switch mode:
   - Allows direct enablement using script parameters without requiring user interaction.
   - Suitable for remote deployment and automation tools such as SCCM or other script execution platforms.

Supported logging options:
- Script Block Logging
- Module Logging
- PowerShell Transcription Logging

Important Notes:
- This script modifies the backend policy registry paths under:
  HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell

- The script can work on both domain joined and non-domain joined systems.

- If Local Group Policy or Domain Group Policy explicitly configures these settings, those policies may override the registry values applied by this script.

- The script works best in environments where the related PowerShell logging policies remain "Not Configured" in Local/Domain GPO.

- PowerShell Transcription Logging may generate significant disk usage over time depending on server activity and retention configuration.

Examples:
# Guided mode:
.\EnablePSLoggingHost.ps1
#
# Enable standard recommended logging both ScriptBlock and Module
.\EnablePSLoggingHost.ps1 -Enable Standard
#
# Enable selected logging:
.\EnablePSLoggingHost.ps1 -Enable ScriptBlock
.\EnablePSLoggingHost.ps1 -Enable Module
.\EnablePSLoggingHost.ps1 -Enable Transcription
#
# Enable all:
.\EnablePSLoggingHost.ps1 -Enable All
#>

param(
    [ValidateSet("ScriptBlock", "Module", "Transcription", "Standard", "All")]
    [string[]]$Enable = @()
)



$defaultTranscriptPath = "C:\PowerShellTranscripts"
$changesMade = $false
$guidedMode = ($Enable.Count -eq 0)
$summary = @()

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "ERROR: Please run PowerShell as Administrator." -ForegroundColor Red
    Write-Host ""
    exit 1
}

function Should-Enable {
    param([string]$Key)

    if ($Enable -contains "All") {
        return $true
    }

    if ($Enable -contains "Standard") {
        return ($Key -in @("ScriptBlock", "Module"))
    }

    return ($Enable -contains $Key)
}

function Get-PolicyState {
    param(
        [string]$Path,
        [string]$ValueName
    )

    if (-not (Test-Path $Path)) {
        return "Not Configured"
    }

    try {
        $value = Get-ItemPropertyValue -Path $Path -Name $ValueName -ErrorAction Stop

        switch ($value) {
            1 { return "Enabled" }
            0 { return "Disabled" }
            default { return "Unknown ($value)" }
        }
    }
    catch {
        return "Not Configured"
    }
}

function Enable-PolicyValue {
    param(
        [string]$Path,
        [string]$ValueName
    )

    New-Item -Path $Path -Force -ErrorAction Stop | Out-Null

    New-ItemProperty `
        -Path $Path `
        -Name $ValueName `
        -Value 1 `
        -PropertyType DWord `
        -Force `
        -ErrorAction Stop | Out-Null
}

function Write-Section {
    param([string]$Title)

    Write-Host ""
    Write-Host "============================================================"
    Write-Host $Title
    Write-Host "============================================================"
}

Write-Section "Device Domain Status"

$computerSystem = Get-CimInstance Win32_ComputerSystem

if ($computerSystem.PartOfDomain -eq $true) {
    Write-Host "Domain Joined : Yes"
    Write-Host "Domain        : $($computerSystem.Domain)"
}
else {
    Write-Host "Domain Joined : No"
    Write-Host "Workgroup     : $($computerSystem.Workgroup)"
}

if ($guidedMode) {
    Write-Section "Mode"
    Write-Host "Mode          : Guided"
    Write-Host "Description   : You will be asked before enabling each disabled setting."
}
else {
    Write-Section "Mode"
    Write-Host "Mode          : Automatic"
    Write-Host "Requested     : $($Enable -join ', ')"
    Write-Host "Description   : Only requested logging options will be enabled. Others will only be reported."
}

$checks = @(
    @{
        Key   = "ScriptBlock"
        Name  = "Script Block Logging"
        Path  = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
        Value = "EnableScriptBlockLogging"
    },
    @{
        Key   = "Module"
        Name  = "Module Logging"
        Path  = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging"
        Value = "EnableModuleLogging"
    },
    @{
        Key   = "Transcription"
        Name  = "Transcription Logging"
        Path  = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription"
        Value = "EnableTranscripting"
    }
)

Write-Section "PowerShell Logging Configuration"

foreach ($check in $checks) {

    $initialState = Get-PolicyState -Path $check.Path -ValueName $check.Value
    $finalState = $initialState
    $action = "No change"
    $transcriptPath = "N/A"

    if ($check.Key -eq "Transcription") {
        try {
            $existingPath = Get-ItemPropertyValue `
                -Path $check.Path `
                -Name "OutputDirectory" `
                -ErrorAction Stop

            if (-not [string]::IsNullOrWhiteSpace($existingPath)) {
                $transcriptPath = $existingPath
            }
            else {
                $transcriptPath = $defaultTranscriptPath
            }
        }
        catch {
            $transcriptPath = $defaultTranscriptPath
        }
    }

    Write-Host ""
    Write-Host "Setting       : $($check.Name)"
    Write-Host "Current State : $initialState"

    $shouldEnableNow = $false

    if ($initialState -ne "Enabled") {

        if ($guidedMode) {

            if ($check.Key -eq "Transcription") {
                Write-Host ""
                Write-Host "Transcription Logging Warning:"
                Write-Host "- This can consume significant disk space over time."
                Write-Host "- Retention and cleanup must be planned."
                Write-Host "- Transcripts may contain sensitive commands, output, tokens, or credentials."
                Write-Host "- Current/default transcript path: $transcriptPath"
                Write-Host ""

                $changePath = Read-Host "Do you want to change the transcript storage location before enabling it? (Y/N)"

                if ($changePath -match "^[Yy]$") {
                    $customPath = Read-Host "Enter the full transcript path"

                    if (-not [string]::IsNullOrWhiteSpace($customPath)) {
                        $transcriptPath = $customPath
                    }
                }

                Write-Host "Selected transcript path: $transcriptPath"
            }

            $answer = Read-Host "Enable $($check.Name)? (Y/N)"

            if ($answer -match "^[Yy]$") {
                $shouldEnableNow = $true
            }
        }
        else {
            $shouldEnableNow = Should-Enable $check.Key
        }

        if ($shouldEnableNow) {
            try {
                Enable-PolicyValue -Path $check.Path -ValueName $check.Value

                if ($check.Key -eq "Module") {
                    $modulePath = "$($check.Path)\ModuleNames"

                    New-Item -Path $modulePath -Force -ErrorAction Stop | Out-Null

                    New-ItemProperty `
                        -Path $modulePath `
                        -Name "*" `
                        -Value "*" `
                        -PropertyType String `
                        -Force `
                        -ErrorAction Stop | Out-Null

                    Write-Host "Module Scope  : All PowerShell modules (*)"
                    Write-Host "Explanation   : The wildcard means module logging applies to all modules, not only selected module names."
                }

                if ($check.Key -eq "Transcription") {
                    if (-not (Test-Path $transcriptPath)) {
                        New-Item `
                            -ItemType Directory `
                            -Path $transcriptPath `
                            -Force `
                            -ErrorAction Stop | Out-Null
                    }

                    New-ItemProperty `
                        -Path $check.Path `
                        -Name "OutputDirectory" `
                        -Value $transcriptPath `
                        -PropertyType String `
                        -Force `
                        -ErrorAction Stop | Out-Null

                    Write-Host "Transcript Path: $transcriptPath"
                }

                $finalState = "Enabled"
                $changesMade = $true
                $action = "Enabled"

                Write-Host "Action        : Enabled successfully"
            }
            catch {
                $finalState = Get-PolicyState -Path $check.Path -ValueName $check.Value
                $action = "Failed: $($_.Exception.Message)"

                Write-Host "Action        : Failed" -ForegroundColor Red
                Write-Host "Error         : $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        else {
            if ($guidedMode) {
                $action = "Skipped by user"
                Write-Host "Action        : Skipped by user"
            }
            else {
                $action = "Not selected"
                Write-Host "Action        : Not selected for enablement"
            }
        }
    }
    else {
        Write-Host "Action        : Already enabled"
        $action = "Already enabled"
    }

    $summary += [PSCustomObject]@{
        Feature      = $check.Name
        InitialState = $initialState
        FinalState   = Get-PolicyState -Path $check.Path -ValueName $check.Value
        Action       = $action
        Path         = if ($check.Key -eq "Transcription") { $transcriptPath } else { "-" }
    }
}

Write-Section "Final Summary"

$summary | Format-Table -AutoSize

if ($changesMade) {
    Write-Host ""
    Write-Host "Notes:"
    Write-Host "- Changes were applied to HKLM policy registry paths."
    Write-Host "- Close and reopen PowerShell sessions for changes to fully apply."
    Write-Host "- If Local GPO or Domain GPO explicitly disables these settings, it may override the registry values later."
}
else {
    Write-Host ""
    Write-Host "No configuration changes were made."
}

Write-Host ""
Write-Host "Completed."
