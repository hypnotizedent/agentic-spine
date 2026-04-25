#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows First-Touch Remote Admin Bootstrap

.DESCRIPTION
    Brings a console-only Windows machine to a proved SSH remote-admin plane.
    Idempotent, single-file, zero-dependency. Runs from elevated PowerShell.

    This script is the missing producer beneath require_remote_access_reachable
    in ops/bindings/operator.hardware.readiness.profiles.yaml.

    Truth boundary:
      OWNS: OpenSSH bring-up, optional Tailscale bring-up, local self-proof, receipt
      DOES NOT OWN: admission, ssh.targets.yaml, eligibility, fleet policy, tool baseline

.PARAMETER AdminUsers
    Optional string array of local usernames to record as SSH admin users.
    Default: current executing user.

.PARAMETER InstallTailscale
    If set, install Tailscale via winget if not already present.

.PARAMETER EnableTailscaleSsh
    If set, enable Tailscale SSH (requires Tailscale installed).

.PARAMETER TailscaleAuthKey
    Optional Tailscale auth key for enrollment in the same run.
    Only used if -InstallTailscale is also set or Tailscale is already installed.

.PARAMETER ReceiptPath
    Override default receipt output path.
    Default: C:\ProgramData\Spine\receipts\windows-first-touch-remote-admin.json

.PARAMETER SkipSelfTest
    Skip the localhost SSH self-test step.

.EXAMPLE
    .\windows-first-touch-remote-admin.ps1
    # Zero-config: install OpenSSH, start sshd, open firewall, emit receipt

.EXAMPLE
    .\windows-first-touch-remote-admin.ps1 -InstallTailscale -TailscaleAuthKey "tskey-auth-..."
    # Also install Tailscale and enroll with auth key
#>

[CmdletBinding()]
param(
    [string[]]$AdminUsers,
    [switch]$InstallTailscale,
    [switch]$EnableTailscaleSsh,
    [string]$TailscaleAuthKey,
    [string]$ReceiptPath,
    [switch]$SkipSelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Constants ─────────────────────────────────────────────────────────────────

$Script:DefaultReceiptDir = 'C:\ProgramData\Spine\receipts'
$Script:DefaultReceiptFile = 'windows-first-touch-remote-admin.json'
$Script:CapabilityName = 'windows.first_touch.remote_admin.bootstrap'
$Script:MinBuild = 19045  # Windows 10 22H2

# ── Receipt accumulator ──────────────────────────────────────────────────────

$Script:Steps = [System.Collections.ArrayList]::new()
$Script:HardFail = $false
$Script:OverallStatus = 'ok'

function Add-Step {
    param(
        [string]$Id,
        [ValidateSet('ok','skip','fail')]
        [string]$Status,
        [string]$Detail
    )
    $null = $Script:Steps.Add([ordered]@{
        id     = $Id
        status = $Status
        detail = $Detail
    })
    if ($Status -eq 'fail') {
        $Script:OverallStatus = 'fail'
        $Script:HardFail = $true
    }
    if ($Status -eq 'fail') {
        Write-Host "  FAIL: $Detail" -ForegroundColor Red
    } elseif ($Status -eq 'skip') {
        Write-Host "  SKIP: $Detail" -ForegroundColor Yellow
    } else {
        Write-Host "  OK:   $Detail" -ForegroundColor Green
    }
}

# ── Step 1: Validate elevation and OS ────────────────────────────────────────

Write-Host "`n=== Windows First-Touch Remote Admin Bootstrap ===" -ForegroundColor Cyan
Write-Host ""

# Elevation is enforced by #Requires -RunAsAdministrator, but belt-and-suspenders:
$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Add-Step -Id 'validate_elevation' -Status 'fail' -Detail 'Not running as Administrator. Re-run from elevated PowerShell.'
    # Emit partial receipt and exit
    $receipt = Build-Receipt
    Write-Output ($receipt | ConvertTo-Json -Depth 10)
    exit 1
}
Add-Step -Id 'validate_elevation' -Status 'ok' -Detail 'Running as Administrator.'

# OS version check
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
$osCaption = $osInfo.Caption
$osVersion = $osInfo.Version
$osBuild = [int]($osInfo.BuildNumber)

