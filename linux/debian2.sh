#!/bin/bash
#GPL3 Licence 
#Copyright (c) 2024 Tanav Malhotra
unalias -a
start_time = $(date +"%Y-%m-%d, %I:%M:%S %p")
start_secs = $(date +%s)
log_file = "/linux_script.log"
# Make log file
touch "$log_file"
echo > "$log_file"

#TODO: use log function for printing msg
log() {
    echo $@ >> "$log_file"
    echo $@
}
log_info() { # does not print out to terminal
    echo $@ >> "$log_file"
}

# Check for sudo access
log "Checking for \`sudo\` access (which may request your password)..."
if [[ $EUID -ne 0 ]]; then
    log "\`sudo\` access is required. Please run \`sudo !!\`"
    exit 1
else
    log "\`sudo\` access confirmed. Proceeding..."
    sleep 1
fi

# Check for debug mode
if [ $# -gt 0 ]; then
    if [ "$1" == "--debug" ]; then
        debug = 1
        log "Debug mode is enabled."
        log "Current Directory: " pwd
        log "Start: $start_time"
    else
        log_info "Start: $start_time"
    fi
fi
sleep 1

clear
log "Created by Tanav Malhotra, Thomas A. Edison Career & Technical Education High School, New York City, NY, USA"
sleep 3
version = "v1.2.2"
log "CyberPatriot Linux Script $version"
sleep 1
log "Starting..."
log;log;
sleep 1

# Confirming with user
read -p "Have all of the Forensics Questions been answered yet? (Y/n): " $confirmation
if [[ $confirmation == n* || $confirmation == N* ]]; then
    log "Please complete these first and only then rerun the script."
    exit 1
fi
read -p "Have you created the required admins.txt, users.txt, addusers.txt, & addgroups.txt files in the _ directory? (Y/n): " $confirmation #TODO: fix _ in output
if [[ $confirmation == n* || $confirmation == N* ]]; then
    log "Please create these first by using the information from the README file located on your desktop."
    exit 1
fi

# Installing nala
log "Installing nala..."
apt install -y git python3-pip
apt-get install -y bum
git clone https://gitlab.com/volian/nala.git
cd nala
make install
cd ..
apt install -y nala
apt-get install -y nala

# Installing bash completion
log "Installing bash completion..."
nala --install-completion bash

# Updating system
log "Updating system..."
nala full-upgrade -y --install-recommends --install-suggests
if [[ $? -ne 0 ]]; then
    nala upgrade -y --full --install-recommends --install-suggests
    if [[ $? -ne 0 ]]; then
        nala upgrade -y --install-recommends --install-suggests
    fi
fi
nala autoremove -y #--purge

# Checking for updates daily
log "Checking for updates daily..."
cp /etc/apt/apt.conf.d/10periodic /etc/apt/apt.conf.d/10periodic.bak
sed -i 's/APT::Periodic::Update-Package-Lists "0";/APT::Periodic::Update-Package-Lists "1";/' /etc/apt/apt.conf.d/10periodic

# Installing Software
log "Installing software..."
apps=("openssh-server" "fail2ban" "bum" "mawk" "chkrootkit" "rkhunter" "auditd" "vim" "neovim" "ufw" "lightdm" "x2go" "deborphan" "libpam-cracklib" "unattended-upgrades")
for app in "${apps[@]}"; do
    log "Installing $app..."
    nala install -y "$app"
done

# Firewall
log "Setting up firewall..."
ufw enable

# Enabling syn cookie protection
log "Enabling syn cookie protection..."
sysctl -n net.ipv4.tcp_syncookies

# Disabling IPv6
log "Disabling IPv6..."
cp /etc/sysctl.conf /etc/sysctl.conf.bak
echo "net.ipv6.conf.all.disable_ipv6 = 1" | tee -a /etc/sysctl.conf

# Disable IP Forwarding
log "Disabling IP Forwarding..."
cp /proc/sys/net/ipv4/ip_forward /proc/sys/net/ipv4/ip_forward.bak
echo 0 | tee /proc/sys/net/ipv4/ip_forward

# Configuring SSH
log "Configuring SSH..."
sshd_config="/etc/ssh/sshd_config"
log "Creating SSH config backup located at ${sshd_config}.bak"
cp "$sshd_config" "${sshd_config}.bak"

# Function to ensure a line is set in the configuration
set_sshd_setting() {
    local setting="$1"
    local value="$2"
    
    # Check if the setting exists and update or add accordingly
    if grep -q "^$setting" "$sshd_config"; then
        sed -i "s/^$setting.*/$setting $value/" "$sshd_config"
        log "Updated $setting to $value."
    else
        log "$setting $value" >> "$sshd_config"
        log "Added $setting with value $value."
    fi
}

if [[ ! -f $sshd_config ]]; then
    log "Creating a basic sshd_config file (with secure settings)..."
    touch $sshd_config
fi
set_sshd_setting "PermitRootLogin" "no"
set_sshd_setting "Port" "22"
set_sshd_setting "PasswordAuthentication" "no"
set_sshd_setting "ChallengeResponseAuthentication" "no"
set_sshd_setting "UsePAM" "no"
set_sshd_setting "PermitEmptyPasswords" "no"
set_sshd_setting "ClientAliveInterval" "300"
set_sshd_setting "ClientAliveCountMax" "0"
set_sshd_setting "IgnoreRhosts" "yes"

# Extract the current port from the configuration
current_port = $(grep -Eo '^Port [0-9]+' "$sshd_config" | awk '{print $2}')
if [[ -z "$current_port" ]]; then
    current_port = 22  # Default to 22 if no port is found
fi

# Ask if the user wants to change the SSH port
read -p "Do you want to change the SSH port? (y/N): " change_port
for i in {1..10}; do                         
    echo -e "\a"
    sleep 0.1                                                    
done &
#TODO: function for bell
if [[ $change_port == y* || $change_port == Y* ]]; then
    while true; do
        read -p "Enter the new SSH port (1-65535): " new_port
        
        # Validate the input
        if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ]; then
            break
        else
            log "Invalid port number. Please enter a number between 1 and 65535."
        fi
    done

    # Update the SSHD configuration with the new port
    sed -i "s/^Port .*/Port $new_port/" $sshd_config
    log "SSH port changed to $new_port."
    
    # Allow the new port in UFW
    ufw delete allow "$current_port"/tcp
    log "Blocked old SSH port."
    ufw allow "$new_port"/tcp
    log "UFW allowed port $new_port."
