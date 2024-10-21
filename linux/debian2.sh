#!/bin/bash
#GPL3 Licence 
#Copyright (c) 2024 Tanav Malhotra
unalias -a
#TODO: make function for printing and sending to log file
# Check if an argument was passed
if [ $# -gt 0 ]; then
    if [ "$1" == "--debug" ]; then
        $debug = 1
        echo "Debug mode is enabled." > /linux_script.log
        echo "Debug mode is enabled."
        echo "Current Directory: " pwd >> /linux_script.log
        echo "Current Directory: " pwd
        #TODO: print current time in log
        #TODO: print current time
    fi
fi

sleep 1
clear
cd
echo "Created by Tanav Malhotra, Thomas A. Edison Career & Technical Education High School, New York City, NY, USA" >> /linux_script.log
echo "Created by Tanav Malhotra, Thomas A. Edison Career & Technical Education High School, New York City, NY, USA"
sleep 3
echo "CyberPatriot Linux Script v1.2.1" >> /linux_script.log
echo "CyberPatriot Linux Script v1.2.1"
sleep 1
echo "Starting..." >> /linux_script.log
echo "Starting..."
echo;echo;
sleep 1

# Confirming with user
read -p "Have all of the Forensics Questions been answered yet? (Y/n): " $confirmation
if [[ $confirmation == n* || $confirmation == N* ]]; then
    echo "Please complete these first and only then rerun the script." >> /linux_script.log
    echo "Please complete these first and only then rerun the script."
    exit 1
fi
read -p "Have you created the required admins.txt, users.txt, addusers.txt, & addgroups.txt files in the _ directory? (Y/n): " $confirmation #TODO: fix _ in output
if [[ $confirmation == n* || $confirmation == N* ]]; then
    echo "Please create these first by using the information from the README file located on your desktop." >> /linux_script.log
    echo "Please create these first by using the information from the README file located on your desktop."
    exit 1
fi

# Check for sudo access
echo "Checking for \`sudo\` access (which may request your password)..." >> /linux_script.log
echo "Checking for \`sudo\` access (which may request your password)..."
if [[ $EUID -ne 0 ]]; then
    echo "\`sudo\` access is required. Please run \`sudo !!\`" >> /linux_script.log
    echo "\`sudo\` access is required. Please run \`sudo !!\`"
    exit 1
else
    echo "\`sudo\` access confirmed. Proceeding..." >> /linux_script.log
    echo "\`sudo\` access confirmed. Proceeding..."
    sleep 1
fi

# Installing nala
echo "Installing nala..." >> /linux_script.log
echo "Installing nala..."
apt install -y git python3-pip
apt-get install -y bum
git clone https://gitlab.com/volian/nala.git
cd nala
make install
cd ..
alias apt="nala -y"
apt install -y nala
apt-get install -y nala

# Installing bash completion
echo "Installing bash completion..." >> /linux_script.log
echo "Installing bash completion..."
nala --install-completion bash

# Updating system
echo "Updating system..." >> /linux_script.log
echo "Updating system..."
nala full-upgrade -y --install-recommends --install-suggests
if [[ $? -ne 0 ]]; then
    nala upgrade -y --full --install-recommends --install-suggests
    if [[ $? -ne 0 ]]; then
        nala upgrade -y --install-recommends --install-suggests
    fi
fi
nala autoremove -y #--purge

# Checking for updates daily
echo "Checking for updates daily..." >> /linux_script.log
echo "Checking for updates daily..."
cp /etc/apt/apt.conf.d/10periodic /etc/apt/apt.conf.d/10periodic.bak
sed -i 's/APT::Periodic::Update-Package-Lists "0";/APT::Periodic::Update-Package-Lists "1";/' /etc/apt/apt.conf.d/10periodic

# Lock Root
echo "Locking root account..." >> /linux_script.log
echo "Locking root account..."
passwd -l root

# Installing Software
echo "Installing software..." >> /linux_script.log
echo "Installing software..."
apps=("openssh-server" "fail2ban" "bum" "mawk" "chkrootkit" "rkhunter" "auditd" "vim" "neovim" "ufw" "lightdm") # "libpam-cracklib"
for app in "${apps[@]}"; do
    echo "Installing $app..." >> /linux_script.log
    echo "Installing $app..."
    nala install -y "$app"
done

# Firewall
echo "Setting up firewall..." >> /linux_script.log
echo "Setting up firewall..."
ufw enable

# Configuring SSH
echo "Configuring SSH..." >> /linux_script.log
echo "Configuring SSH..."
sshd_config="/etc/ssh/sshd_config"
echo "Creating SSH config backup located at ${sshd_config}.bak" >> /linux_script.log
echo "Creating SSH config backup located at ${sshd_config}.bak"
cp "$sshd_config" "${sshd_config}.bak"

# Function to ensure a line is set in the configuration
set_sshd_setting() {
    local setting="$1"
    local value="$2"
    
    # Check if the setting exists and update or add accordingly
    if grep -q "^$setting" "$sshd_config"; then
        sed -i "s/^$setting.*/$setting $value/" "$sshd_config"
        echo "Updated $setting to $value." >> /linux_script.log
        echo "Updated $setting to $value."
    else
        echo "$setting $value" >> "$sshd_config" >> /linux_script.log
        echo "$setting $value" >> "$sshd_config"
        echo "Added $setting with value $value." >> /linux_script.log
        echo "Added $setting with value $value."
    fi
}

if [[ ! -f $sshd_config ]]; then
    echo "Creating a basic sshd_config file (with secure settings)..." >> /linux_script.log
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
for i in {1..10}; do                         
    echo -e "\a"
    sleep 0.1                                                    
done &
if [[ $change_port == y* || $change_port == Y* ]]; then
    while true; do
        read -p "Enter the new SSH port (1-65535): " new_port
        
        # Validate the input
        if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ]; then
            break
        else
            echo "Invalid port number. Please enter a number between 1 and 65535." >> /linux_script.log
            echo "Invalid port number. Please enter a number between 1 and 65535."
        fi
    done

    # Update the SSHD configuration with the new port
    sed -i "s/^Port .*/Port $new_port/" $sshd_config
    echo "SSH port changed to $new_port." >> /linux_script.log
    echo "SSH port changed to $new_port."
    
    # Allow the new port in UFW
    ufw delete allow "$current_port"/tcp
    echo "Blocked old SSH port." >> /linux_script.log
    echo "Blocked old SSH port."
    ufw allow "$new_port"/tcp
    echo "UFW allowed port $new_port." >> /linux_script.log
    echo "UFW allowed port $new_port."
