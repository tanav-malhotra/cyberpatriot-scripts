#!/bin/bash
#GPL3 Licence 
#Copyright (c) Tanav Malhotra
clear
echo "Created by Tanav Malhotra, Thomas A. Edison Career & Technical Education High School, New York City, NY, USA"
sleep 3
echo "Ubuntu Linux Script v1.0.0"
sleep 1
echo "Starting..."
sleep 1

# Check for sudo access
if sudo -n true 2>/dev/null; then
    echo "Checking for sudo access..."
    echo "Sudo access confirmed. Proceeding..."
    sleep 1
else
    echo "Checking for sudo access..."
    echo "Sudo access is required. Please run \`sudo !!\`"
    exit 1
fi

# Removing Aliases
echo "Removing existing aliases (if any)..."
unalias -a

# Updating system
echo "Updating system..."
apt-get update -y && apt-get upgrade -y && apt-get dist-upgrade -y

# Firewall
echo "Setting up firewall..."
apt-get install -y ufw && ufw enable

# Lock Root
echo "Locking root account..."
passwd -l root

# Installing Software
echo "Installing software..."
apt-get install -y openssh-server fail2ban bum mawk chkrootkit rkhunter libpam-cracklib auditd

# Configuring SSH
echo "Configuring SSH..."
sshd_config="/etc/ssh/sshd_config"
echo "Creating SSH config backup located at ${sshd_config}.bak"
cp "$sshd_config" "${sshd_config}.bak"

# Function to ensure a line is set in the configuration
set_sshd_setting() {
    local setting="$1"
    local value="$2"
    
    # Check if the setting exists and update or add accordingly
    if grep -q "^$setting" "$sshd_config"; then
        sed -i "s/^$setting.*/$setting $value/" "$sshd_config"
        echo "Updated $setting to $value."
    else
        echo "$setting $value" >> "$sshd_config"
        echo "Added $setting with value $value."
    fi
}

if [[ ! -f $sshd_config ]]; then
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
if [[ $change_port == y* ]]; then
    while true; do
        read -p "Enter the new SSH port (1-65535): " new_port
        
        # Validate the input
        if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ]; then
            break
        else
            echo "Invalid port number. Please enter a number between 1 and 65535."
        fi
    done

    # Update the SSHD configuration with the new port
    sed -i "s/^Port .*/Port $new_port/" $sshd_config
    echo "SSH port changed to $new_port."
    
    # Allow the new port in UFW
    ufw delete allow "$current_port"/tcp
    echo "Blocked old SSH port."
    ufw allow "$new_port"/tcp
    echo "UFW allowed port $new_port."
else
    echo "Keeping the default SSH port (22)."
    ufw allow "$current_port"/tcp
fi

if sudo sshd -t; then
    echo "SSH configuration is correct. Restarting SSH service..."
    if [[ -x "$(command -v systemctl)" ]]; then
        sudo systemctl restart sshd
    elif [[ -x "$(command -v service)" ]]; then
        sudo service sshd restart
    else
        echo "Unable to restart sshd service."
    fi
else
    echo "SSH configuration has errors. Please fix them before restarting."
fi

# Removing Software
echo "Removing prohibited software and hacking tools..."
apt-get purge -y wireshark wireshark-qt wireshark-common telnet vsftpd proftpd snmpd mysql postgresql xrdp tightvncserver .*samba.* .*smb.* nmap zenmap apache2 nginx lighttpd tcpdump netcat-traditional nikto ophcrack

# Setting up fail2ban
echo "Ban IPs with too many incorrect login attempts..."
systemctl restart fail2ban.service

# Preventing IP Spoofing
echo "Preventing IP Spoofing in /etc/host.conf..."
grep -qF 'multi on' && sed 's/multi/nospoof/' || echo 'nospoof on' >> /etc/host.conf

# Finding backdoors
echo "Finding backdoors/rootkits..."
chkrootkit
rkhunter --update
rkhunter --check

# Disabling Certain Interfaces
echo "Disabling USB..."
echo 'install usb-storage /bin/true' >> /etc/modprobe.d/disable-usb-storage.conf
echo "Disabling FireWire..."
echo "blacklist firewire-core" >> /etc/modprobe.d/firewire.conf
echo "Disabling Thunderbolt..."
echo "blacklist thunderbolt" >> /etc/modprobe.d/thunderbolt.conf

