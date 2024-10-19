#!/bin/bash
#GPL3 Licence 
#Copyright (c) Tanav Malhotra
unalias -a
clear
echo "Created by Tanav Malhotra, Thomas A. Edison Career & Technical Education High School, New York City, NY, USA"
sleep 3
echo "Ubuntu Linux Script v1.0.6"
sleep 1
echo "Starting..."
sleep 1

# Check for sudo access
echo "Checking for \`sudo\` access (which may request your password)..." > /ubuntu_script.log
echo "Checking for \`sudo\` access (which may request your password)..."
if [[ $EUID -ne 0 ]]; then
    echo "\`sudo\` access is required. Please run \`sudo !!\`" >> /ubuntu_script.log
    echo "\`sudo\` access is required. Please run \`sudo !!\`"
    exit 1
else
    echo "\`sudo\` access confirmed. Proceeding..." >> /ubuntu_script.log
    echo "\`sudo\` access confirmed. Proceeding..."
    sleep 1
fi

# Updating system
echo "Updating system..." >> /ubuntu_script.log
echo "Updating system..."
apt update -y && apt full-upgrade -y
apt autoremove -y

# Firewall
echo "Setting up firewall..." >> /ubuntu_script.log
echo "Setting up firewall..."
apt install -y ufw && ufw enable

# Lock Root
echo "Locking root account..." >> /ubuntu_script.log
echo "Locking root account..."
passwd -l root

# Installing Software
echo "Installing software..." >> /ubuntu_script.log
echo "Installing software..."
apt install -y openssh-server fail2ban bum mawk chkrootkit rkhunter libpam-cracklib auditd vim neovim

# Configuring SSH
echo "Configuring SSH..." >> /ubuntu_script.log
echo "Configuring SSH..."
sshd_config="/etc/ssh/sshd_config"
echo "Creating SSH config backup located at ${sshd_config}.bak" >> /ubuntu_script.log
echo "Creating SSH config backup located at ${sshd_config}.bak"
cp "$sshd_config" "${sshd_config}.bak"

# Function to ensure a line is set in the configuration
set_sshd_setting() {
    local setting="$1"
    local value="$2"
    
    # Check if the setting exists and update or add accordingly
    if grep -q "^$setting" "$sshd_config"; then
        sed -i "s/^$setting.*/$setting $value/" "$sshd_config"
        echo "Updated $setting to $value." >> /ubuntu_script.log
        echo "Updated $setting to $value."
    else
        echo "$setting $value" >> "$sshd_config" >> /ubuntu_script.log
        echo "$setting $value" >> "$sshd_config"
        echo "Added $setting with value $value." >> /ubuntu_script.log
        echo "Added $setting with value $value."
    fi
}

if [[ ! -f $sshd_config ]]; then
    echo "Creating a basic sshd_config file (with secure settings)..." >> /ubuntu_script.log
    echo "Creating a basic sshd_config file (with secure settings)..."
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
current_port=$(grep -Eo '^Port [0-9]+' "$sshd_config" | awk '{print $2}')

if [[ -z "$current_port" ]]; then
    current_port=22  # Default to 22 if no port is found
fi

# Ask if the user wants to change the SSH port
read -p "Do you want to change the SSH port? (y/N): " change_port
if [[ $change_port == y* || $change_port == Y* ]]; then
    while true; do
        read -p "Enter the new SSH port (1-65535): " new_port
        
        # Validate the input
        if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ]; then
            break
        else
            echo "Invalid port number. Please enter a number between 1 and 65535." >> /ubuntu_script.log
            echo "Invalid port number. Please enter a number between 1 and 65535."
        fi
    done

    # Update the SSHD configuration with the new port
    sed -i "s/^Port .*/Port $new_port/" $sshd_config
    echo "SSH port changed to $new_port." >> /ubuntu_script.log
    echo "SSH port changed to $new_port."
    
    # Allow the new port in UFW
    ufw delete allow "$current_port"/tcp
    echo "Blocked old SSH port." >> /ubuntu_script.log
    echo "Blocked old SSH port."
    ufw allow "$new_port"/tcp
    echo "UFW allowed port $new_port." >> /ubuntu_script.log
    echo "UFW allowed port $new_port."
else
    echo "Keeping the default SSH port (22)." >> /ubuntu_script.log
    echo "Keeping the default SSH port (22)."
    ufw allow "$current_port"/tcp
fi

