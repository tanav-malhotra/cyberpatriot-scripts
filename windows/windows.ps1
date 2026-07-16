# ====================================================================================
# CyberPatriot Windows Hardening Script
# Authors: Tanav Malhotra (GitHub: https://github.com/tanav-malhotra), Bryan Lochan
# License: GNU General Public License v3.0 (https://www.gnu.org/licenses/gpl-3.0.html)
#
# This revision restructures the original windows.ps1 for speed and safety, with
# improvements informed by past CyberPatriot answer keys (2024-2025 rounds).
#
# Design goals of this revision:
#   1. ALL questions are asked up front - after that the script runs unattended.
#   2. One secedit export/apply pass instead of three (much faster).
#   3. One recursive scan of C:\Users instead of two (much faster).
#   4. No slow synchronous Windows Update COM search, no double gpupdate /force.
#   5. Removed changes that BREAK the image (disabling RpcSs) or LOSE points
#      (opening inbound port 80, disabling TermService after choosing to keep RDP).
#   6. Added the audit/report sections answer keys score every round:
#      prohibited apps, shares, persistence (Run keys / scheduled tasks / startup),
#      listening ports, suspicious user files.
# ====================================================================================

#Requires -Version 5.1

##### LOGGING #####
$LOGFILE = Join-Path (Get-Location).Path "windows_script.log"
if (Test-Path $LOGFILE) { Remove-Item $LOGFILE -Force }

function log {
    param([string]$Message, [ConsoleColor]$Color = [ConsoleColor]::Gray)
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $LOGFILE -Value "[$(Get-Date -Format 'HH:mm:ss')] $Message"
}
function log_info {
    param([string]$Message)
    Add-Content -Path $LOGFILE -Value "[$(Get-Date -Format 'HH:mm:ss')] $Message"
}
# Wraps a block so one failure never stops the run; logs errors to file only.
function Try-Step {
    param([string]$Name, [scriptblock]$Action)
    try { & $Action } catch { log_info "error: $Name failed: $_" }
}

##### CHECK FOR ADMIN #####
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Please run this script as an administrator."
    exit 1
}

