# ====================================================================================
# Authors: Tanav Malhotra, Bryan Lochan 
# License: GNU General Public License v3.0
# Copyright (c) 2024 Tanav Malhotra, Bryan Lochan 
#
# This script is licensed under the GNU General Public License v3.0.
# You may obtain a copy of the license at:
#   https://www.gnu.org/licenses/gpl-3.0.html
#
# The script is provided "as-is", without any warranty of any kind,
# express or implied, including but not limited to the implied warranties
# of merchantability and fitness for a particular purpose. See the GPL-3.0
# for full details.
#
# You can also view the license by running this script
# with the '-License' option.
# ====================================================================================

##### VARIABLES #####
$LOGFILE = "windows_ps1_script.log"

##### REMOVE EXISTING LOG FILE #####
if (Test-Path $LOGFILE) {
    Remove-Item $LOGFILE -Force
}

##### FUNCTIONS #####
function log {
    param (
        [string]$Message,
    )
    Write-Host $Message
    $Message | Out-File -Append -FilePath $LOGFILE
}
function log_info {
    param (
        [string]$Message,
    )
    $Message | Out-File -Append -FilePath $LOGFILE
}

##### CHECK FOR ADMIN #####
log_info "Checking for admininstrative access..."
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    log "error: Please run this script as an administrator."
    exit
}

##### PASSWORD SETTINGS #####
log "Setting password settings and lockout policy..."
$newPassword = "CyberPatr!0t"
$users = Get-WmiObject -Class Win32_UserAccount -Filter "LocalAccount = 'True' AND Disabled = 'False'"
foreach ($user in $users) {
    if ($user.Name -ne "Administrator" -and $user.Name -ne "DefaultAccount" -and $user.Name -ne "Guest") {
        try {
            net user $user.Name $newPassword
            log "Password for user $($user.Name) changed successfully."
        } catch {
            log "Failed to change password for user $($user.Name): $_"
        }
    }
}
$registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
$registryName = "LimitBlankPasswordUse"
try {
    log "Enabling 'Limit local account use of blank passwords to console logon only'..."
    Set-ItemProperty -Path $registryPath -Name $registryName -Value 1
} catch {
    log "Failed to enable the setting: $_"
}
# each user max password age 60
$users = Get-LocalUser | Where-Object { $_.Name -ne 'Administrator' -and $_.Name -ne 'DefaultAccount' }
foreach ($user in $users) {
	Set-LocalUser -Name $user.Name -MaximumPasswordAge (New-TimeSpan -Days 60)
}
net accounts /maxpwage:60
net accounts /minpwage:1
net accounts /minpwlen:12
net accounts /uniquepw:5
net accounts /lockoutthreshold:5 # attempts
net accounts /lockoutduration:30 # minutes
net accounts /lockoutwindow:30 # minutes before failed login attempts threshold counter is reset to 0
# make admin max pw age shorter
$admins = Get-LocalGroupMember -Group "Administrators"
foreach ($admin in $admins) {
	Set-LocalUser -Name $admin.Name -MaximumPasswordAge (New-TimeSpan -Days 30)
}
# Apply password complexity setting using secedit
log "Applying password complexity setting..."
secedit /export /cfg C:\secpol.cfg
(Get-Content C:\secpol.cfg).replace("PasswordComplexity = 0", "PasswordComplexity = 1") | 
    Set-Content C:\secpol.cfg
secedit /configure /db secedit.sdb /cfg C:\secpol.cfg /overwrite
Remove-Item C:\secpol.cfg
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" `
	-Name "PasswordComplexity" -Value 1 -PropertyType DWord -Force
log "Password complexity applied."
# Disable Password Reversible Encryption for passwords (Decryption)
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Password" `
	-Name "DisableReversibleEncryption" -Value 1 -PropertyType DWord -Force
Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'DisablePasswordReversibleEncryption' -Value 1