else
    echo "Keeping the default SSH port (22)." >> /linux_script.log
    echo "Keeping the default SSH port (22)."
    ufw allow "$current_port"/tcp
fi

if sudo sshd -t; then
    echo "SSH configuration is correct. Restarting SSH service..." >> /linux_script.log
    echo "SSH configuration is correct. Restarting SSH service..."
    if [[ -x "$(command -v systemctl)" ]]; then
        sudo systemctl restart sshd
    elif [[ -x "$(command -v service)" ]]; then
        sudo service sshd restart
    else
        echo "Unable to restart sshd service." >> /linux_script.log
        echo "Unable to restart sshd service."
    fi
else
    echo "SSH configuration has errors. Please fix them before restarting." >> /linux_script.log
    echo "SSH configuration has errors. Please fix them before restarting."
fi

# Removing Software
echo "Removing prohibited software and hacking tools..." >> /linux_script.log
echo "Removing prohibited software and hacking tools..."
apps=("*wireshark*" "*telnet*" "*vsftpd*" "*proftpd*" "*snmpd*" "*mysql*" "*postgresql*" "*xrdp*" "*tightvncserver*" ".*samba.*" ".*smb.*" "*nmap*" "*zenmap*" "*apache2*" "*nginx*" "*lighttpd*" "*tcpdump*" "*netcat-traditional*" "*nikto*" "*ophcrack*" "*ettercap*" "*deluge*")
for app in "${apps[@]}"; do
    echo "Purging $app..." >> /linux_script.log
    echo "Purging $app..."
    nala purge -y "$app" #TODO: try removing instead of purging
done

# Setting up fail2ban
echo "Ban IPs with too many incorrect login attempts..." >> /linux_script.log
echo "Ban IPs with too many incorrect login attempts..."
#systemctl reload-or-restart fail2ban.service
systemctl enable fail2ban.service
systemctl start fail2ban.service

# Disabling Certain Interfaces
#echo "Disabling USB..."
#echo 'install usb-storage /bin/true' >> /etc/modprobe.d/disable-usb-storage.conf
#echo "Disabling FireWire..."
#echo "blacklist firewire-core" >> /etc/modprobe.d/firewire.conf
#echo "Disabling Thunderbolt..."
#echo "blacklist thunderbolt" >> /etc/modprobe.d/thunderbolt.conf