$scriptStart = Get-Date
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split('\')[-1]

# ====================================================================================
# PHASE 0: ASK EVERYTHING UP FRONT
# The original scattered Read-Host prompts through the whole script, so it sat idle
# waiting for input between slow operations. Collect every answer now; the rest runs
# start-to-finish with zero interaction.
# ====================================================================================
Write-Host "`n================ CYBERPATRIOT SETUP QUESTIONS ================" -ForegroundColor Cyan
Write-Host "Answer these from the README. Everything after this runs unattended.`n" -ForegroundColor Cyan

# NOTE: never use `$input` as a variable name - it is a reserved automatic variable
# in PowerShell and assigning to it silently misbehaves (bug in the original script).
function Read-List {
    param([string]$Prompt)
    $list = @()
    do {
        $entry = Read-Host $Prompt
        if ($entry -ne "") { $list += $entry.Trim() }
    } while ($entry -ne "")
    return $list
}

Write-Host "=== AUTHORIZED ADMINISTRATORS (from README) ===" -ForegroundColor Yellow
$adminList = Read-List "Admin username (blank line = done)"

Write-Host "`n=== AUTHORIZED STANDARD USERS (from README) ===" -ForegroundColor Yellow
$standardList = Read-List "Standard username (blank line = done)"

# Every round's README is different: services/software that are "hacking tools" to
# remove on one image are business-critical on another (e.g. one Server 2022 round
# required Wireshark, IIS, RDP, and MailEnable to stay). Stopping a README-critical
# service triggers a scoring PENALTY, so these exemption lists are load-bearing.
Write-Host "`n=== README EXEMPTIONS (critical - read the README carefully) ===" -ForegroundColor Yellow
Write-Host "Accounts the README says NOT to touch (e.g. service accounts like IME_ADMIN)." -ForegroundColor Yellow
Write-Host "These will not be removed, disabled, demoted, or have passwords changed:" -ForegroundColor Yellow
$doNotTouchAccounts = Read-List "Untouchable account (blank line = done)"

Write-Host "`nWindows SERVICE names the README requires to keep running (e.g. W3SVC," -ForegroundColor Yellow
Write-Host "'MailEnable SMTP Connector', ftpsvc). These will never be stopped/disabled:" -ForegroundColor Yellow
$criticalServices = Read-List "Critical service name (blank line = done)"

Write-Host "`nSoftware the README says must REMAIN INSTALLED (e.g. Wireshark, Chrome," -ForegroundColor Yellow
Write-Host "Notepad++). These are excluded from the prohibited-program flagging:" -ForegroundColor Yellow
$requiredSoftware = Read-List "Required software name (blank line = done)"

$keepRDP        = (Read-Host "`nDoes the README require Remote Desktop (RDP)? (y/N)").ToLower() -eq 'y'
$keepWeb        = (Read-Host "Does the README require a web server (IIS/W3SVC)? (y/N)").ToLower() -eq 'y'
$keepFTP        = (Read-Host "Does the README require an FTP server? (y/N)").ToLower() -eq 'y'
$keepMail       = (Read-Host "Does the README require a mail server (SMTP/MailEnable/Exchange)? (y/N)").ToLower() -eq 'y'
$renameAdmin    = (Read-Host "Rename built-in Administrator account? (y/N)").ToLower() -eq 'y'
$newAdminName   = "SecureAdmin"
if ($renameAdmin) {
    $entered = Read-Host "New name for Administrator [default: SecureAdmin]"
    if ($entered -ne "") { $newAdminName = $entered.Trim() }
}
$deleteMedia    = (Read-Host "Delete media files (mp3/mp4/etc) found in C:\Users? Files are LISTED first in the log; y = delete. (y/N)").ToLower() -eq 'y'
$deleteImages   = (Read-Host "Delete image files (jpg/png/etc) found in C:\Users? (y/N)").ToLower() -eq 'y'
$doURA          = (Read-Host "Interactively configure User Rights Assignment? (y/N)").ToLower() -eq 'y'
$doLolbin       = (Read-Host "Add outbound firewall blocks for LOLBins (certutil, mshta, wscript...)? Rarely scored; adds ~1 min. (y/N)").ToLower() -eq 'y'
$newPassword    = Read-Host "Password to set for all local users (blank = default 'CyberPatr!0t2025')"
if ($newPassword -eq "") { $newPassword = "CyberPatr!0t2025" }

log "`nConfig: RDP=$keepRDP Web=$keepWeb FTP=$keepFTP Mail=$keepMail RenameAdmin=$renameAdmin DeleteMedia=$deleteMedia DeleteImages=$deleteImages"
log "Admins: $($adminList -join ', ')"
log "Standard users: $($standardList -join ', ')"
log "Untouchable accounts (README): $($doNotTouchAccounts -join ', ')"
log "Critical services (README): $($criticalServices -join ', ')"
log "Required software (README): $($requiredSoftware -join ', ')"
log "Current user (protected from password change/removal): $currentUser"

# Snapshot current policy state before changing anything - lets you diff later and
# answer "what did the image look like originally" style forensics questions.
Try-Step "gpresult baseline" {
    gpresult /h (Join-Path (Get-Location).Path "gpresult_baseline.html") /f | Out-Null
    log "Saved Group Policy baseline to gpresult_baseline.html"
}

# ====================================================================================
# PHASE 1: USER ACCOUNT MANAGEMENT
# Answer keys score this in literally every round: "Removed unauthorized user X",
# "User Y is not an administrator", "User Z has a password".
# ====================================================================================
log "`n===== USER ACCOUNT MANAGEMENT =====" Cyan

$protectedAccounts = @("Administrator","Guest","DefaultAccount","WDAGUtilityAccount",
                       "krbtgt","ASPNET","IUSR","IWAM", $newAdminName, $currentUser) + $doNotTouchAccounts
$authorizedUsers = $adminList + $standardList + $protectedAccounts

function Test-ServiceAccount {
    param($User)
    return ($User.Name -like "NT *" -or $User.Name -like "IIS *" -or $User.Name -like "SQL *" -or
            $User.Name -like "svc*" -or $User.Name -like "service*" -or $User.Name -like "*$" -or
            $User.SID -like "S-1-5-80-*")
}

# Cache group membership ONCE instead of calling Get-LocalGroupMember 4x per user.
$adminMembers = @(Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue | ForEach-Object { $_.Name.Split('\')[-1] })
$userMembers  = @(Get-LocalGroupMember -Group "Users" -ErrorAction SilentlyContinue | ForEach-Object { $_.Name.Split('\')[-1] })

foreach ($name in $adminList) {
    if (-not (Get-LocalUser -Name $name -ErrorAction SilentlyContinue)) {
        # Answer keys also score "Created user account X" - create missing authorized users.
        Try-Step "create user $name" {
            New-LocalUser -Name $name -Password (ConvertTo-SecureString $newPassword -AsPlainText -Force) -ErrorAction Stop | Out-Null
            log "Created missing authorized user: $name" Green
        }
    }
    Try-Step "promote $name" {
        if ($adminMembers -notcontains $name) {
            Add-LocalGroupMember -Group "Administrators" -Member $name -ErrorAction Stop
            log "Added $name to Administrators."
        } else { log "$name is already an Administrator." }
    }
}

foreach ($name in $standardList) {
    if (-not (Get-LocalUser -Name $name -ErrorAction SilentlyContinue)) {
        Try-Step "create user $name" {
            New-LocalUser -Name $name -Password (ConvertTo-SecureString $newPassword -AsPlainText -Force) -ErrorAction Stop | Out-Null
            log "Created missing authorized user: $name" Green
        }
    }
    Try-Step "demote $name" {
        if ($adminMembers -contains $name) {
            Remove-LocalGroupMember -Group "Administrators" -Member $name -ErrorAction Stop
            log "Removed $name from Administrators." Green
        }
        if ($userMembers -notcontains $name) {
            Add-LocalGroupMember -Group "Users" -Member $name -ErrorAction SilentlyContinue
            log "Added $name to Users."
        }
    }
}

# Unauthorized users: DISABLE immediately (safe, reversible, still scores on most images),
# list them, and require an explicit 'y' to permanently remove.
# The original defaulted to DELETION when you pressed Enter - dangerous default.
$unauthorized = @()
foreach ($u in (Get-LocalUser | Where-Object { $_.Enabled })) {
    if ($authorizedUsers -contains $u.Name) { continue }
    if (Test-ServiceAccount $u) { log "Protecting service account: $($u.Name)"; continue }
    $unauthorized += $u.Name
}
if ($unauthorized.Count -gt 0) {
    Write-Host "`nUnauthorized users found: $($unauthorized -join ', ')" -ForegroundColor Red
    foreach ($name in $unauthorized) {
        $confirm = Read-Host "Remove user '$name'? (y = delete / N = disable only)"
        if ($confirm.ToLower() -eq 'y') {
            Try-Step "remove $name" { Remove-LocalUser -Name $name -ErrorAction Stop; log "REMOVED unauthorized user: $name" Green }
        } else {
            Try-Step "disable $name" { Disable-LocalUser -Name $name -ErrorAction Stop; log "Disabled (kept) unauthorized user: $name" Yellow }
        }
    }
} else { log "No unauthorized enabled users found." }

##### HIDDEN USER DETECTION (scored: "Hidden user removed - 8 pts") #####
log "`nChecking SpecialAccounts\UserList for users hidden from the logon screen..."
$specialAccountsPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList"
if (Test-Path $specialAccountsPath) {
    foreach ($name in (Get-Item $specialAccountsPath).Property) {
        $value = (Get-ItemProperty -Path $specialAccountsPath -Name $name -ErrorAction SilentlyContinue).$name
        if ($value -eq 0) {
            Write-Host "HIDDEN USER FOUND: $name" -ForegroundColor Red
            log "Hidden user detected via SpecialAccounts\UserList: $name"
            if (Get-LocalUser -Name $name -ErrorAction SilentlyContinue) {
                $c = Read-Host "'$name' is hidden. (U)nhide / (R)emove user / (K)eep [U/r/k]"
                switch ($c.ToUpper()) {
                    "R" { Remove-LocalUser -Name $name -ErrorAction SilentlyContinue
                          Remove-ItemProperty -Path $specialAccountsPath -Name $name -ErrorAction SilentlyContinue
                          log "REMOVED hidden user: $name" Green }
                    "K" { log "Kept hidden user: $name" }
                    Default { Remove-ItemProperty -Path $specialAccountsPath -Name $name -ErrorAction SilentlyContinue
                              log "Un-hid user: $name" Green }
                }
            } else {
                Remove-ItemProperty -Path $specialAccountsPath -Name $name -ErrorAction SilentlyContinue
                log "Removed orphaned hidden-user registry entry: $name"
            }
        }
    }
} else { log "No SpecialAccounts\UserList key - no users hidden this way." }

##### PASSWORDS #####
# Scored: "Changed insecure password for user X", "User Y has a password".
# CRITICAL FIX vs original: never change the password of the account you are logged
# in as - on CyberPatriot images that can break auto-login / lock you out.
# Uses Set-LocalUser (not `net user`) so names with spaces or >20 chars work.
log "`nSetting passwords for local users (skipping $currentUser, Administrator, Guest, DefaultAccount, service accounts)..."
$securePw = ConvertTo-SecureString $newPassword -AsPlainText -Force
foreach ($u in (Get-LocalUser | Where-Object { $_.Enabled })) {
    if ($u.Name -in @($currentUser,"Administrator","Guest","DefaultAccount",$newAdminName)) { continue }
    # README-exempted accounts often run services (mail/web); resetting their
    # passwords can take a critical service down -> scoring penalty.
    if ($doNotTouchAccounts -contains $u.Name) { log "Skipping README-exempted account: $($u.Name)"; continue }
    if (Test-ServiceAccount $u) { continue }
    Try-Step "password for $($u.Name)" {
        Set-LocalUser -Name $u.Name -Password $securePw -ErrorAction Stop
        log "Password set for: $($u.Name)"
    }
}

# Ensure passwords expire for regular users (scored: "User X's password expires").
log "Enabling password expiration for regular users..."
foreach ($u in (Get-LocalUser | Where-Object { $_.Enabled })) {
    if ($u.Name -eq $currentUser -or $u.Name -in $protectedAccounts) { continue }
    if (Test-ServiceAccount $u) { continue }
    Try-Step "pw expiry for $($u.Name)" { Set-LocalUser -Name $u.Name -PasswordNeverExpires $false -ErrorAction Stop }
}

##### GUEST / ADMINISTRATOR BUILT-IN ACCOUNTS #####
# Scored: "Guest account disabled", "Administrator account is not enabled".
# The rename is done properly here via Rename-LocalUser: the original used the
# deprecated/removed `wmic` and then ran `net localgroup /delete Administrator`
# AFTER the rename (the old name no longer exists -> every one of those calls failed;
# they were also unnecessary because renames preserve the SID and group membership).
Try-Step "disable Guest" { Disable-LocalUser -Name "Guest" -ErrorAction Stop; log "Guest account disabled." Green }
if ($renameAdmin) {
    Try-Step "rename Administrator" {
        Rename-LocalUser -Name "Administrator" -NewName $newAdminName -ErrorAction Stop
        Disable-LocalUser -Name $newAdminName -ErrorAction SilentlyContinue
        log "Renamed Administrator -> $newAdminName and disabled it." Green
    }
} else {
    Try-Step "disable Administrator" { Disable-LocalUser -Name "Administrator" -ErrorAction Stop; log "Built-in Administrator disabled." Green }
}

# ====================================================================================
# PHASE 2: SECURITY POLICY - SINGLE SECEDIT PASS
# The original ran secedit export/configure THREE separate times (complexity,
# reversible encryption, user rights), each costing several seconds, plus redundant
# `net accounts` calls. This does ONE export, edits everything, ONE apply.
# Covers scored items: min/max password age, min length, history, complexity,
# reversible encryption, lockout threshold/duration/window.
# ====================================================================================
log "`n===== SECURITY POLICY (single secedit pass) =====" Cyan

$cfgPath = "$env:TEMP\secpol_all.cfg"
$dbPath  = "$env:TEMP\secedit_all.sdb"
secedit /export /cfg $cfgPath /areas SECURITYPOLICY USER_RIGHTS | Out-Null
# secedit exports UTF-16; keep that encoding when writing back (original wrote ANSI).
$cfgLines = Get-Content $cfgPath

function Set-CfgValue {
    param([string[]]$Lines, [string]$Key, [string]$Value, [string]$Section = "[System Access]")
    $found = $false
    $out = foreach ($line in $Lines) {
        if ($line -match "^\s*$([regex]::Escape($Key))\s*=") { $found = $true; "$Key = $Value" } else { $line }
    }
    if (-not $found) {
        $idx = [array]::IndexOf($out, $Section)
        if ($idx -ge 0) { $out = $out[0..$idx] + "$Key = $Value" + $out[($idx+1)..($out.Length-1)] }
        else { $out += @($Section, "$Key = $Value") }
    }
    return $out
}

$policySettings = @{
    "MinimumPasswordAge"    = "1"     # scored: "A secure minimum password age exists"
    "MaximumPasswordAge"    = "60"    # scored: "A secure maximum password age exists"
    "MinimumPasswordLength" = "12"    # scored: "A secure minimum password length is required"
    "PasswordComplexity"    = "1"     # scored: "Passwords must meet complexity requirements"
    "PasswordHistorySize"   = "24"    # scored: "Previous passwords are remembered"
    "ClearTextPassword"     = "0"     # scored: "Passwords are not stored using reversible encryption"
    "LockoutBadCount"       = "5"     # scored: "A secure lockout threshold exists"
    "ResetLockoutCount"     = "30"
    "LockoutDuration"       = "30"    # scored: "A secure account lockout duration exists"
    "EnableGuestAccount"    = "0"
    "EnableAdminAccount"    = "0"
}
foreach ($k in $policySettings.Keys) { $cfgLines = Set-CfgValue -Lines $cfgLines -Key $k -Value $policySettings[$k] }

##### USER RIGHTS ASSIGNMENT (same file, same apply) #####
# Scored repeatedly: "Users may not change the system time", "Everyone's TCB right
# revoked", "Replace a process level token removed from Everyone", "Everyone may not
# access this computer from the network", "User X may not create global objects".
if ($doURA) {
    function Convert-NameToSID {
        param([string]$AccountName)
        $AccountName = $AccountName.Trim()
        if ($AccountName -eq "") { return $null }
        try {
            return "*" + (New-Object System.Security.Principal.NTAccount($AccountName)).Translate([System.Security.Principal.SecurityIdentifier]).Value
        } catch {
            Write-Host "  Cannot resolve '$AccountName' - skipping." -ForegroundColor Yellow
            return $null
        }
    }
    function Convert-SIDToName {
        param([string]$SidToken)
        try { return (New-Object System.Security.Principal.SecurityIdentifier($SidToken.TrimStart("*"))).Translate([System.Security.Principal.NTAccount]).Value }
        catch { return $SidToken }
    }
    $uraTargets = @(
        @{ C = "SeNetworkLogonRight";              N = "Access this computer from the network" },
        @{ C = "SeDenyNetworkLogonRight";          N = "Deny access to this computer from the network" },
        @{ C = "SeSystemtimePrivilege";            N = "Change the system time" },
        @{ C = "SeTcbPrivilege";                   N = "Act as part of the operating system" },
        @{ C = "SeServiceLogonRight";              N = "Log on as a service" },
        @{ C = "SeInteractiveLogonRight";          N = "Allow log on locally" },
        @{ C = "SeRemoteInteractiveLogonRight";    N = "Allow log on through Remote Desktop Services" },
        @{ C = "SeAssignPrimaryTokenPrivilege";    N = "Replace a process level token" },
        @{ C = "SeCreateGlobalPrivilege";          N = "Create global objects" },
        @{ C = "SeCreateTokenPrivilege";           N = "Create a token object" },
        @{ C = "SeBackupPrivilege";                N = "Back up files and directories" },
        @{ C = "SeRestorePrivilege";               N = "Restore files and directories" },
        @{ C = "SeDebugPrivilege";                 N = "Debug programs" },
        @{ C = "SeTakeOwnershipPrivilege";         N = "Take ownership of files or other objects" },
        @{ C = "SeShutdownPrivilege";              N = "Shut down the system" },
        @{ C = "SeRemoteShutdownPrivilege";        N = "Force shutdown from a remote system" }
    )
    Write-Host "`nFor each right: Enter = no change, NONE = clear, or comma-separated accounts to replace members." -ForegroundColor Cyan
    foreach ($t in $uraTargets) {
        $line = $cfgLines | Where-Object { $_ -match "^\s*$($t.C)\s*=" } | Select-Object -First 1
        $current = if ($line) { (($line -split "=",2)[1].Trim() -split ",") | Where-Object { $_ } | ForEach-Object { Convert-SIDToName $_ } } else { @() }
        Write-Host "`n$($t.N) [$($t.C)]" -ForegroundColor Green
        Write-Host "  Current: $(if ($current) { $current -join ', ' } else { '(No one)' })"
        $newVal = Read-Host "  New members"
        if ($newVal -eq "") { continue }
        $tokens = if ($newVal.ToUpper() -eq "NONE") { @() } else {
            @(($newVal -split ",") | ForEach-Object { Convert-NameToSID $_ } | Where-Object { $_ })
        }
        $cfgLines = Set-CfgValue -Lines $cfgLines -Key $t.C -Value ($tokens -join ",") -Section "[Privilege Rights]"
        log "User right '$($t.N)' set to: $(if ($newVal.ToUpper() -eq 'NONE') { 'No one' } else { $newVal })"
    }
}

$cfgLines | Set-Content $cfgPath -Encoding Unicode
secedit /configure /db $dbPath /cfg $cfgPath /areas SECURITYPOLICY USER_RIGHTS /overwrite /quiet | Out-Null
Remove-Item $cfgPath, $dbPath -Force -ErrorAction SilentlyContinue
log "Security policy + user rights applied in one secedit pass." Green

##### AUDIT POLICY - ONE COMMAND #####
# Scored: "Audit Credential Validation [Success/Failure]", "Audit File Share",
# "Audit Object Access", "Audit Privilege Use"... Enabling Success+Failure on
# everything satisfies all variants seen in the answer keys, and this single
# wildcard call replaces the original's 18 auditpol calls + interactive prompt.
log "`nEnabling Success+Failure auditing on all categories..."
auditpol /set /category:* /success:enable /failure:enable | Out-Null
log "Audit policy set." Green

# ====================================================================================
# PHASE 3: REGISTRY HARDENING - DATA-DRIVEN, ONE LOOP
# Consolidates the original's mix of Set-ItemProperty blocks and 50+ `reg add`
# calls (which each spawn a process) into one native loop. Duplicated settings
# (Windows Update, Defender, UAC were each configured 2-3 times) appear once.
# Every entry maps to an item seen in past answer keys or a standard CIS control.
# ====================================================================================
log "`n===== REGISTRY HARDENING =====" Cyan

$SYS  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$LSA  = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
$regSettings = @(
    # --- Logon / session ---
    @{P=$SYS; N="DisableCAD";                V=0},   # "CTRL+ALT+DEL is required for login"
    @{P=$SYS; N="DontDisplayLastUserName";   V=1},   # "Don't display last logged in enabled"
    @{P=$SYS; N="ShutdownWithoutLogon";      V=0},   # "System is not allowed to be shutdown without logon"
    @{P=$SYS; N="InactivityTimeoutSecs";     V=900}, # machine inactivity limit
    @{P="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"; N="AutoAdminLogon"; V=0},
    # --- UAC (scored: elevation prompt behavior, secure desktop, signed executables) ---
    @{P=$SYS; N="EnableLUA";                     V=1},
    @{P=$SYS; N="ConsentPromptBehaviorAdmin";    V=4}, # prompt for consent
    @{P=$SYS; N="ConsentPromptBehaviorUser";     V=0}, # auto-deny standard users
    @{P=$SYS; N="PromptOnSecureDesktop";         V=1}, # "UAC switches to secure desktop"
    @{P=$SYS; N="ValidateAdminCodeSignatures";   V=1}, # "Only elevate executables that are signed"
    @{P=$SYS; N="FilterAdministratorToken";      V=1},
    @{P=$SYS; N="EnableInstallerDetection";      V=1},
    @{P=$SYS; N="EnableVirtualization";          V=1}, # "Virtualize file and registry write failures"
    # --- LSA / anonymous access (scored: SAM enumeration, everyone-anonymous, blank pw) ---
    @{P=$LSA; N="LimitBlankPasswordUse";     V=1},   # "Limit local use of blank passwords to console only"
    @{P=$LSA; N="RestrictAnonymous";         V=1},   # "Do not allow anonymous enumeration of SAM accounts and shares"
    @{P=$LSA; N="RestrictAnonymousSAM";      V=1},   # "Do not allow anonymous enumeration of SAM accounts"
    @{P=$LSA; N="EveryoneIncludesAnonymous"; V=0},   # "Let Everyone permissions apply to anonymous disabled"
    @{P=$LSA; N="DisableDomainCreds";        V=1},   # "Storage of credentials is no longer allowed"
    @{P=$LSA; N="RunAsPPL";                  V=1},   # "Additional LSA protection enabled"
    @{P=$LSA; N="NoLMHash";                  V=1},   # do not store LM hashes
    @{P=$LSA; N="LmCompatibilityLevel";      V=5},   # NTLMv2 only, refuse LM & NTLM
    @{P="$LSA\FipsAlgorithmPolicy"; N="Enabled"; V=1}, # "FIPS compliant algorithms enabled"
    @{P="HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest"; N="UseLogonCredential"; V=0}, # no plaintext creds in memory
    # --- SMB client/server (scored: signing always, no plaintext, insecure guest) ---
    @{P="HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"; N="RequireSecuritySignature"; V=1},
    @{P="HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"; N="EnableSecuritySignature";  V=1},
    @{P="HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"; N="EnablePlainTextPassword";  V=0},
    @{P="HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters";      N="RequireSecuritySignature"; V=1},
    @{P="HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters";      N="EnableSecuritySignature";  V=1},
    @{P="HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters";      N="AutoShareWks";             V=0},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation"; N="AllowInsecureGuestAuth"; V=0}, # "enable insecure guest logons disabled"
    # --- WinRM (scored: "Windows does not accept remote shell connections") ---
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service"; N="AllowUnencryptedTraffic"; V=0},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client";  N="AllowUnencryptedTraffic"; V=0},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service"; N="AllowBasic"; V=0},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service\WinRS"; N="AllowRemoteShellAccess"; V=0},
    # --- RDP hardening (applies whether or not RDP stays on) ---
    @{P="HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"; N="UserAuthentication"; V=1}, # "RDP network level authentication enabled"
    @{P="HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"; N="UserAuthentication"; V=1},
    @{P="HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"; N="SecurityLayer"; V=2}, # "RDP Security Layer set to SSL"
    @{P="HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"; N="fEncryptRPCTraffic"; V=1}, # "RDP Requires secure RPC"
    @{P="HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"; N="MinEncryptionLevel"; V=3},
    # --- Remote Assistance (scored: "Remote Assistance connections have been disabled") ---
    @{P="HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance"; N="fAllowToGetHelp";   V=0},
    @{P="HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance"; N="fAllowUnsolicited"; V=0},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"; N="fAllowToGetHelp";   V=0},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"; N="fAllowUnsolicited"; V=0},
    # --- AutoPlay/AutoRun (scored: "AutoPlay has been disabled [all users]") ---
    @{P="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"; N="NoDriveTypeAutoRun"; V=255},
    @{P="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"; N="NoAutorun";          V=1},
    # --- Windows Update (scored: "Windows automatically checks for updates") ---
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; N="NoAutoUpdate";            V=0},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; N="AUOptions";               V=4},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; N="AutoInstallMinorUpdates"; V=1},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; N="ScheduledInstallDay";     V=0},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; N="ScheduledInstallTime";    V=3},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate";    N="DisableWindowsUpdateAccess"; V=0},
    # --- Windows Defender (scored: real-time, heuristics, passive mode off) ---
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"; N="DisableAntiSpyware"; V=0},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"; N="ServiceKeepAlive";   V=1},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"; N="DisableRealtimeMonitoring"; V=0},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"; N="DisableIOAVProtection";     V=0},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Scan"; N="DisableHeuristics"; V=0},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Scan"; N="CheckForSignaturesBeforeRunningScan"; V=1},
    @{P="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments"; N="ScanWithAntiVirus"; V=3},
    # --- SmartScreen (scored: "Windows SmartScreen configured to warn or block") ---
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; N="EnableSmartScreen"; V=1},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; N="ShellSmartScreenLevel"; V="Block"; T="String"},
    # --- Printers (scored: "Users are prevented from installing printer drivers",
    #     "Downloading of print drivers over HTTP is disabled") ---
    @{P="HKLM:\SYSTEM\CurrentControlSet\Control\Print\Providers\LanMan Print Services\Servers"; N="AddPrinterDrivers"; V=1},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers"; N="DisableWebPnPDownload"; V=1},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers"; N="DisableHTTPPrinting";   V=1},
    # --- Misc scored items ---
    @{P="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"; N="PreXPSP2ShellProtocolBehavior"; V=0}, # "Shell protocol protected mode enabled"
    @{P="HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"; N="CrashDumpEnabled"; V=0}, # "System failures do not cause automatic memory dumps"
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\IIS"; N="PreventIISInstall"; V=1},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Messenger\Client"; N="PreventAutoRun"; V=1},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\SearchCompanion"; N="DisableContentFileUpdates"; V=1},
    # --- PowerShell logging (defensive visibility) ---
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"; N="EnableScriptBlockLogging"; V=1},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging"; N="EnableModuleLogging"; V=1},
    @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription"; N="EnableTranscripting"; V=1},
    # --- Explorer: show hidden files (helps YOU find planted files; per-user) ---
    @{P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="Hidden"; V=1},
    @{P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="HideFileExt"; V=0}
)