else
    log "Keeping the default SSH port (22)."
    ufw allow "$current_port"/tcp
fi

if sshd -t; then
    log "SSH configuration is correct. Restarting SSH service..."
    if [[ -x "$(command -v systemctl)" ]]; then
        systemctl restart sshd
    elif [[ -x "$(command -v service)" ]]; then
        service sshd restart
    else
        log "Unable to restart sshd service."
    fi
else
    log "SSH configuration has errors. Please fix them before restarting."
fi

# Removing Software
apt list --installed > /software_that_was_installed.txt
log "Removing prohibited software and hacking tools..."
apps=("*wireshark*" "*telnet*" "*vsftpd*" "*proftpd*" "*snmpd*" "*mysql*" "*postgresql*" "*xrdp*" "*tightvncserver*" ".*samba.*" ".*smb.*" "*nmap*" "*zenmap*" "*apache2*" "*nginx*" "*lighttpd*" "*tcpdump*" "*netcat-traditional*" "*nikto*" "*ophcrack*" "*ettercap*" "*deluge*" "*dovecot*" "*netcat*" "*john*" "*vuze*" "*frostwire*" "*aircrack*" "*metasploit*" "*nessus*" "*snort*" "*kismet*" "*nikto*" "*yersinia*" "*burp-suite*" "*THCHydra*" "*oclhashcat*" "*maltego*" "*oswapzed*" "*cain*" "*angryipscanner*" "*ipscan*" "*ettercap*" "*hydra*" "*medusa*")
for app in "${apps[@]}"; do
    log "Purging $app..."
    nala purge -y "$app" #TODO: try removing instead of purging
done

# Removing Games
log "Removing games..."
games=$(dpkg -l | grep "game" | awk '{print $2}')
for game in "${apps[@]}"; do
    log "Purging $game..."
    nala purge -y "$game" #TODO: try removing instead of purging

# Setting up fail2ban
log "Ban IPs with too many incorrect login attempts..."
#systemctl reload-or-restart fail2ban.service
systemctl enable fail2ban.service
systemctl start fail2ban.service

# Disabling Certain Interfaces
#log "Disabling USB..."
#echo 'install usb-storage /bin/true' >> /etc/modprobe.d/disable-usb-storage.conf
#log "Disabling FireWire..."
#echo "blacklist firewire-core" >> /etc/modprobe.d/firewire.conf
#log "Disabling Thunderbolt..."
#echo "blacklist thunderbolt" >> /etc/modprobe.d/thunderbolt.conf