# Setting home directory permissions
echo "Setting home directory permissions..." >> /linux_script.log
echo "Setting home directory permissions..."
for i in $(mawk -F: '$3 > 999 && $3 < 65534 {print $1}' /etc/passwd); do [ -d /home/${i} ] && chmod -R 750 /home/${i}; done
echo "Changing permissions of commonly exploited files..." >> /linux_script.log
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
echo "Setting max password days..." >> /linux_script.log
echo "Setting max password days..."
cp /etc/login.defs /etc/login.defs.bak
sed -i 's/PASS_MAX_DAYS.*$/PASS_MAX_DAYS 90/;s/PASS_MIN_DAYS.*$/PASS_MIN_DAYS 10/;s/PASS_WARN_AGE.*$/PASS_WARN_AGE 7/' /etc/login.defs

# Change PAM (Pluggable Authentication Modules) settings
echo "Changing PAM settings (setting max password attempts, minimum password langths, etc.)..." >> /linux_script.log
echo "Changing PAM settings (setting max password attempts, minimum password langths, etc.)..."
cp /etc/pam.d/common-auth /etc/pam.d/common-auth.bak
#echo 'auth required pam_tally2.so deny=5 onerr=fail unlock_time=1800' >> /etc/pam.d/common-auth
#echo 'auth required pam_unix.so' >> /etc/pam.d/common-auth
sed -i 's/nullok//g' /etc/pam.d/common-auth
cp /etc/pam.d/common-password /etc/pam.d/common-password.bak
sed -i 's/\(pam_unix\.so.*\)$/\1 remember=5 minlen=8/' /etc/pam.d/common-password
sed -i 's/\(pam_cracklib\.so.*\)$/\1 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1/' /etc/pam.d/common-password

# Setting up auditing
echo "Setting up auditing..." >> /linux_script.log
echo "Setting up auditing..."
auditctl -e 1

# Finding & Removing Files
echo "Finding & saving media files to \`/media_files.txt\`..." >> /linux_script.log
echo "Finding & saving media files to \`/media_files.txt\`..."
find /home/ -type f \( -name "*.mp3" -o -name "*.mp4" -o -name "*.wav" -o -name "*.avi" -o -name "*.mkv" -o -name "*.flac" -o -name "*.mov" \) -print > /media_files.txt
echo "Finding & saving possible hacking tools as packages to \`/packages.txt\`..." >> /linux_script.log
echo "Finding & saving possible hacking tools as packages to \`/packages.txt\`..."
find /home/ -type f \( -name "*.tar.gz" -o -name "*.tgz" -o -name "*.zip" -o -name "*.deb" \) -print > /packages.txt
echo "Finding & saving World Writable files to \`/world_writable.txt\`..." >> /linux_script.log
echo "Finding & saving World Writable files to \`/world_writable.txt\`..."
find /dir -xdev -type d \( -perm -0002 -a ! -perm -1000 \) -print > /world_writable.txt
echo "Finding & saving No-User files to \`/no_user.txt\`..." >> /linux_script.log
echo "Finding & saving No-User files to \`/no_user.txt\`..."
find /dir -xdev \( -nouser -o -nogroup \) -print > /no_user.txt

echo "Removing media files..." >> /linux_script.log
echo "Removing media files..."
echo "The following files will be removed:" >> /linux_script.log
echo "The following files will be removed:"
cat /media_files.txt
# Prompt the user for confirmation
read -p "Do you want to proceed with the deletion? (Y/n): " choice
if [[ $choice == n* || $choice == N* ]]; then
    echo "No files were removed." >> /linux_script.log
    echo "No files were removed."
else
    # Proceed with removal
    while IFS= read -r file; do
        rm -rf "$file"
    done < /media_files.txt

    echo "Files have been removed." >> /linux_script.log
    echo "Files have been removed."
fi

echo "Removing packages..." >> /linux_script.log
echo "Removing packages..."
echo "The following files will be removed:" >> /linux_script.log
echo "The following files will be removed:"
cat /packages.txt
# Prompt the user for confirmation
read -p "Do you want to proceed with the deletion? (Y/n): " choice
if [[ $choice == n* || $choice == N* ]]; then
    echo "No files were removed." >> /linux_script.log
    echo "No files were removed."
else
    # Proceed with removal
    while IFS= read -r file; do
        rm -rf "$file"
    done < /packages.txt
    echo "Files have been removed." >> /linux_script.log
    echo "Files have been removed."
fi

echo "Please manually check the world-writable files and the no-user files." >> /linux_script.log
echo "Please manually check the world-writable files and the no-user files."