#### FIREWALL #####
log "Setting up firewall..."
Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True
Set-NetFirewallRule -DisplayGroup "Windows Firewall" -Enabled True
New-NetFirewallRule -DisplayName "Allow HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow
# rules
netsh advfirewall firewall add rule name="Block appvlp.exe netconns" program="C:\Program Files (x86)\Microsoft Office\root\client\AppVLP.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block appvlp.exe netconns" program="C:\Program Files\Microsoft Office\root\client\AppVLP.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block calc.exe netconns" program="%systemroot%\system32\calc.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block calc.exe netconns" program="%systemroot%\SysWOW64\calc.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block certutil.exe netconns" program="%systemroot%\system32\certutil.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block certutil.exe netconns" program="%systemroot%\SysWOW64\certutil.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block cmstp.exe netconns" program="%systemroot%\system32\cmstp.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block cmstp.exe netconns" program="%systemroot%\SysWOW64\cmstp.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block cscript.exe netconns" program="%systemroot%\system32\cscript.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block cscript.exe netconns" program="%systemroot%\SysWOW64\cscript.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block esentutl.exe netconns" program="%systemroot%\system32\esentutl.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block esentutl.exe netconns" program="%systemroot%\SysWOW64\esentutl.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block expand.exe netconns" program="%systemroot%\system32\expand.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block expand.exe netconns" program="%systemroot%\SysWOW64\expand.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block extrac32.exe netconns" program="%systemroot%\system32\extrac32.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block extrac32.exe netconns" program="%systemroot%\SysWOW64\extrac32.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block findstr.exe netconns" program="%systemroot%\system32\findstr.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block findstr.exe netconns" program="%systemroot%\SysWOW64\findstr.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block hh.exe netconns" program="%systemroot%\system32\hh.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block hh.exe netconns" program="%systemroot%\SysWOW64\hh.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block makecab.exe netconns" program="%systemroot%\system32\makecab.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block makecab.exe netconns" program="%systemroot%\SysWOW64\makecab.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block mshta.exe netconns" program="%systemroot%\system32\mshta.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block mshta.exe netconns" program="%systemroot%\SysWOW64\mshta.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block msiexec.exe netconns" program="%systemroot%\system32\msiexec.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block msiexec.exe netconns" program="%systemroot%\SysWOW64\msiexec.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block nltest.exe netconns" program="%systemroot%\system32\nltest.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block nltest.exe netconns" program="%systemroot%\SysWOW64\nltest.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block Notepad.exe netconns" program="%systemroot%\system32\notepad.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block Notepad.exe netconns" program="%systemroot%\SysWOW64\notepad.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block odbcconf.exe netconns" program="%systemroot%\system32\odbcconf.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block odbcconf.exe netconns" program="%systemroot%\SysWOW64\odbcconf.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block pcalua.exe netconns" program="%systemroot%\system32\pcalua.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block pcalua.exe netconns" program="%systemroot%\SysWOW64\pcalua.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block regasm.exe netconns" program="%systemroot%\system32\regasm.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block regasm.exe netconns" program="%systemroot%\SysWOW64\regasm.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block regsvr32.exe netconns" program="%systemroot%\system32\regsvr32.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block regsvr32.exe netconns" program="%systemroot%\SysWOW64\regsvr32.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block replace.exe netconns" program="%systemroot%\system32\replace.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block replace.exe netconns" program="%systemroot%\SysWOW64\replace.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block rpcping.exe netconns" program="%systemroot%\SysWOW64\rpcping.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block rundll32.exe netconns" program="%systemroot%\system32\rundll32.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block rundll32.exe netconns" program="%systemroot%\SysWOW64\rundll32.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block runscripthelper.exe netconns" program="%systemroot%\system32\runscripthelper.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block runscripthelper.exe netconns" program="%systemroot%\SysWOW64\runscripthelper.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block scriptrunner.exe netconns" program="%systemroot%\system32\scriptrunner.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block scriptrunner.exe netconns" program="%systemroot%\SysWOW64\scriptrunner.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block SyncAppvPublishingServer.exe netconns" program="%systemroot%\system32\SyncAppvPublishingServer.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block SyncAppvPublishingServer.exe netconns" program="%systemroot%\SysWOW64\SyncAppvPublishingServer.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block wmic.exe netconns" program="%systemroot%\system32\wbem\wmic.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block wmic.exe netconns" program="%systemroot%\SysWOW64\wbem\wmic.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block wscript.exe netconns" program="%systemroot%\system32\wscript.exe" protocol=tcp dir=out enable=yes action=block profile=any
netsh advfirewall firewall add rule name="Block wscript.exe netconns" program="%systemroot%\SysWOW64\wscript.exe" protocol=tcp dir=out enable=yes action=block profile=any