# Setting home directory permissions
log "Setting home directory permissions..."
for i in $(mawk -F: '$3 > 999 && $3 < 65534 {print $1}' /etc/passwd); do [ -d /home/${i} ] && chmod -R 750 /home/${i}; done
log "Changing permissions of commonly exploited files..."
chown root:root /etc/securetty
chmod 0600 /etc/securetty
chmod 644 /etc/crontab
chmod 640 /etc/ftpusers
chmod 440 /etc/inetd.conf
chmod 440 /etc/xinetd.conf
chmod 400 /etc/inetd.d
chmod 644 /etc/hosts.allow
chmod 440 /etc/sudoers
chmod 640 /etc/shadow
chown root:root /etc/shadow

# Setting max password days
log "Setting max password days..."
cp /etc/login.defs /etc/login.defs.bak
sed -i 's/PASS_MAX_DAYS.*$/PASS_MAX_DAYS 90/;s/PASS_MIN_DAYS.*$/PASS_MIN_DAYS 10/;s/PASS_WARN_AGE.*$/PASS_WARN_AGE 7/' /etc/login.defs

# Change PAM (Pluggable Authentication Modules) settings
log "Changing PAM settings (setting max password attempts, minimum password langths, etc.)..."
cp /etc/pam.d/common-auth /etc/pam.d/common-auth.bak
#echo 'auth required pam_tally2.so deny=5 onerr=fail unlock_time=1800' >> /etc/pam.d/common-auth
#echo 'auth required pam_unix.so' >> /etc/pam.d/common-auth
sed -i 's/nullok//g' /etc/pam.d/common-auth
sed -i 's/\(pam_tally2\.so.*\)$/\1 deny=5 audit unlock_time=1800/' /etc/pam.d/common-auth # lockout policy
cp /etc/pam.d/common-password /etc/pam.d/common-password.bak
sed -i 's/\(pam_unix\.so.*\)$/\1 remember=5 minlen=8/' /etc/pam.d/common-password
sed -i 's/\(pam_cracklib\.so.*\)$/\1 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-/' /etc/pam.d/common-password
cp /etc/default/useradd /etc/default/useradd.bak
sed -i 's/^EXPIRE=[0-9]\+/EXPIRE=30/' /etc/default/useradd
sed -i 's/^INACTIVE=[0-9]\+/INACTIVE=30/' /etc/default/useradd

# Setting up auditing
log "Setting up auditing..."
auditctl -e 1

# Finding and saving open ports
log "Finding and saving open ports to \`/open_ports.txt\`..."
ss -ln > /open_ports.txt

# Finding and saving running services
log "Finding and saving running services to \`/services.txt\`..."
service --status-all > /services.txt

# Finding unused software
log "Finding & saving unused software to \`/unused_software.txt\`..."
deborphan --guess-all > /unused_software.txt
log "Removing unused software..."
log "The following files will be removed:"
cat /unused_software.txt
# Prompt the user for confirmation
read -p "Do you want to proceed with the deletion? (Y/n): " choice
if [[ $choice == n* || $choice == N* ]]; then
    log "No software was removed."
else
    # Proceed with removal
    while IFS= read -r file; do
        rm -rf "$file"
    done < /unused_software.txt

    log "Unused software has been removed."
fi

# Finding & Removing Files
log "Finding & saving media files to \`/media_files.txt\`..."
find /home/ -type f \( -name "*.mp3" -o -name "*.mp4" -o -name "*.wav" -o -name "*.avi" -o -name "*.mkv" -o -name "*.flac" -o -name "*.mov" \) -print > /media_files.txt
log "Finding & saving possible hacking tools as packages to \`/packages.txt\`..."
find /home/ -type f \( -name "*.tar.gz" -o -name "*.tgz" -o -name "*.zip" -o -name "*.deb" \) -print > /packages.txt
log "Finding & saving World Writable files to \`/world_writable.txt\`..."
find /dir -xdev -type d \( -perm -0002 -a ! -perm -1000 \) -print > /world_writable.txt
log "Finding & saving No-User files to \`/no_user.txt\`..."
find /dir -xdev \( -nouser -o -nogroup \) -print > /no_user.txt

log "Removing media files..."
log "The following files will be removed:" >> /linux_script.log
cat /media_files.txt
# Prompt the user for confirmation
read -p "Do you want to proceed with the deletion? (Y/n): " choice
if [[ $choice == n* || $choice == N* ]]; then
    log "No files were removed."
else
    # Proceed with removal
    while IFS= read -r file; do
        rm -rf "$file"
    done < /media_files.txt

    log "Files have been removed."
fi

log "Removing packages..."
log "The following files will be removed:"
cat /packages.txt
# Prompt the user for confirmation
read -p "Do you want to proceed with the deletion? (Y/n): " choice
if [[ $choice == n* || $choice == N* ]]; then
    log "No files were removed."