# Preventing IP Spoofing
echo "Preventing IP Spoofing in /etc/host.conf..." >> /linux_script.log
echo "Preventing IP Spoofing in /etc/host.conf..."
echo "failed: no code for preventing IP spoofing written..." >> /linux_script.log
echo "failed: no code for preventing IP spoofing written..."

# User Management
mawk -F: '$1 == "sudo"' /etc/group > /admins.txt
echo "Admins (saved to \`/admins.txt\`):" >> /linux_script.log
echo "Admins (saved to \`/admins.txt\`):"
mawk -F: '$3 > 999 && $3 < 65534 {print $1}' /etc/passwd > /users.txt
echo "Users (saved to \`/users.txt\`):" >> /linux_script.log
echo "Users (saved to \`/users.txt\`):"
mawk -F: '$2 == ""' /etc/passwd > /no_passwd.txt
echo "Empty Passwords (saved to \`/no_passwd.txt\`):" >> /linux_script.log
echo "Empty Passwords (saved to \`/no_passwd.txt\`):"
mawk -F: '$3 == 0 && $1 != "root"' /etc/passwd > /non-root_uid0.txt
echo "Non-root UID 0 users (saved to \`/non-root_uid0.txt\`):" >> /linux_script.log
echo "Non-root UID 0 users (saved to \`/non-root_uid0.txt\`):"
# Reading files for authorized users and admins
echo "Reading users.txt, admins.txt, addusers.txt, and addgroups.txt..." >> /linux_script.log
echo "Reading users.txt, admins.txt, addusers.txt, and addgroups.txt..."
#TODO

# Changing Passwords
NEW_PASSWORD="CyberPatr!0t"
echo "Changing Passwords of all users, admins, and root to \`$NEW_PASSWORD\`..." >> /linux_script.log
echo "Changing Passwords of all users, admins, and root to \`$NEW_PASSWORD\`..."

for user in $(cut -f1 -d: /etc/passwd); do
    if [[ "$user" != "root" && "$user" != "nobody" && "$user" != "daemon" && "$user" != "systemd-timesync" ]]; then
        if id -nG "$user" | grep -qw 'sudo'; then
            ROLE="admin"
        else
            ROLE="user"
        fi
        echo "$user:$NEW_PASSWORD" | chpasswd
        echo "Password for $ROLE $user changed."
    fi
done
echo "root:$NEW_PASSWORD" | chpasswd
echo "Password for admin root changed."

# Finding vulnerabilities
echo "Finding vulnerabilities..." >> /linux_script.log
echo "Finding vulnerabilities..."
echo "Running \`chkrootkit\`..." >> /linux_script.log
echo "Running \`chkrootkit\`..."
chkrootkit
echo "Running \`rkhunter --update\`..." >> /linux_script.log
echo "Running \`rkhunter --update\`..."
rkhunter --update
echo "Running \`rkhunter --check\`..." >> /linux_script.log
echo "Running \`rkhunter --check\`..."
rkhunter --check
echo "Running \`freshclam\`..." >> /linux_script.log
echo "Running \`freshclam\`..."
freshclam
echo "Running \`clamscan -r --bell -i\`..." >> /linux_script.log
echo "Running \`clamscan -r --bell -i\`..."
clamscan -r --bell -i /

# Final Notes
echo "Final Notes:" >> /linux_script.log
echo "Final Notes:"
echo >> /linux_script.log
echo
echo "Please manually check the world-writable files and the no-user files." >> /linux_script.log
echo "Please manually check the world-writable files and the no-user files."
echo;
echo "Launching settings..." >> /linux_script.log
echo "Launching settings..."
if [[ "$DESKTOP_SESSION" == "gnome" ]]; then
    gnome-control-center > /dev/null 2>&1 &
elif [[ "$DESKTOP_SESSION" == "cinnamon" ]]; then
    cinnamon-settings > /dev/null 2>&1 &
elif [[ "$DESKTOP_SESSION" == "xfce" ]]; then
    xfce4-settings-manager > /dev/null 2>&1 &
elif [[ "$DESKTOP_SESSION" == "kde" ]]; then
    systemsettings5 > /dev/null 2>&1 &
fi

# Print Finished in Log
echo "Finished! in _s..." >> /linux_script.log # TODO: calculate time

# Wishing Goodluck
echo;echo;echo
echo "Thank you for using this script. Good luck for the competition!"
echo;
echo "==================================="
echo "Copyright (c) 2024 Tanav Malhotra"
echo "GPL3 License"
echo "==================================="