if sudo sshd -t; then
    echo "SSH configuration is correct. Restarting SSH service..." >> /ubuntu_script.log
    echo "SSH configuration is correct. Restarting SSH service..."
    if [[ -x "$(command -v systemctl)" ]]; then
        sudo systemctl restart sshd
    elif [[ -x "$(command -v service)" ]]; then
        sudo service sshd restart
    else
        echo "Unable to restart sshd service." >> /ubuntu_script.log
        echo "Unable to restart sshd service."
    fi
else
    echo "SSH configuration has errors. Please fix them before restarting." >> /ubuntu_script.log
    echo "SSH configuration has errors. Please fix them before restarting."
fi

# Removing Software
echo "Removing prohibited software and hacking tools..." >> /ubuntu_script.log
echo "Removing prohibited software and hacking tools..."
apt purge -y *wireshark* *telnet* *vsftpd* *proftpd* *snmpd* *mysql* *postgresql* *xrdp* *tightvncserver* .*samba.* .*smb.* *nmap* *zenmap* *apache2* *nginx* *lighttpd* *tcpdump* *netcat-traditional* *nikto* *ophcrack*

# Setting up fail2ban
echo "Ban IPs with too many incorrect login attempts..." >> /ubuntu_script.log
echo "Ban IPs with too many incorrect login attempts..."
#systemctl reload-or-restart fail2ban.service
systemctl enable fail2ban.service
systemctl start fail2ban.service

# Finding backdoors
echo "Finding backdoors/rootkits..." >> /ubuntu_script.log
echo "Finding backdoors/rootkits..."
chkrootkit
rkhunter --update
rkhunter --check

# Disabling Certain Interfaces
#echo "Disabling USB..."
#echo 'install usb-storage /bin/true' >> /etc/modprobe.d/disable-usb-storage.conf
#echo "Disabling FireWire..."
#echo "blacklist firewire-core" >> /etc/modprobe.d/firewire.conf
#echo "Disabling Thunderbolt..."
#echo "blacklist thunderbolt" >> /etc/modprobe.d/thunderbolt.conf

# Setting home directory permissions
echo "Setting home directory permissions..." >> /ubuntu_script.log
echo "Setting home directory permissions..."
for i in $(mawk -F: '$3 > 999 && $3 < 65534 {print $1}' /etc/passwd); do [ -d /home/${i} ] && chmod -R 750 /home/${i}; done
echo "Changing permissions of commonly exploited files..." >> /ubuntu_script.log
echo "Changing permissions of commonly exploited files..."
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
echo "Setting max password days..." >> /ubuntu_script.log
echo "Setting max password days..."
cp /etc/login.defs /etc/login.defs.bak
sed -i 's/PASS_MAX_DAYS.*$/PASS_MAX_DAYS 90/;s/PASS_MIN_DAYS.*$/PASS_MIN_DAYS 10/;s/PASS_WARN_AGE.*$/PASS_WARN_AGE 7/' /etc/login.defs

# Change PAM (Pluggable Authentication Modules) settings
echo "Changing PAM settings (setting max password attempts, minimum password langths, etc.)..." >> /ubuntu_script.log
echo "Changing PAM settings (setting max password attempts, minimum password langths, etc.)..."
# echo 'auth required pam_tally2.so deny=5 onerr=fail unlock_time=1800' >> /etc/pam.d/common-auth
cp /etc/pam.d/common-auth /etc/pam.d/common-auth.bak
cp /etc/pam.d/common-password /etc/pam.d/common-password.bak
sed -i 's/nullok//g' /etc/pam.d/common-auth
sed -i 's/\(pam_unix\.so.*\)$/\1 remember=5 minlen=8/' /etc/pam.d/common-password
sed -i 's/\(pam_cracklib\.so.*\)$/\1 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1/' /etc/pam.d/common-password

# Setting up auditing
echo "Setting up auditing..." >> /ubuntu_script.log
echo "Setting up auditing..."
auditctl -e 1