else
    # Proceed with removal
    while IFS= read -r file; do
        rm -rf "$file"
    done < /packages.txt
    log "Files have been removed."
fi

log "Please manually check the world-writable files and the no-user files."

# Preventing IP Spoofing
log "Preventing IP Spoofing in /etc/host.conf..."
log "failed: no code for preventing IP spoofing written..."
#TODO: fix IP spoofing

# User Management
log "User Management..."
# Lock Root
log "Locking root account..."
passwd -l root
# log "Setting default shell for users..."
# chsh -s /bin/bash
cp /etc/sudoers /etc/sudoers.bak
cp /etc/sudoers.d /etc/sudoers.d.bak
cp /etc/passwd /etc/passwd.bak
cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.bak
cp /etc/lightdm/users.conf /etc/lightdm/users.conf.bak
sed -i 's/nopasswd//g' /etc/sudoers
sed -i 's/!authenticate//g' /etc/sudoers
sed -i 's/nopasswd//g' /etc/sudoers.d
sed -i 's/!authenticate//g' /etc/sudoers.d
log "Turning off guest login..."
sed -i 's/allow-guest=true/allow-guest=false/' /etc/lightdm/lightdm.conf
echo "allow-guest=false" >> /etc/lightdm/users.conf
mawk -F: '$1 == "sudo"' /etc/group > /admins.txt
log "Admins (saved to \`/admins.txt\`):"
mawk -F: '$3 > 999 && $3 < 65534 {print $1}' /etc/passwd > /users.txt
log "Users (saved to \`/users.txt\`):"
mawk -F: '$2 == ""' /etc/passwd > /no_passwd.txt
log "Empty Passwords (saved to \`/no_passwd.txt\`):"
mawk -F: '$3 == 0 && $1 != "root"' /etc/passwd > /non-root_uid0.txt
log "Non-root UID 0 users (saved to \`/non-root_uid0.txt\`):"
# Reading files for authorized users and admins
log "Reading users.txt, admins.txt, addusers.txt, and addgroups.txt..."
#TODO

# Changing Passwords
$NEW_PASSWORD="CyberPatr!0t"
log "Changing Passwords of all users, admins, and root to \`$NEW_PASSWORD\`..."

for user in $(cut -f1 -d: /etc/passwd); do
    if [[ "$user" != "root" && "$user" != "nobody" && "$user" != "daemon" && "$user" != "systemd-timesync" ]]; then
        if id -nG "$user" | grep -qw 'sudo'; then
            ROLE="admin"
        else
            ROLE="user"
        fi
        echo "$user:$NEW_PASSWORD" | chpasswd
        log "Password for $ROLE $user changed."
    fi
done
echo "root:$NEW_PASSWORD" | chpasswd
log "Password for admin root changed."

# Finding vulnerabilities
log "Finding vulnerabilities..."
log "Running \`chkrootkit\`..."
chkrootkit
log "Running \`rkhunter --update\`..."
rkhunter --update
log "Running \`rkhunter --check\`..."
rkhunter --check
log "Running \`freshclam\`..."
freshclam
log "Running \`clamscan -r --bell -i\`..."
clamscan -r --bell -i /

# Saving list of installed software
apt list --installed > /software_installed.txt

# Calculate time
$end_time = $(date +"%Y-%m-%d, %I:%M:%S %p")
$end_secs = $(date +%s)
log_info "End time: " $end_time
$duration = $(( $end_secs - $start_secs ))
$final_min = $(( $duration / 60 ))
$final_sec = $(( $duration % 60 ))

# Final Notes
log "Finished! in $final_min minutes and $final_sec seconds..."
log
log "Final Notes:"
log
log "Please manually check the world-writable files and the no-user files."
log "Please run \`sudo restart lightdm\`"
log;
# log "Launching settings..."
# if [[ "$DESKTOP_SESSION" == "gnome" ]]; then
#     gnome-control-center > /dev/null 2>&1 &
# elif [[ "$DESKTOP_SESSION" == "cinnamon" ]]; then
#     cinnamon-settings > /dev/null 2>&1 &
# elif [[ "$DESKTOP_SESSION" == "xfce" ]]; then
#     xfce4-settings-manager > /dev/null 2>&1 &
# elif [[ "$DESKTOP_SESSION" == "kde" ]]; then
#     systemsettings5 > /dev/null 2>&1 &
# fi

# Wishing Goodluck
log;log;log
log "Thank you for using this script. Good luck for the competition!"
log;
log "==================================="
log "Copyright (c) 2024 Tanav Malhotra"
log "GPL3 License"
log "==================================="
