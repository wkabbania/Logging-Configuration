# Run PowerShell as Administrator
# Transcription is commented remove the comment section if needed to be enabled
# =========================================================
# Enable Script Block Logging
# =========================================================

New-Item `
-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" `
-Force | Out-Null

New-ItemProperty `
-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" `
-Name "EnableScriptBlockLogging" `
-Value 1 `
-PropertyType DWord `
-Force | Out-Null

Write-Host "Script Block Logging enabled"


# =========================================================
# Enable Module Logging
# =========================================================

New-Item `
-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" `
-Force | Out-Null

New-ItemProperty `
-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" `
-Name "EnableModuleLogging" `
-Value 1 `
-PropertyType DWord `
-Force | Out-Null

New-Item `
-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames" `
-Force | Out-Null

New-ItemProperty `
-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames" `
-Name "*" `
-Value "*" `
-PropertyType String `
-Force | Out-Null

Write-Host "Module Logging enabled for all PowerShell modules"

<#
# =========================================================
# Enable PowerShell Transcription Logging
# =========================================================

$TranscriptPath = "C:\PowerShellTranscripts"

if (-not (Test-Path $TranscriptPath)) {
    New-Item `
    -ItemType Directory `
    -Path $TranscriptPath `
    -Force | Out-Null
}

New-Item `
-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" `
-Force | Out-Null

New-ItemProperty `
-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" `
-Name "EnableTranscripting" `
-Value 1 `
-PropertyType DWord `
-Force | Out-Null

New-ItemProperty `
-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" `
-Name "OutputDirectory" `
-Value $TranscriptPath `
-PropertyType String `
-Force | Out-Null

Write-Host "PowerShell Transcription Logging enabled"
Write-Host "Transcript path: $TranscriptPath"
#>
# =========================================================

Write-Host ""
Write-Host "========== Final Configuration =========="

Get-ItemProperty `
"HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"

Get-ItemProperty `
"HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging"

Get-ItemProperty `
"HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription"

Write-Host ""
Write-Host "Close and reopen PowerShell sessions for changes to fully apply."