##### DISABLE IPv6 #####
log "Disabling IPv6..."
Set-NetAdapterBinding -Name "*" -ComponentID ms_tcpip6 -Enabled $false
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' -Name 'DisabledComponents' -Value 0xFFFFFFFF

##### DISBALE GUEST LOGIN #####
log "Disabling guest login..."
Set-LocalUser -Name "Guest" -Enabled $false

##### SOFTWARE MANAGEMENT #####
# removing software
log "Removing prohibited software..."
$appsToRemove = @(
    "*xbox*",
    "*zune*",
    "*3dbuilder*",
    "*bingnews*",
    "*solitaire*",
    "*skypeapp*",
    "*getstarted*",
    "*oneconnect*",
    "*people*",
    "*communicationsapps*",
    "*feedbackhub*",
    "*officehub*",
    "*onenote*",
    "*mixedreality*",
    "*wallet*",
    "*yourphone*",
    "*candycrush*",
    "*twitter*",
    "*netflix*",
    "*wireshark*",
    "*bittorrent*",
    "*netcat*",
    "*teamviewer*",
    "*webcompanion*",
    "*groove*",
    "*Paint3D*"
)
foreach ($app in $appsToRemove) {
    log "Removing $app..."
    Get-AppxPackage -AllUsers | Where-Object { $_.Name -like $app } | Remove-AppxPackage -ErrorAction SilentlyContinue
    Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like $app } | ForEach-Object { $_.Uninstall() } # for traditional apps installed from internet
}
$app = "*tftp*"
$appChoice = Read-Host "Do you want to remove $app? (Y/n): "
switch -WildCard ($appChoice) {
    "N" -or "n" {
        log "Canceled."
    }
    Default {
        log "Removing $app..."
        Get-AppxPackage -AllUsers | Where-Object { $_.Name -like $app } | Remove-AppxPackage -ErrorAction SilentlyContinue
        Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like $app } | ForEach-Object { $_.Uninstall() } # for traditional apps installed from internet
    }
}
$app = "*telnet*"
$appChoice = Read-Host "Do you want to remove $app? (Y/n): "
switch -WildCard ($appChoice) {
    "N" -or "n" {
        log "Canceled."
    }
    Default {
        log "Removing $app..."
        Get-AppxPackage -AllUsers | Where-Object { $_.Name -like $app } | Remove-AppxPackage -ErrorAction SilentlyContinue
        Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like $app } | ForEach-Object { $_.Uninstall() } # for traditional apps installed from internet
    }
}
# installing software
log "Installing software..."
# TODO: see if any software needs to be installed

##### AUTOMATIC UPDATES #####
# start update service and set to automatic
Start-Service -Name wuauserv
Set-Service -Name wuauserv -StartupType Automatic
# modify registry to check for updates automatically
$regPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
Set-ItemProperty -Path $regPath -Name "FlightSetting" -Value 0
Set-ItemProperty -Path $regPath -Name "UserPreference" -Value 1
# force a manual check for updates to initialize the update process
$updateSession = New-Object -ComObject Microsoft.Update.Session
$updateSearcher = $updateSession.CreateUpdateSearcher()
$searchResult = $updateSearcher.Search("IsInstalled=0")

##### WINDOWS DEFENDER #####
log "Enabling and updating Windows Defender..."
# Enable Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $false
# Update Windows Defender
Update-MpSignature

##### CREATE GLOBAL OBJECTS CONFIGURATION #####
# $policyName = "SeCreateGlobalPrivilege"
# $adminSID = (New-Object System.Security.Principal.NTAccount("Administrators")).Translate([System.Security.Principal.SecurityIdentifier]).Value
# secedit /export /cfg "C:\secpol.cfg"
# (gc "C:\secpol.cfg") -replace "$policyName.*", "$policyName = *$adminSID" | Out-File "C:\secpol.cfg"
# secedit /configure /db secedit.sdb /cfg "C:\secpol.cfg" /overwrite
log "Preventing users from creating global objects..."
$secpolPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$createGlobalObjectsKey = "SeCreateGlobalPrivilege"
$currentPrivileges = Get-ItemProperty -Path $secpolPath -Name $createGlobalObjectsKey
$usersSID = (New-Object System.Security.Principal.NTAccount("Users")).Translate([System.Security.Principal.SecurityIdentifier]).Value
$adminsSID = (New-Object System.Security.Principal.NTAccount("Administrators")).Translate([System.Security.Principal.SecurityIdentifier]).Value
$currentPrivileges.Value = $currentPrivileges.Value -replace $usersSID, ""
Set-ItemProperty -Path $secpolPath -Name $createGlobalObjectsKey -Value $currentPrivileges.Value