# Office macro hardening (scored: "Block Win32 imports from macro code in Office").
# HKCU only affects the current user, but that is the graded account on images.
foreach ($app in @("word","excel","powerpoint","access","publisher","visio","ms project","outlook")) {
    $regSettings += @{P="HKCU:\Software\Policies\Microsoft\office\16.0\$app\security"; N="vbawarnings"; V=4}
    $regSettings += @{P="HKCU:\Software\Policies\Microsoft\office\16.0\$app\security"; N="blockcontentexecutionfrominternet"; V=1}
}
$regSettings += @{P="HKCU:\Software\Policies\Microsoft\office\common\security"; N="automationsecurity"; V=3}
$regSettings += @{P="HKCU:\Software\Policies\Microsoft\office\16.0\common\security"; N="macroruntimescanscope"; V=2}

$regApplied = 0
foreach ($s in $regSettings) {
    Try-Step "reg $($s.P)\$($s.N)" {
        if (-not (Test-Path $s.P)) { New-Item -Path $s.P -Force -ErrorAction Stop | Out-Null }
        $type = if ($s.T) { $s.T } else { "DWord" }
        Set-ItemProperty -Path $s.P -Name $s.N -Value $s.V -Type $type -Force -ErrorAction Stop
        $script:regApplied++
    }
}
log "Applied $regApplied registry settings (see log for any failures)." Green