$osSupported = $osBuild -ge $Script:MinBuild
if (-not $osSupported) {
    Add-Step -Id 'validate_os' -Status 'fail' -Detail "OS build $osBuild is below minimum $Script:MinBuild (Windows 10 22H2). Caption: $osCaption"
    $receipt = Build-Receipt
    Write-Output ($receipt | ConvertTo-Json -Depth 10)
    exit 1
}
Add-Step -Id 'validate_os' -Status 'ok' -Detail "OS supported: $osCaption (build $osBuild)."

# ── Step 2: Detect current state ─────────────────────────────────────────────

Write-Host "`n--- Detecting current state ---" -ForegroundColor Cyan

# OpenSSH Server capability
$opensshCapability = Get-WindowsCapability -Online | Where-Object { $_.Name -like 'OpenSSH.Server*' }
$opensshInstalled = $false
if ($opensshCapability -and $opensshCapability.State -eq 'Installed') {
    $opensshInstalled = $true
}

# sshd service
$sshdService = $null
try {
    $sshdService = Get-Service -Name sshd -ErrorAction SilentlyContinue
} catch {
    # Service doesn't exist yet
}
$sshdRunning = $false
$sshdStartType = $null
if ($sshdService) {
    $sshdRunning = $sshdService.Status -eq 'Running'
    $sshdStartType = (Get-CimInstance -ClassName Win32_Service -Filter "Name='sshd'").StartMode
}

# Firewall rule
$fwRule = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
$fwRulePresent = $null -ne $fwRule
$fwRuleEnabled = $fwRulePresent -and $fwRule.Enabled -eq 'True'

# Tailscale
$tailscaleInstalled = $null -ne (Get-Command tailscale -ErrorAction SilentlyContinue)
$tailscaleSshEnabled = $false
if ($tailscaleInstalled) {
    try {
        $tsStatus = & tailscale status --json 2>$null | ConvertFrom-Json
        if ($tsStatus.Self.CapMap -and $tsStatus.Self.CapMap.PSObject.Properties.Name -contains 'ssh') {
            $tailscaleSshEnabled = $true
        }
    } catch {
        # Cannot determine — leave false
    }
}

$stateDetail = "OpenSSH=$opensshInstalled, sshd=$sshdRunning/$sshdStartType, FW=$fwRulePresent/$fwRuleEnabled, Tailscale=$tailscaleInstalled, TailscaleSSH=$tailscaleSshEnabled"
Add-Step -Id 'detect_state' -Status 'ok' -Detail $stateDetail

# ── Step 3: Enable/install OpenSSH Server ────────────────────────────────────

Write-Host "`n--- OpenSSH Server ---" -ForegroundColor Cyan

if ($opensshInstalled) {
    Add-Step -Id 'install_openssh' -Status 'skip' -Detail 'OpenSSH Server capability already installed.'
} else {
    if (-not $opensshCapability) {
        Add-Step -Id 'install_openssh' -Status 'fail' -Detail 'OpenSSH.Server capability not available on this OS image.'
        $receipt = Build-Receipt
        Write-Output ($receipt | ConvertTo-Json -Depth 10)
        exit 1
    }
    try {
        $result = Add-WindowsCapability -Online -Name $opensshCapability.Name
        if ($result.RestartNeeded) {
            Add-Step -Id 'install_openssh' -Status 'ok' -Detail 'OpenSSH Server installed. NOTE: restart may be required.'
            $Script:OverallStatus = 'warn'
        } else {
            Add-Step -Id 'install_openssh' -Status 'ok' -Detail 'OpenSSH Server installed successfully.'
        }
        $opensshInstalled = $true
    } catch {
        Add-Step -Id 'install_openssh' -Status 'fail' -Detail "OpenSSH Server install failed: $_"
        $receipt = Build-Receipt
        Write-Output ($receipt | ConvertTo-Json -Depth 10)
        exit 1
    }
}

# ── Step 4: Set sshd to automatic and start ──────────────────────────────────

Write-Host "`n--- sshd service ---" -ForegroundColor Cyan

# Re-check service after potential install
$sshdService = Get-Service -Name sshd -ErrorAction SilentlyContinue
if (-not $sshdService) {
    Add-Step -Id 'configure_sshd' -Status 'fail' -Detail 'sshd service not found after OpenSSH install.'
    $receipt = Build-Receipt
    Write-Output ($receipt | ConvertTo-Json -Depth 10)
    exit 1
}