##### AUDIT CREDENTIAL VALIDATION #####
log "Enabling Audit Credential Validation..."
do {
    $auditChoice = Read-Host "Do you want to enable Audit Credential Validation for (1) Success only, (2) Failure only, or (3) Both? Enter the number corresponding to your choice: "
    switch ($auditChoice) {
        "1" {
            # Enable Success only
            auditpol /set /subcategory:"Credential Validation" /success:enable /failure:disable
            log "Audit Credential Validation has been enabled for Success events only."
            $validChoice = $true
        }
        "2" {
            # Enable Failure only
            auditpol /set /subcategory:"Credential Validation" /success:disable /failure:enable
            log "Audit Credential Validation has been enabled for Failure events only."
            $validChoice = $true
        }
        "3" {
            # Enable both Success and Failure
            auditpol /set /subcategory:"Credential Validation" /success:enable /failure:enable
            log "Audit Credential Validation has been enabled for both Success and Failure events."
            $validChoice = $true
        }
        Default {
            log "Invalid selection. Please try again."
            $validChoice = $false
        }
    }
} while (-not $validChoice)

##### DISABLING AUTOPLAY #####
log "Disabling AutoPlay..."
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun" -Value 0xFF

##### CONFIGURE WINDOWS SMARTSCREEN #####
log "Blocking windows smartscreen..."
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
$regKey = "SmartScreenEnabled"
# Set SmartScreen to Block
Set-ItemProperty -Path $regPath -Name $regKey -Value "Block"

##### PROMPT ADMINS BEFORE ELEVATING THEIR PRIVILEGES #####
log "Prompting admins before elevating their privileges..."
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$registryValueName = "ConsentPromptBehaviorAdmin"
$desiredBehavior = 4 # 3 = prompt for credentials, 4 = prompt for consent
Set-ItemProperty -Path $registryPath -Name $registryValueName -Value $desiredBehavior

##### REMOVING MEDIA FILES #####
$mediaExtensions = @("*.mp3", "*.mp4", "*.avi", "*.mkv", "*.flac", "*.wav", "*.mov", "*.wmv")
$mediaFiles = Get-ChildItem -Path "C:\Users\*" -Recurse -File | Where-Object { $mediaExtensions -contains $_.Extension.ToLower() }
$mediaFiles | Select-Object FullName | Out-File -FilePath "media_files.txt"
$mediaFiles | ForEach-Object {
    $confirmDelete = Read-Host "Do you want to delete '$($_.FullName)'? (Y/n): "
    if ($confirmDelete.ToLower() -eq 'n') {
        log "Skipped: $($_.FullName)"
    } else {
        Remove-Item -Path $_.FullName -Force
        log "Deleted: $($_.FullName)"
    }
}

##### AUDIT POLICIES #####
try {
    auditpol /set /category:"Account Logon" /success:enable 
    auditpol /set /category:"Account Logon" /failure:enable
    auditpol /set /category:"Account Management" /success:enable
    auditpol /set /category:"Account Management" /failure:enable
    auditpol /set /category:"DS Access" /success:enable
    auditpol /set /category:"DS Access" /failure:enable
    auditpol /set /category:"Logon/Logoff" /success:enable
    auditpol /set /category:"Logon/Logoff" /failure:enable
    auditpol /set /category:"Object Access" /success:enable
    auditpol /set /category:"Object Access" /failure:enable
    auditpol /set /category:"Policy Change" /success:enable
    auditpol /set /category:"Policy Change" /failure:enable
    auditpol /set /category:"Privilege Use" /success:enable
    auditpol /set /category:"Privilege Use" /failure:enable
    auditpol /set /category:"Detailed Tracking" /success:enable
    auditpol /set /category:"Detailed Tracking" /failure:enable
    auditpol /set /category:"System" /success:enable 
    auditpol /set /category:"System" /failure:enable
} catch {
    log "error: Failed to set audit policies."
}
# global audit policies
$OSWMI = Get-WmiObject Win32_OperatingSystem -Property Caption,Version
$OSName = $OSWMI.Caption
auditpol /resourceSACL /set /type:File /user:Administrator /success /failure /access:FW
auditpol /resourceSACL /set /type:Key /user:Administrator /success /failure /access:FW