# ====================================================================================
# PHASE 4: DEFENDER, FIREWALL, SERVICES, FEATURES
# ====================================================================================
log "`n===== DEFENDER / FIREWALL / SERVICES =====" Cyan

##### WINDOWS DEFENDER #####
# Scored: real-time on, heuristics, script scanning, severe/high threat action not
# 'ignore', cloud protection, network protection, PUA. One Set-MpPreference batch.
Try-Step "Defender preferences" {
    Set-MpPreference -DisableRealtimeMonitoring $false -DisableScriptScanning $false `
        -DisableIOAVProtection $false -DisableBehaviorMonitoring $false `
        -HighThreatDefaultAction Quarantine -SevereThreatDefaultAction Quarantine `
        -MAPSReporting Advanced -SubmitSamplesConsent SendSafeSamples `
        -PUAProtection Enabled -EnableNetworkProtection Enabled -ErrorAction Stop
    log "Defender: realtime, script scanning, behavior monitoring, cloud+network protection, PUA all ON; severe/high threats quarantined." Green
}
Try-Step "Defender service" { Start-Service WinDefend -ErrorAction Stop }
# Signature update runs in the BACKGROUND so the script doesn't stall on a download.
Try-Step "Defender signatures" { Start-Job { Update-MpSignature } | Out-Null; log "Defender signature update started in background." }