$sshdStartType = (Get-CimInstance -ClassName Win32_Service -Filter "Name='sshd'").StartMode
$sshdRunning = $sshdService.Status -eq 'Running'

$sshdChanged = $false
if ($sshdStartType -ne 'Auto') {
    Set-Service -Name sshd -StartupType Automatic
    $sshdChanged = $true
}
if (-not $sshdRunning) {
    try {
        Start-Service sshd
        $sshdChanged = $true
    } catch {
        Add-Step -Id 'configure_sshd' -Status 'fail' -Detail "Failed to start sshd: $_"
        $receipt = Build-Receipt
        Write-Output ($receipt | ConvertTo-Json -Depth 10)
        exit 1
    }
}

if ($sshdChanged) {
    Add-Step -Id 'configure_sshd' -Status 'ok' -Detail 'sshd set to Automatic and started.'
} else {
    Add-Step -Id 'configure_sshd' -Status 'skip' -Detail 'sshd already Automatic and running.'
}

# Also ensure ssh-agent is automatic and started (needed for key-based auth)
$sshAgentService = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
if ($sshAgentService) {
    $agentStartType = (Get-CimInstance -ClassName Win32_Service -Filter "Name='ssh-agent'").StartMode
    if ($agentStartType -ne 'Auto' -or $sshAgentService.Status -ne 'Running') {
        Set-Service -Name ssh-agent -StartupType Automatic
        Start-Service ssh-agent -ErrorAction SilentlyContinue
    }
}

# ── Step 5: Firewall rule ────────────────────────────────────────────────────

Write-Host "`n--- Firewall ---" -ForegroundColor Cyan

if ($fwRulePresent -and $fwRuleEnabled) {
    Add-Step -Id 'firewall_rule' -Status 'skip' -Detail 'Inbound TCP 22 rule already present and enabled.'
} elseif ($fwRulePresent -and -not $fwRuleEnabled) {
    try {
        Set-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -Enabled True
        Add-Step -Id 'firewall_rule' -Status 'ok' -Detail 'Existing firewall rule enabled.'
    } catch {
        Add-Step -Id 'firewall_rule' -Status 'fail' -Detail "Failed to enable firewall rule: $_"
        $receipt = Build-Receipt
        Write-Output ($receipt | ConvertTo-Json -Depth 10)
        exit 1
    }
} else {
    try {
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' `
            -DisplayName 'OpenSSH Server (sshd) - Spine Bootstrap' `
            -Enabled True `
            -Direction Inbound `
            -Protocol TCP `
            -Action Allow `
            -LocalPort 22 `
            -Profile Any | Out-Null
        Add-Step -Id 'firewall_rule' -Status 'ok' -Detail 'Inbound TCP 22 firewall rule created.'
    } catch {
        Add-Step -Id 'firewall_rule' -Status 'fail' -Detail "Failed to create firewall rule: $_"
        $receipt = Build-Receipt
        Write-Output ($receipt | ConvertTo-Json -Depth 10)
        exit 1
    }
}

# ── Step 6: SSH admin posture ────────────────────────────────────────────────

Write-Host "`n--- SSH admin posture ---" -ForegroundColor Cyan

$adminAuthSurface = 'unknown'
$recordedAdminUsers = @()

# Windows OpenSSH uses ProgramData\ssh\administrators_authorized_keys for admin users
# and user-profile .ssh\authorized_keys for non-admin users.
# The sshd_config Match Group administrators block controls which file is used.

$sshdConfigPath = "$env:ProgramData\ssh\sshd_config"
$adminsKeyFile = "$env:ProgramData\ssh\administrators_authorized_keys"
$userProfileKeyFile = "$env:USERPROFILE\.ssh\authorized_keys"

if (Test-Path $sshdConfigPath) {
    $sshdConfig = Get-Content $sshdConfigPath -Raw
    # Check if the administrators_authorized_keys override is active (default on Windows)
    if ($sshdConfig -match 'administrators_authorized_keys') {
        $adminAuthSurface = 'administrators_authorized_keys'
    } else {
        $adminAuthSurface = 'user_profile_authorized_keys'
    }
} else {
    $adminAuthSurface = 'unknown'
}

