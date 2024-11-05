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
# with the '--license' option.
# ====================================================================================

# Check for administrator access
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
	Write-Host "Please run this script as an administrator."
	exit
} # TODO: fix error

# Functions
#TODO: make function to log and print

# Password and Lockout Policy
Write-Host "Setting password settings and lockout policy..."

$users = Get-LocalUser | Where-Object { $_.Name -ne 'Administrator' -and $_.Name -ne 'DefaultAccount' }
foreach ($user in $users) {
	Set-LocalUser -Name $user.Name -MaximumPasswordAge (New-TimeSpan -Days 90)
}
$admins = Get-LocalGroupMember -Group "Administrators"
foreach ($admin in $admins) {
	Set-LocalUser -Name $admin.Name -MaximumPasswordAge (New-TimeSpan -Days 30)
}
net accounts /maxpwage:90
net accounts /minpwage:10
net accounts /minpwlen:10
net accounts /uniquepw:5
net accounts /lockoutthreshold:5 # attempts
net accounts /lockoutduration:30 # minutes
net accounts /lockoutwindow:30 # minutes before failed login attempts threshold counter is reset to 0

# Password Complexity
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" `
	-Name "PasswordComplexity" -Value 1 -PropertyType DWord -Force
# Disable Password Reversible Encryption (Decryption)
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Password" `
	-Name "DisableReversibleEncryption" -Value 1 -PropertyType DWord -Force
Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'DisablePasswordReversibleEncryption' -Value 1
# Firewall settings
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled True
Set-NetFirewallRule -DisplayGroup "Windows Firewall" -Enabled True
New-NetFirewallRule -DisplayName "Allow MyApp" -Direction Inbound -Program "C:\Path\To\YourApp.exe" -Action Allow
New-NetFirewallRule -DisplayName "Allow HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow

# Disable IPv6
Set-NetAdapterBinding -Name "*" -ComponentID ms_tcpip6 -Enabled $false
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' -Name 'DisabledComponents' -Value 0xFFFFFFFF

# Disable Guest login
Set-LocalUser -Name "Guest" -Enabled $false

# Remove apps

# Update Apps

# Antivirus install

# Enable Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $false
# Update Windows Defender
Update-MpSignature

#Disabling Services
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


# Update OS (in the end)

# Exit
exit