##### FIREWALL #####
# Scored every round: "Firewall protection has been enabled". Also default-inbound
# Block ("Incoming connections not matching a rule are blocked").
# REMOVED vs original: the `New-NetFirewallRule -DisplayName "Allow HTTP"` inbound
# port 80 rule - opening inbound ports unprompted can LOSE points; only do that if
# the README explicitly hosts a web service.
Try-Step "firewall profiles" {
    Set-NetFirewallProfile -All -Enabled True -DefaultInboundAction Block -ErrorAction Stop
    log "Firewall enabled on all profiles, default inbound = Block." Green
}
Try-Step "firewall service" { Set-Service mpssvc -StartupType Automatic; Start-Service mpssvc -ErrorAction SilentlyContinue }
if ($keepWeb) {
    Try-Step "allow HTTP" { New-NetFirewallRule -DisplayName "Allow HTTP (README)" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow -ErrorAction Stop | Out-Null; log "Inbound TCP 80 allowed per README." }
}
Try-Step "Remote Assistance FW rules" { Disable-NetFirewallRule -DisplayGroup "Remote Assistance" -ErrorAction Stop; log "Remote Assistance firewall rules disabled." }

# Optional LOLBin outbound blocks. Data-driven loop replaces ~55 hardcoded netsh
# lines; skips rules that already exist so re-runs don't create duplicates.
if ($doLolbin) {
    log "Adding outbound block rules for living-off-the-land binaries..."
    $lolbins = @("certutil.exe","cmstp.exe","cscript.exe","wscript.exe","mshta.exe","regsvr32.exe",
                 "regasm.exe","rundll32.exe","msiexec.exe","hh.exe","makecab.exe","expand.exe",
                 "extrac32.exe","esentutl.exe","odbcconf.exe","pcalua.exe","replace.exe",
                 "scriptrunner.exe","SyncAppvPublishingServer.exe","nltest.exe")
    $existing = @(Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "Block LOLBin*" } | ForEach-Object DisplayName)
    foreach ($bin in $lolbins) {
        foreach ($dir in @("$env:SystemRoot\System32","$env:SystemRoot\SysWOW64")) {
            $path = Join-Path $dir $bin
            $ruleName = "Block LOLBin $bin ($dir)"
            if ((Test-Path $path) -and ($existing -notcontains $ruleName)) {
                Try-Step "block $bin" {
                    New-NetFirewallRule -DisplayName $ruleName -Program $path -Direction Outbound -Action Block -Profile Any -ErrorAction Stop | Out-Null
                }
            }
        }
    }
    Try-Step "block wmic" {
        New-NetFirewallRule -DisplayName "Block LOLBin wmic.exe" -Program "$env:SystemRoot\System32\wbem\wmic.exe" -Direction Outbound -Action Block -Profile Any -ErrorAction SilentlyContinue | Out-Null
    }
    log "LOLBin outbound blocks added." Green
}