# Record admin users
if (-not $AdminUsers) {
    $AdminUsers = @($env:USERNAME)
}
$recordedAdminUsers = $AdminUsers

# Check if authorized_keys files exist
$adminsKeyExists = Test-Path $adminsKeyFile
$userKeyExists = Test-Path $userProfileKeyFile

$posDetail = "auth_surface=$adminAuthSurface, admins_key_exists=$adminsKeyExists, user_key_exists=$userKeyExists, recorded_users=$($recordedAdminUsers -join ',')"
Add-Step -Id 'ssh_admin_posture' -Status 'ok' -Detail $posDetail

# ── Step 7: Optional Tailscale install ───────────────────────────────────────

Write-Host "`n--- Tailscale ---" -ForegroundColor Cyan

$tailscaleRequested = $InstallTailscale.IsPresent
$tailscaleEnrollmentAttempted = $false

if (-not $tailscaleRequested) {
    Add-Step -Id 'tailscale_install' -Status 'skip' -Detail 'Tailscale install not requested.'
} elseif ($tailscaleInstalled) {
    Add-Step -Id 'tailscale_install' -Status 'skip' -Detail 'Tailscale already installed.'
} else {
    # Try winget first
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        try {
            & winget install --id Tailscale.Tailscale --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-Null
            # Refresh path
            $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
            $tailscaleInstalled = $null -ne (Get-Command tailscale -ErrorAction SilentlyContinue)
            if ($tailscaleInstalled) {
                Add-Step -Id 'tailscale_install' -Status 'ok' -Detail 'Tailscale installed via winget.'
            } else {
                Add-Step -Id 'tailscale_install' -Status 'fail' -Detail 'winget install succeeded but tailscale binary not found on PATH.'
            }
        } catch {
            Add-Step -Id 'tailscale_install' -Status 'fail' -Detail "winget install failed: $_"
        }
    } else {
        Add-Step -Id 'tailscale_install' -Status 'fail' -Detail 'winget not available. Manual Tailscale install required.'
    }

    # Enroll if auth key provided and Tailscale is now installed
    if ($tailscaleInstalled -and $TailscaleAuthKey) {
        try {
            & tailscale up --authkey $TailscaleAuthKey 2>&1 | Out-Null
            $tailscaleEnrollmentAttempted = $true
            Add-Step -Id 'tailscale_enroll' -Status 'ok' -Detail 'Tailscale enrollment attempted with auth key.'
        } catch {
            $tailscaleEnrollmentAttempted = $true
            Add-Step -Id 'tailscale_enroll' -Status 'fail' -Detail "Tailscale enrollment failed: $_"
        }
    }
}

# ── Step 8: Optional Tailscale SSH ───────────────────────────────────────────

$tailscaleSshRequested = $EnableTailscaleSsh.IsPresent

if (-not $tailscaleSshRequested) {
    Add-Step -Id 'tailscale_ssh' -Status 'skip' -Detail 'Tailscale SSH not requested.'
} elseif (-not $tailscaleInstalled) {
    Add-Step -Id 'tailscale_ssh' -Status 'skip' -Detail 'Tailscale not installed — cannot enable Tailscale SSH.'
} elseif ($tailscaleSshEnabled) {
    Add-Step -Id 'tailscale_ssh' -Status 'skip' -Detail 'Tailscale SSH already enabled.'
} else {
    try {
        & tailscale set --ssh 2>&1 | Out-Null
        Add-Step -Id 'tailscale_ssh' -Status 'ok' -Detail 'Tailscale SSH enabled.'
        $tailscaleSshEnabled = $true
    } catch {
        Add-Step -Id 'tailscale_ssh' -Status 'fail' -Detail "Failed to enable Tailscale SSH: $_"
    }
}

# ── Step 9: Self-test ────────────────────────────────────────────────────────

Write-Host "`n--- Self-test ---" -ForegroundColor Cyan