##### GROUP POLICIES #####
Set-PolicyFileEntry -Path $env:systemroot\system32\GroupPolicy\Machine\registry.pol -Key "SOFTWARE\Policies\Microsoft\Messenger\Client" -ValueName PreventAutoRun -Type DWord -Data 1
Set-PolicyFileEntry -Path $env:systemroot\system32\GroupPolicy\Machine\registry.pol -Key "SOFTWARE\Policies\Microsoft\SearchCompanion" -ValueName DisableContentFileUpdates -Type DWord -Data 1
Set-PolicyFileEntry -Path $env:systemroot\system32\GroupPolicy\Machine\registry.pol -Key "SOFTWARE\Policies\Microsoft\Windows NT\IIS" -ValueName PreventIISInstall -Type DWord -Data 1
Set-PolicyFileEntry -Path $env:systemroot\system32\GroupPolicy\Machine\registry.pol -Key "SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -ValueName NoAutoUpdate -Type DWord -Data 0

##### SERVICE MANAGEMENT #####
log "Managing services..."
log "Disabling certain services..."
# disabling
sc stop TapiSrv
sc config TapiSrv start= disabled
sc stop TlntSvr
sc config TlntSvr start= disabled
sc stop ftpsvc
sc config ftpsvc start= disabled
sc stop SNMP
sc config SNMP start= disabled
sc stop SessionEnv
sc config SessionEnv start= disabled
sc stop TermService
sc config TermService start= disabled
sc stop UmRdpService
sc config UmRdpService start= disabled
sc stop SharedAccess
sc config SharedAccess start= disabled
sc stop remoteRegistry 
sc config remoteRegistry start= disabled
sc stop SSDPSRV
sc config SSDPSRV start= disabled
sc stop W3SVC
sc config W3SVC start= disabled
sc stop SNMPTRAP
sc config SNMPTRAP start= disabled
sc stop remoteAccess
sc config remoteAccess start= disabled
sc stop RpcSs
sc config RpcSs start= disabled
sc stop HomeGroupProvider
sc config HomeGroupProvider start= disabled
sc stop HomeGroupListener
sc config HomeGroupListener start= disabled
sc stop telnet
sc config telnet start= disabled
sc stop upnphost
sc config upnphost start= disabled
sc stop IISADMIN
sc config IISADMIN start= disabled
sc stop ConfRoom
sc config ConfRoom start= disabled
sc stop RDSessMgr
sc config RDSessMgr start= disabled
sc stop ssdpsrv
sc config ssdpsrv start= disabled
sc stop Messenger
sc config Messenger start= disabled
# enabling
log "Enabling certain services..."
sc config EventLog start= auto
sc start EventLog

##### ANTIVIRUS #####
# install antivirus and make another script for antivirus

##### UPDATE #####
# log "Checking for Windows updates..."
# Install-Module PSWindowsUpdate -Force -ErrorAction SilentlyContinue
# Import-Module PSWindowsUpdate
# try {
#     Get-WindowsUpdate -AcceptAll -Install -AutoReboot
#     log "Windows updates completed."
# } catch {
#     log "Failed to complete Windows updates: $_"
# }
# # Update all applications using Winget
# log "Updating applications via Winget..."
# try {
#     winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
#     log "Application updates completed."
# } catch {
#     log "Failed to update applications via Winget: $_"
# }
# # Update drivers using Device Manager
# log "Updating drivers..."
# try {
#     # Get a list of drivers that can be updated
#     $devices = Get-PnpDevice | Where-Object { $_.Status -eq "OK" }
#     foreach ($device in $devices) {
#         log "Updating driver for: $($device.Name)"
#         Update-PnpDevice -InstanceId $device.InstanceId -Confirm:$false
#     }
#     log "Driver updates completed."
# } catch {
#     log "Failed to update drivers: $_"
# }
# log "All updates completed."

##### RESTART #####
$choice = Read-Host "Do you want to restart the computer? (Y/n): "
if ($choice -eq 'N' -or $choice -eq 'n') {
    log "Restart canceled."
} else {
    Restart-Computer -Force
}

##### EXIT #####
exit