##### SERVICES #####
# CRITICAL FIX vs original: it disabled RpcSs (the Remote Procedure Call service).
# Nearly everything in Windows depends on RpcSs - disabling it renders the image
# unusable/unbootable. It is GONE from this list.
# Also fixed: the original asked "keep RDP?" then unconditionally disabled
# TermService/SessionEnv/UmRdpService anyway 400 lines later.
log "`nConfiguring services..."
$servicesToDisable = @("TlntSvr","Telnet","SNMP","SNMPTRAP","SSDPSRV","upnphost",
                       "RemoteRegistry","RemoteAccess","SharedAccess","Messenger","TapiSrv",
                       "HomeGroupProvider","HomeGroupListener","RDSessMgr","ConfRoom",
                       "Spooler","seclogon","Fax","XblAuthManager","XblGameSave","XboxNetApiSvc")
if (-not $keepWeb)  { $servicesToDisable += @("W3SVC","IISADMIN") }
if (-not $keepMail) { $servicesToDisable += @("SMTPSVC") }
if (-not $keepFTP)  { $servicesToDisable += @("ftpsvc","msftpsvc") }
if (-not $keepRDP)  { $servicesToDisable += @("TermService","SessionEnv","UmRdpService") }

# One Get-Service call, then only touch services that actually exist - the original
# ran `sc stop`/`sc config` blindly for ~25 services (2 processes each, most erroring).
$existingServices = Get-Service -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
foreach ($svc in $servicesToDisable) {
    # Never touch README-critical services (stopping one = scoring penalty) or the
    # CyberPatriot CCS scoring client (tampering kills scoring feedback entirely).
    if ($criticalServices | Where-Object { $svc -like $_ -or $_ -like $svc }) { log "Skipping README-critical service: $svc"; continue }
    if ($svc -match "CCS|CyberPatriot") { continue }
    if ($existingServices -contains $svc) {
        Try-Step "disable $svc" {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svc -StartupType Disabled -ErrorAction Stop
            log "Disabled service: $svc"
        }
    }
}

# Scored as ENABLED in keys: Event Log, Windows Update, DHCP client, Server, Firewall,
# Defender. wscsvc = Security Center ("Action Center should be enabled and monitoring").
# README-critical services are also ensured running - uptime of critical services is scored.
$servicesToEnable = @("EventLog","wuauserv","Dhcp","LanmanServer","mpssvc","WinDefend","wscsvc") + $criticalServices
foreach ($svc in $servicesToEnable) {
    if ($existingServices -contains $svc) {
        Try-Step "enable $svc" {
            Set-Service -Name $svc -StartupType Automatic -ErrorAction Stop
            Start-Service -Name $svc -ErrorAction SilentlyContinue
            log "Enabled + started service: $svc"
        }
    }
}

##### RDP ENABLE/DISABLE (single, consistent decision) #####
if ($keepRDP) {
    Try-Step "enable RDP" {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
        Set-Service TermService -StartupType Automatic; Start-Service TermService -ErrorAction SilentlyContinue
        log "RDP kept enabled (with NLA + SSL security layer from registry phase)." Green
    }
} else {
    Try-Step "disable RDP" {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 1
        log "RDP disabled." Green
    }
}

##### WINDOWS FEATURES #####
# Scored: "SMBv1 uninstalled", "Powershell 2.0 has been uninstalled", telnet removed.
# One Get- call, then disable only what's actually enabled (each dism-backed disable
# costs ~20-30s, so skipping absent features is a big time win vs the original's
# unconditional `dism` calls).
log "`nChecking optional Windows features..."
Try-Step "optional features" {
    $badFeatures = @("SMB1Protocol","SMB1Protocol-Client","SMB1Protocol-Server",
                     "TelnetClient","TelnetServer","TFTP",
                     "MicrosoftWindowsPowerShellV2","MicrosoftWindowsPowerShellV2Root")
    $enabled = Get-WindowsOptionalFeature -Online -ErrorAction Stop |
               Where-Object { $_.State -eq "Enabled" -and $badFeatures -contains $_.FeatureName }
    foreach ($f in $enabled) {
        Try-Step "disable feature $($f.FeatureName)" {
            Disable-WindowsOptionalFeature -Online -FeatureName $f.FeatureName -NoRestart -ErrorAction Stop | Out-Null
            log "Disabled feature: $($f.FeatureName)" Green
        }
    }
    if (-not $enabled) { log "No insecure optional features enabled (SMBv1/Telnet/TFTP/PSv2 all absent)." }
}
Try-Step "SMB server config" {
    Set-SmbServerConfiguration -EncryptData $true -EnableSMB1Protocol $false -Force -ErrorAction Stop
    log "SMB server-wide encryption enabled, SMB1 off." Green
}

##### MISC HARDENING #####
Try-Step "DEP" { bcdedit /set "{current}" nx AlwaysOn | Out-Null; log "DEP set to AlwaysOn." Green }  # "DEP enabled system wide"
Try-Step "IPv6" {
    # 0xFF is Microsoft's documented value to disable all IPv6 components;
    # the original's 0xFFFFFFFF is invalid and causes boot delays.
    Set-NetAdapterBinding -Name "*" -ComponentID ms_tcpip6 -Enabled $false -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents" -Value 0xFF -Type DWord -Force
    log "IPv6 disabled (DisabledComponents=0xFF)." Green
}
Try-Step "Recycle Bin" { Clear-RecycleBin -Force -ErrorAction Stop; log "Recycle Bin cleared." }  # "Recycle bins cleared"
# Kick off an update scan asynchronously - the original ran a synchronous COM search
# that can take 5+ minutes; the registry settings above are what actually score.
Try-Step "update scan" { Start-Process -FilePath "$env:SystemRoot\System32\UsoClient.exe" -ArgumentList "StartScan" -WindowStyle Hidden -ErrorAction Stop; log "Windows Update scan kicked off in background." }