$selfTestResult = 'skip'
if ($SkipSelfTest.IsPresent) {
    Add-Step -Id 'self_test' -Status 'skip' -Detail 'Self-test skipped by operator.'
} else {
    # Test that sshd is listening on port 22
    try {
        $tcpTest = Test-NetConnection -ComputerName localhost -Port 22 -WarningAction SilentlyContinue
        if ($tcpTest.TcpTestSucceeded) {
            $selfTestResult = 'pass'
            Add-Step -Id 'self_test' -Status 'ok' -Detail 'Localhost TCP 22 reachable — sshd is listening.'
        } else {
            $selfTestResult = 'fail'
            Add-Step -Id 'self_test' -Status 'fail' -Detail 'Localhost TCP 22 not reachable — sshd may not be listening.'
        }
    } catch {
        $selfTestResult = 'fail'
        Add-Step -Id 'self_test' -Status 'fail' -Detail "Self-test error: $_"
    }
}

# ── Step 10: Emit receipt ────────────────────────────────────────────────────

Write-Host "`n--- Receipt ---" -ForegroundColor Cyan

# Resolve receipt path
if (-not $ReceiptPath) {
    $ReceiptPath = Join-Path $Script:DefaultReceiptDir $Script:DefaultReceiptFile
}

# Re-read final service state for receipt accuracy
$finalSshdService = Get-Service -Name sshd -ErrorAction SilentlyContinue
$finalSshdRunning = $finalSshdService -and $finalSshdService.Status -eq 'Running'
$finalSshdStartType = 'unknown'
if ($finalSshdService) {
    $finalSshdStartType = (Get-CimInstance -ClassName Win32_Service -Filter "Name='sshd'").StartMode
}

$finalFwRule = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
$finalFwPresent = $null -ne $finalFwRule

# Determine next operator action
$nextAction = 'none'
if ($Script:HardFail) {
    $nextAction = 'Investigate and fix failures above, then re-run.'
} elseif (-not $adminsKeyExists -and -not $userKeyExists) {
    $nextAction = 'Deploy SSH public key to enable key-based authentication.'
} elseif ($Script:OverallStatus -eq 'warn') {
    $nextAction = 'Restart may be required. Reboot, then re-run to confirm.'
} else {
    $nextAction = 'SSH admin plane is ready. Test remote access from operator workstation.'
}

$receipt = [ordered]@{
    capability       = $Script:CapabilityName
    status           = $Script:OverallStatus
    executed_at      = (Get-Date -Format 'o')
    hostname         = $env:COMPUTERNAME
    os               = [ordered]@{
        caption   = $osCaption
        version   = $osVersion
        build     = $osBuild
        supported = $osSupported
    }
    steps            = $Script:Steps
    ssh              = [ordered]@{
        openssh_server_installed = $opensshInstalled
        service_start_mode       = $finalSshdStartType
        service_running          = $finalSshdRunning
        firewall_rule_present    = $finalFwPresent
        self_test                = $selfTestResult
        admin_auth_surface       = $adminAuthSurface
        recorded_admin_users     = $recordedAdminUsers
    }
    tailscale        = [ordered]@{
        requested            = $tailscaleRequested
        installed            = $tailscaleInstalled
        ssh_enabled          = $tailscaleSshEnabled
        enrollment_attempted = $tailscaleEnrollmentAttempted
    }
    receipt_path         = $ReceiptPath
    hard_fail            = $Script:HardFail
    next_operator_action = $nextAction
}

# Write receipt file
try {
    $receiptDir = Split-Path $ReceiptPath -Parent
    if (-not (Test-Path $receiptDir)) {
        New-Item -ItemType Directory -Path $receiptDir -Force | Out-Null
    }
    $receiptJson = $receipt | ConvertTo-Json -Depth 10
    $receiptJson | Set-Content -Path $ReceiptPath -Encoding UTF8
    Add-Step -Id 'emit_receipt' -Status 'ok' -Detail "Receipt written to $ReceiptPath"
} catch {
    Add-Step -Id 'emit_receipt' -Status 'fail' -Detail "Failed to write receipt: $_"
    # Still output to stdout
}

# Always print to stdout
Write-Host ""
$finalJson = $receipt | ConvertTo-Json -Depth 10
Write-Output $finalJson

# Summary
Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Status: $($Script:OverallStatus)" -ForegroundColor $(if ($Script:HardFail) { 'Red' } elseif ($Script:OverallStatus -eq 'warn') { 'Yellow' } else { 'Green' })
Write-Host "Next:   $nextAction"
Write-Host ""

if ($Script:HardFail) {
    exit 1
} else {
    exit 0
}