# Setting home directory permissions
echo "Setting home directory permissions..."
for i in $(mawk -F: '$3 > 999 && $3 < 65534 {print $1}' /etc/passwd); do [ -d /home/${i} ] && chmod -R 750 /home/${i}; done

# Change login chances
echo "Changing login chances..."
sed -i 's/PASS_MAX_DAYS.*$/PASS_MAX_DAYS 90/;s/PASS_MIN_DAYS.*$/PASS_MIN_DAYS 10/;s/PASS_WARN_AGE.*$/PASS_WARN_AGE 7/' /etc/login.defs

# Change PAM (Pluggable Authentication Modules) settings
echo "Changing PAM settings (setting max password attempts, minimum password langths, etc.)..."
echo 'auth required pam_tally2.so deny=5 onerr=fail unlock_time=1800' >> /etc/pam.d/common-auth
sed -i 's/\(pam_unix\.so.*\)$/\1 remember=5 minlen=8/' /etc/pam.d/common-password
sed -i 's/\(pam_cracklib\.so.*\)$/\1 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1/' /etc/pam.d/common-password

# Setting up auditing
echo "Setting up auditing..."
auditctl -e 1

# Finding & Removing Files
echo "Finding & saving media files to \`/media_files.txt\`..."
find / -type f \( -name "*.mp3" -o -name "*.mp4" -o -name "*.wav" -o -name "*.avi" -o -name "*.mkv" -o -name "*.flac" -o -name "*.mov" \) -print > /media_files.txt
echo "Finding & saving possible hacking tools as packages to \`/packages.txt\`..."
find / -type f \( -name "*.tar.gz" -o -name "*.tgz" -o -name "*.zip" -o -name "*.deb" \) -print > /packages.txt
echo "Finding & saving World Writable files to \`/world_writable.txt\`..."
find /dir -xdev -type d \( -perm -0002 -a ! -perm -1000 \) -print > /world_writable.txt
echo "Finding & saving No-User files to \`/no_user.txt\`..."
find /dir -xdev \( -nouser -o -nogroup \) -print > /no_user.txt

echo "Removing media files..."
echo "The following files will be removed:"
xargs echo rm < /media_files.txt 2>/dev/null
# Prompt the user for confirmation
read -p "Do you want to proceed with the deletion? (Y/n): " choice
if [[ "$choice" == "n" || "$choice" == "N" ]]; then
    echo "No files were removed."
else
    # Proceed with removal
    xargs rm < /media_files.txt
    echo "Files have been removed."
fi

echo "Removing packages..."
echo "The following files will be removed:"
xargs echo rm < /packages.txt 2>/dev/null
# Prompt the user for confirmation
read -p "Do you want to proceed with the deletion? (Y/n): " choice
if [[ "$choice" == "n" || "$choice" == "N" ]]; then
    echo "No files were removed."
else
    # Proceed with removal
    xargs rm < /packages.txt
    echo "Files have been removed."
fi

echo "Please manually check the world-writable files and the no-user files."

# User Management
echo "Wierd Admins (saved to \`/weird_admins.txt\`):"
mawk -F: '$1 == "sudo"' /etc/group > /weird_admins.txt
echo "Wierd Users (saved to \`/weird_users.txt\`):"
mawk -F: '$3 > 999 && $3 < 65534 {print $1}' /etc/passwd > /weird_users.txt
echo "Empty Passwords (saved to \`/no_passwd.txt\`):"
mawk -F: '$2 == ""' /etc/passwd > /no_passwd.txt
echo "Non-root UID 0 users (saved to \`/non-root_uid0.txt\`):"
mawk -F: '$3 == 0 && $1 != "root"' /etc/passwd > /non-root_uid0.txt

# Final Notes
echo "Final Notes:"
echo
echo "Please manually check the world-writable files and the no-user files."

echo;echo;echo
echo "Thank you for using this script. Good luck for the competition!"
echo
echo "=============================="
echo "Copyright (c) 2024 Tanav Malhotra"
echo "GPL3 License"
echo "=============================="