# ====================================================================================
# PHASE 5: BACKDOOR & PERSISTENCE HUNTING
# Answer keys score these heavily: "Sticky keys backdoor removed - 5 pts",
# "Removed netcat backdoor - 5 pts", "PowerShell script persistence removed - 4 pts",
# "WMI persistence removed", "Removed psexec service backdoor".
# ====================================================================================
log "`n===== BACKDOOR / PERSISTENCE AUDIT =====" Cyan

##### STICKY KEYS / ACCESSIBILITY / IFEO #####
$accessibilityBinaries = @("sethc.exe","utilman.exe","osk.exe","Magnify.exe","Narrator.exe","DisplaySwitch.exe","AtBroker.exe")
$cmdHash = $null
Try-Step "hash cmd.exe" { $script:cmdHash = (Get-FileHash "$env:SystemRoot\System32\cmd.exe" -Algorithm SHA256 -ErrorAction Stop).Hash }
foreach ($bin in $accessibilityBinaries) {
    foreach ($sysDir in @("$env:SystemRoot\System32","$env:SystemRoot\SysWOW64")) {
        $binPath = Join-Path $sysDir $bin
        if ($cmdHash -and (Test-Path $binPath)) {
            $binHash = (Get-FileHash $binPath -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash
            if ($binHash -eq $cmdHash) {
                Write-Host "BACKDOOR: $binPath is a copy of cmd.exe!" -ForegroundColor Red
                log "BACKDOOR: $binPath identical to cmd.exe (sticky-keys backdoor)."
                $quarantineDir = "C:\CyberPatriot_Quarantine"
                if (-not (Test-Path $quarantineDir)) { New-Item $quarantineDir -ItemType Directory -Force | Out-Null }
                Move-Item $binPath (Join-Path $quarantineDir "$bin.$(Get-Date -Format yyyyMMddHHmmss).bak") -Force -ErrorAction SilentlyContinue
                log "Quarantined $binPath to $quarantineDir. Restore the real $bin from clean media if needed." Green
            }
        }
        # IFEO Debugger hijack - auto-remove, no legitimate image sets these.
        $ifeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$bin"
        if (Test-Path $ifeoPath) {
            $dbg = (Get-ItemProperty $ifeoPath -Name "Debugger" -ErrorAction SilentlyContinue).Debugger
            if ($dbg) {
                log "BACKDOOR: IFEO Debugger on $bin -> '$dbg'. Removing." Red
                Remove-ItemProperty -Path $ifeoPath -Name "Debugger" -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
log "Accessibility/IFEO backdoor check complete."

##### AUTORUN / PERSISTENCE REPORT (new - report-only, very fast) #####
log "`n--- Run/RunOnce registry autoruns (review each entry): ---" Yellow
$runKeys = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
             "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
             "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
             "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
             "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce")
foreach ($rk in $runKeys) {
    if (Test-Path $rk) {
        foreach ($prop in (Get-Item $rk).Property) {
            $val = (Get-ItemProperty $rk -Name $prop).$prop
            log "  [$rk] $prop = $val" Yellow
        }
    }
}

log "`n--- Startup folder contents: ---" Yellow
foreach ($sf in @("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp",
                  "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup")) {
    Get-ChildItem $sf -ErrorAction SilentlyContinue | Where-Object Name -ne "desktop.ini" |
        ForEach-Object { log "  $($_.FullName)" Yellow }
}

log "`n--- Non-Microsoft scheduled tasks (common persistence spot): ---" Yellow
Try-Step "scheduled tasks" {
    Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskPath -notlike "\Microsoft\*" -and $_.State -ne "Disabled" } |
        ForEach-Object {
            $action = ($_.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join "; "
            log "  $($_.TaskPath)$($_.TaskName) -> $action" Yellow
        }
}

log "`n--- Listening TCP ports (find netcat/backdoor listeners): ---" Yellow
Try-Step "listening ports" {
    $procs = @{}
    Get-Process | ForEach-Object { $procs[$_.Id] = $_.ProcessName }
    Get-NetTCPConnection -State Listen -ErrorAction Stop | Sort-Object LocalPort -Unique |
        ForEach-Object { log ("  Port {0,-6} PID {1,-7} {2}" -f $_.LocalPort, $_.OwningProcess, $procs[[int]$_.OwningProcess]) Yellow }
}

log "`n--- Non-default SMB shares (scored: 'File share X disabled'): ---" Yellow
Try-Step "shares" {
    Get-SmbShare -ErrorAction Stop | Where-Object { $_.Name -notin @("ADMIN$","C$","IPC$","print$") } |
        ForEach-Object { log "  Share '$($_.Name)' -> $($_.Path)  (remove with: Remove-SmbShare -Name '$($_.Name)')" Yellow }
}

log "`n--- hosts file entries (malware sometimes redirects update/AV domains): ---" Yellow
Get-Content "$env:SystemRoot\System32\drivers\etc\hosts" -ErrorAction SilentlyContinue |
    Where-Object { $_ -match '^\s*\d' } | ForEach-Object { log "  $_" Yellow }

##### DEFENDER EXCLUSIONS (sabotage check - exclusions silently override every policy) #####
log "`n--- Windows Defender exclusions (planted exclusions hide malware from scans): ---" Yellow
Try-Step "Defender exclusions" {
    $mp = Get-MpPreference -ErrorAction Stop
    $exclusions = @($mp.ExclusionPath) + @($mp.ExclusionExtension) + @($mp.ExclusionProcess) | Where-Object { $_ }
    if ($exclusions) {
        foreach ($e in $exclusions) { log "  EXCLUSION FOUND: $e" Red }
        Write-Host "Remove planted exclusions with: Remove-MpPreference -ExclusionPath/<type> '<value>'" -ForegroundColor Red
    } else { log "  No Defender exclusions configured." }
}

##### ADMIN TOOL LOCKOUT SABOTAGE (images sometimes disable cmd/regedit/Task Manager) #####
Try-Step "tool lockout keys" {
    $lockouts = @(
        @{P="HKCU:\Software\Policies\Microsoft\Windows\System";                          N="DisableCMD"},
        @{P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System";           N="DisableTaskMgr"},
        @{P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System";           N="DisableRegistryTools"},
        @{P="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System";           N="DisableTaskMgr"},
        @{P="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System";           N="DisableRegistryTools"}
    )
    foreach ($l in $lockouts) {
        if ((Get-ItemProperty -Path $l.P -Name $l.N -ErrorAction SilentlyContinue).($l.N)) {
            Set-ItemProperty -Path $l.P -Name $l.N -Value 0 -Force
            log "  SABOTAGE FIXED: $($l.P)\$($l.N) was set - admin tool re-enabled." Red
        }
    }
}

##### INSTALLED PROGRAM AUDIT (new - scored every round: "Removed Wireshark/CCleaner/TeamViewer/...") #####
log "`n--- Installed programs flagged as commonly-prohibited: ---" Red
$badPatterns = "wireshark|nmap|zenmap|netstumbler|ccleaner|pc cleaner|teamviewer|anydesk|tightvnc|ultravnc|realvnc|bittorrent|utorrent|qbittorrent|deluge|amule|emule|ophcrack|cain|john the ripper|hydra|aircrack|kismet|netcat|ncat|hashcat|l0phtcrack|brutus|keylogger|tftp|metasploit|armitage|burp|angry ip|advanced port scanner|mcafee|tor browser|cursor|tini"
Try-Step "program inventory" {
    $uninstallKeys = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                       "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                       "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
    $apps = Get-ItemProperty $uninstallKeys -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName } | Sort-Object DisplayName -Unique
    log_info "`nFull installed program list:"
    foreach ($a in $apps) { log_info "  $($a.DisplayName)  [$($a.DisplayVersion)]" }
    $flagged = $apps | Where-Object { $_.DisplayName -match $badPatterns }
    foreach ($f in $flagged) {
        # A "hacking tool" on one image is required business software on another
        # (e.g. one Server 2022 README required Wireshark to stay installed and
        # up-to-date). README exemptions always win.
        $isRequired = $requiredSoftware | Where-Object { $f.DisplayName -match [regex]::Escape($_) }
        if ($isRequired) {
            log "  KEEP (README-required): $($f.DisplayName) - keep it UPDATED instead ('X has been updated' is scored)" Green
        } else {
            log "  FLAGGED: $($f.DisplayName)  -> uninstall via Settings/Apps or: $($f.UninstallString)" Red
        }
    }
    if (-not $flagged) { log "  No known-prohibited programs matched. Full inventory is in the log - review it against the README." }
    else { Write-Host "`nUninstall FLAGGED programs manually (or with winget) - the README list has already been applied." -ForegroundColor Red }
}

# ====================================================================================
# PHASE 6: PROHIBITED FILES - SINGLE SCAN OF C:\Users
# The original scanned C:\Users recursively TWICE (once for media, once for images).
# This scans ONCE and classifies. Also flags plaintext-password-style files, which
# answer keys score ("Removed plain text file with passwords in it",
# "Removed unauthorized credit card information file").
# ====================================================================================
log "`n===== PROHIBITED FILE SCAN (single pass of C:\Users) =====" Cyan

$mediaExt = @(".mp3",".mp4",".avi",".mkv",".flac",".wav",".mov",".wmv",".m4a",".mpeg",".mpg")
$imageExt = @(".png",".jpg",".jpeg",".gif",".bmp",".tiff",".webp",".heif",".ico")
$toolExt  = @(".pcap",".pcapng",".kdbx")

$allFiles = Get-ChildItem -Path "C:\Users" -Recurse -File -Force -ErrorAction SilentlyContinue
$mediaFiles = $allFiles | Where-Object { $mediaExt -contains $_.Extension.ToLower() }
$imageFiles = $allFiles | Where-Object { $imageExt -contains $_.Extension.ToLower() -and $_.FullName -notmatch '\\AppData\\' }
$suspFiles  = $allFiles | Where-Object {
    ($toolExt -contains $_.Extension.ToLower()) -or
    ($_.Extension -in @(".txt",".csv",".xlsx",".docx") -and $_.Name -match "password|passwd|credit|ssn|secret") -or
    ($_.Extension -eq ".exe" -and $_.FullName -notmatch '\\AppData\\')
}

log "Media files found: $($mediaFiles.Count) | Images (outside AppData): $($imageFiles.Count) | Suspicious files: $($suspFiles.Count)"
log_info "`nMedia files:";  $mediaFiles | ForEach-Object { log_info "  $($_.FullName)" }
log_info "`nImage files:";  $imageFiles | ForEach-Object { log_info "  $($_.FullName)" }
if ($suspFiles) {
    log "`nSUSPICIOUS files (password/PII/captures/loose exes) - review, do NOT auto-delete (may be forensics evidence):" Red
    $suspFiles | ForEach-Object { log "  $($_.FullName)" Red }
}

if ($deleteMedia -and $mediaFiles) {
    $mediaFiles | Remove-Item -Force -ErrorAction SilentlyContinue
    log "Deleted $($mediaFiles.Count) media files (list in log)." Green
}
if ($deleteImages -and $imageFiles) {
    $imageFiles | Remove-Item -Force -ErrorAction SilentlyContinue
    log "Deleted $($imageFiles.Count) image files (list in log)." Green
}

# ====================================================================================
# WRAP-UP
# ====================================================================================
$elapsed = (Get-Date) - $scriptStart
log "`n===== DONE in $([int]$elapsed.TotalMinutes) min $($elapsed.Seconds) sec =====" Cyan

Write-Host @"

MANUAL CHECKLIST (things a script cannot safely do for you):
  1. ANSWER THE FORENSICS QUESTIONS FIRST - they are the highest-value items.
  2. Read the README again: required users, groups ('Created group X / Added users
     to group X' is scored), required services, allowed software. Penalties come
     from acting against the README and are recovered by reverting the action.
  3. Create/populate any README-specified groups:  net localgroup "GroupName" /add
  4. Update third-party apps (Firefox, Chrome, Notepad++, 7-Zip, LibreOffice...) -
     'X has been updated' is scored in nearly every round. README-required software
     (even tools like Wireshark) must be UPDATED, never removed.
  5. Run Windows Update from Settings ('majority of Windows updates installed').
     Quality/security updates only - READMEs forbid Feature Updates / Insider
     builds / 'Reset this PC'.
  6. Uninstall the FLAGGED programs listed above.
  7. Review the persistence report (Run keys, scheduled tasks, listening ports,
     shares, hosts file, Defender exclusions) printed above / in the log.
     Do NOT delete shares the README/scenario depends on.
  8. Check Task Manager > Startup tab, and services.msc for anything odd.
     NEVER stop or touch the CyberPatriot CCS scoring client.
  9. If the image hosts scenario apps (mail/web), check their own security settings
     (SSL required, no plaintext auth, protected data directories) - READMEs call
     these out and they are scored.
 10. Reboot when convenient (several settings need it). Script no longer force-restarts.

Log file: $LOGFILE
"@ -ForegroundColor Cyan

$choice = Read-Host "Restart now to apply everything? (y/N)"
if ($choice.ToLower() -eq 'y') { Restart-Computer -Force } else { log "Restart deferred." }