# Finding & Removing Files
echo "Finding & saving media files to \`/media_files.txt\`..." >> /ubuntu_script.log
echo "Finding & saving media files to \`/media_files.txt\`..."
find / -type f \( -name "*.mp3" -o -name "*.mp4" -o -name "*.wav" -o -name "*.avi" -o -name "*.mkv" -o -name "*.flac" -o -name "*.mov" \) -print > /media_files.txt
echo "Finding & saving possible hacking tools as packages to \`/packages.txt\`..." >> /ubuntu_script.log
echo "Finding & saving possible hacking tools as packages to \`/packages.txt\`..."
find / -type f \( -name "*.tar.gz" -o -name "*.tgz" -o -name "*.zip" -o -name "*.deb" \) -print > /packages.txt
echo "Finding & saving World Writable files to \`/world_writable.txt\`..." >> /ubuntu_script.log
echo "Finding & saving World Writable files to \`/world_writable.txt\`..."
find /dir -xdev -type d \( -perm -0002 -a ! -perm -1000 \) -print > /world_writable.txt
echo "Finding & saving No-User files to \`/no_user.txt\`..." >> /ubuntu_script.log
echo "Finding & saving No-User files to \`/no_user.txt\`..."
find /dir -xdev \( -nouser -o -nogroup \) -print > /no_user.txt

echo "Removing media files..." >> /ubuntu_script.log
echo "Removing media files..."
echo "The following files will be removed:" >> /ubuntu_script.log
echo "The following files will be removed:"
xargs echo rm < /media_files.txt 2>/dev/null
# Prompt the user for confirmation
read -p "Do you want to proceed with the deletion? (Y/n): " choice
if [[ $choice == n* || $choice == N* ]]; then
    echo "No files were removed." >> /ubuntu_script.log
    echo "No files were removed."
else
    # Proceed with removal
    xargs -0 rm < /media_files.txt
    echo "Files have been removed." >> /ubuntu_script.log
    echo "Files have been removed."
fi

echo "Removing packages..." >> /ubuntu_script.log
echo "Removing packages..."
echo "The following files will be removed:" >> /ubuntu_script.log
echo "The following files will be removed:"
xargs echo rm < /packages.txt 2>/dev/null
# Prompt the user for confirmation
read -p "Do you want to proceed with the deletion? (Y/n): " choice
if [[ $choice == n* || $choice == N* ]]; then
    echo "No files were removed." >> /ubuntu_script.log
    echo "No files were removed."
else
    # Proceed with removal
    xargs -0 rm < /packages.txt
    echo "Files have been removed." >> /ubuntu_script.log
    echo "Files have been removed."
fi

echo "Please manually check the world-writable files and the no-user files." >> /ubuntu_script.log
echo "Please manually check the world-writable files and the no-user files."

# Preventing IP Spoofing
echo "Preventing IP Spoofing in /etc/host.conf..." >> /ubuntu_script.log
echo "Preventing IP Spoofing in /etc/host.conf..."
#grep -qF 'multi on' && sed 's/multi/nospoof/' || echo 'nospoof on' >> /etc/host.conf
if grep -qF 'multi on' /etc/host.conf; then
    sed -i 's/multi/nospoof/' /etc/host.conf
else
    echo 'nospoof on' | sudo tee -a /etc/host.conf > /dev/null
fi

# User Management
mawk -F: '$1 == "sudo"' /etc/group > /admins.txt
echo "Admins (saved to \`/admins.txt\`):" >> /ubuntu_script.log
echo "Admins (saved to \`/admins.txt\`):"
mawk -F: '$3 > 999 && $3 < 65534 {print $1}' /etc/passwd > /users.txt
echo "Users (saved to \`/users.txt\`):" >> /ubuntu_script.log
echo "Users (saved to \`/users.txt\`):"
mawk -F: '$2 == ""' /etc/passwd > /no_passwd.txt
echo "Empty Passwords (saved to \`/no_passwd.txt\`):" >> /ubuntu_script.log
echo "Empty Passwords (saved to \`/no_passwd.txt\`):"
mawk -F: '$3 == 0 && $1 != "root"' /etc/passwd > /non-root_uid0.txt
echo "Non-root UID 0 users (saved to \`/non-root_uid0.txt\`):" >> /ubuntu_script.log
echo "Non-root UID 0 users (saved to \`/non-root_uid0.txt\`):"

# Final Notes
echo "Final Notes:" >> /ubuntu_script.log
echo "Final Notes:"
echo >> /ubuntu_script.log
echo
echo "Please manually check the world-writable files and the no-user files." >> /ubuntu_script.log
echo "Please manually check the world-writable files and the no-user files."

echo;echo;echo
echo "Thank you for using this script. Good luck for the competition!"
echo
echo "==================================="
echo "Copyright (c) 2024 Tanav Malhotra"
echo "GPL3 License"
echo "==================================="
