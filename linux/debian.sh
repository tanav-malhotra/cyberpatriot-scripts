#!/bin/bash
# ====================================================================================
# Author: Tanav Malhotra
# License: GNU General Public License v3.0
# Copyright (c) 2024 Tanav Malhotra
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
# You can also view the license by running the `debian.sh` script
# with the '--license' option.
# ====================================================================================

##### IMPORTANT VARS #####
unalias -a
version="v1.5.2"
start_time=$(date +"%Y-%m-%d, %I:%M:%S %p")
start_secs=$(date +%s.%N)
LOGFILE="./linux_script.log"
output_file="./linux_script_output.txt"
starting_dir=$(pwd)
distro_id=$(grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
distro_codename=$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
debug=0
help=0
license=0
version_arg=0

##### FUNCTIONS #####
banner() {
    cat << 'EOF'
 _____  _    _   _    ___     __
|_   _|/ \  | \ | |  / \ \   / /
  | | / _ \ |  \| | / _ \ \ / / 
  | |/ ___ \| |\  |/ ___ \ V /  
  |_/_/   \_\_| \_/_/   \_\_/   
 __  __    _    _     _   _  ___ _____ ____      _    
|  \/  |  / \  | |   | | | |/ _ \_   _|  _ \    / \   
| |\/| | / _ \ | |   | |_| | | | || | | |_) |  / _ \  
| |  | |/ ___ \| |___|  _  | |_| || | |  _ <  / ___ \ 
|_|  |_/_/   \_\_____|_| |_|\___/ |_| |_| \_\/_/   \_\
EOF
    echo
}
log() {
    echo $@ >> "$LOGFILE"
    echo $@
}
log_info() { # does not print out to terminal
    echo $@ >> "$LOGFILE"
    if [[ $debug -eq 1 ]]; then
        echo $@ >> "$output_file"
    fi
}
ring_bell() {
    # for i in {1..10}; do
    #     echo -e "\a"
    #     sleep 0.1                                                    
    # done &
    echo -e "\a" &
}

##### CHECK FOR SUDO #####
log_info "Checking for \`sudo\` access..."
if [[ $EUID -ne 0 ]]; then
    log "\`sudo\` access is required. Please run \`sudo !!\`"
    exit 1
fi

##### MANAGE ARGS #####
if [ $# -gt 0 ]; then
    for arg in "$@"; do
        case "$arg" in
            --help)
                help=1
            ;;
            --version)
                version_arg=1
            ;;
            --license)
                license=1
            ;;
            --debug)
                debug=1
            ;;
            *)
            echo "Unknown option: $arg"
            exit 1
            ;;
        esac
    done
fi
if [[ $help -eq 1 ]]; then
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "    --debug      Enable debug mode"
    echo "    --help       Display this help message"
    echo "    --license    Show license information"
    echo "    --version    Show version information"
    echo ""
    echo "Description: A sophisticated script for Debian-based Linux systems, designed for CyberPatriot competitions."
    exit 0
elif [[ $version_arg -eq 1 ]]; then
    echo "$0 $version"
    exit 0
elif [[ $license -eq 1 ]]; then
    curl https://www.gnu.org/licenses/gpl-3.0.txt | less
    exit 0
elif [[ $debug -eq 1 ]]; then
    touch "$LOGFILE"
    touch $output_file
    # Redirect both stdout and stderr to tee
    exec > >(tee -a "$output_file") 2>&1
    
    # Display debug information
    log "Debug mode enabled."
    log
    log "Info:"
    log "Current Directory: $starting_dir"
    log "Start: $start_time"
    log "Distro ID: $distro_id"
    log "Distro Codename: $distro_codename"
    if [[ -x "$(command -v systemctl)" ]]; then
        log "Systemd detected..."
    fi
    sleep 5
else
    touch "$LOGFILE"
    log_info "Start time: $start_time" # log start time
fi

##### START SCRIPT #####
clear
banner
log "Created by Tanav Malhotra, Thomas A. Edison Career & Technical Education High School, New York City, NY, USA"
sleep 3
log "CyberPatriot Linux Script $version"
sleep 1
log "Starting..."
log;log;
sleep 1

##### MAKE SURE USER IS READY TO RUN SCRIPT #####
ring_bell
read -p "Do you want to make all of the bash scripts in this directory executable? (Y/n): " $confirmation
if [[ $confirmation =~ ^[Nn].* ]]; then
    log "Make sure you manually run \`sudo chmod +x\` on any script you want to run."
else
    chmod +x *.sh
fi
ring_bell
read -p "Have all of the Forensics Questions been answered? (Y/n): " $confirmation
if [[ $confirmation =~ ^[Nn].* ]]; then
    log "error: Please complete these first and only then rerun the script."
    exit 1
fi
ring_bell
read -p "Have you created the required users.txt & admins.txt files in the current directory? (Y/n): " $confirmation
if [[ $confirmation =~ ^[Nn].* ]]; then
    log "error: Please create these files first by using the information from the README file located on your desktop."
    exit 1
fi

##### UPDATE #####
log "Updating system..."
apt purge -y snapd
apt update -y && apt full-upgrade -y
apt autoremove -y --purge

##### LANGUAGE #####
#TODO: fix this
LANG_TO_KEEP="en_US.UTF-8"
LOCALE_TO_KEEP="en"
log "Setting language to $LANG_TO_KEEP and locale to $LOCALE_TO_KEEP..."
update-locale LANG=$LANG_TO_KEEP LANGUAGE=$LOCALE_TO_KEEP LC_MESSAGES="POSIX"
ring_bell
locale-gen --purge $LANG_TO_KEEP # languages you WANT to keep
dpkg-reconfigure locales

##### SOFTWARE MANAGEMENT #####
apt list --installed > ./software_that_was_installed.txt
log "Installing software..."
apps=("openssh-server" "fail2ban" "bum" "mawk" "chkrootkit" "rkhunter" "auditd" "vim" "neovim" "iptables" "ufw" "lightdm" "x2goserver" "deborphan" "libpam-cracklib" "debsums" "software-properties-gtk" "apt-listbugs" "apt-listchanges" "libpam-tmpdin" "libpam-usb" "libpam-pwquality" "apparmor" "rsyslog" "rsyslog" "USBGaurdd" "usb-storage" "net-tools" "lynis")
for app in "${apps[@]}"; do
    log "Installing $app..."
    apt-get install -y "$app"
done
log "Removing prohibited software and hacking tools (and making sure \`snapd\` was removed)..."
apps=("wireshark" "telnet" "vsftpd" "proftpd" "snmpd" "mysql-server" "mysql-client" "postgresql" "xrdp" "tightvncserver" "samba" "nmap" "php" "apache2*" "*nginx*" "lighttpd" "tcpdump" "netcat-traditional" "nikto" "ophcrack" "ettercap*" "deluge" "dovecot-core" "*netcat*" "john" "vuze" "frostwire" "aircrack-ng" "metasploit-framework" "nessus" "snort" "kismet" "yersinia" "burp-suite" "burpsuite" "hydra" "oclhashcat" "hashcat" "maltego" "zaproxy" "cain" "*angryip*" "ipscan" "medusa" "xinetd" "openbsd-inetd" "inetutils-inetd" "avahi-daemon" "tcpd" "snapd")
for app in "${apps[@]}"; do
    log "Removing $app..."
    apt-get purge -y "$app"
done
hacking_tools=("john" "nmap" "vuze" "frostwire" "kismet" "freeciv" "minetest" "minetest-server" "medusa" "hydra" "truecrack" "ophcrack" "nikto" "cryptcat" "nc" "netcat" "tightvncserver" "x11vnc" "nfs" "xinetd" "samba" "postgresql" "sftpd" "vsftpd" "apache" "apache2" "ftp" "mysql" "php" "snmp" "pop3" "icmp" "sendmail" "dovecot" "bind9" "nginx" "telnet" "rlogind" "rshd" "rcmd" "rexecd" "rbootd" "rquotad" "rstatd" "rusersd" "rwalld" "rexd" "fingerd" "tftpd")
for tool in "${hacking_tools[@]}"; do
    log "Removing $tool..."
    apt-get purge -y "$tool"
done
log "Removing games..."
games=("gnome-games" "iagno" "lightsoff" "four-in-a-row" "gnome-robots" "pegsolitaire" "gnome-2048" "hitori" "gnome-klotski" "gnome-mines" "gnome-mahjongg" "gnome-sudoku" "quadrapassel" "swell-foop" "gnome-tetravex" "gnome-taquin" "aisleriot" "gnome-chess" "five-or-more" "gnome-nibbles" "tali" "freeciv" "wesnoth")
# games=$(dpkg -l | grep "game" | awk '{print $2}') # find "game" in package descriptions
for game in "${games[@]}"; do
    log "Removing $game..."
    apt-get purge -y "$game"
done
dpkg --configure -a
apt --fix-broken install
apt autoremove -y --purge

##### CHECK FOR UPDATES DAILY #####
log "Checking for updates daily..."
touch /etc/apt/apt.conf.d/10periodic
touch /etc/apt/apt.conf.d/10removal
touch /etc/apt/apt.conf.d/20auto-upgrades
touch /etc/apt/apt.conf.d/50unattended-upgrades
cp /etc/apt/apt.conf.d/10periodic /etc/apt/apt.conf.d/10periodic.bak
cp /etc/apt/apt.conf.d/10removal /etc/apt/apt.conf.d/10removal.bak
cp /etc/apt/apt.conf.d/20auto-upgrades /etc/apt/apt.conf.d/20auto-upgrades.bak
cp /etc/apt/apt.conf.d/50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades.bak
dpkg-reconfigure unattended-upgrades
echo "APT::Periodic::AutocleanInterval "7";" >> /etc/apt/apt.conf.d/10periodic
echo "APT::Get::Remove-Unused "true";" >> /etc/apt/apt.conf.d/10removal
cat <<EOL > "/etc/apt/apt.conf.d/20auto-upgrades"
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOL
cat <<EOL > "/etc/apt/apt.conf.d/50unattended-upgrades"
Unattended-Upgrade::Allowed-Origins {
	"${distro_id} stable";
	"${distro_id} ${distro_codename}-security";
	"${distro_id} ${distro_codename}-updates";
};
EOL
# Unattended-Upgrade::Package-Blacklist {
# 	"libproxy1v5";		# because school blocks the word "proxy"
# };
# EOL

##### FIREWALL #####
log "Setting up firewall..."
ufw enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw logging on
ufw logging high

##### SSH #####
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
set_sshd_setting "UsePAM" "yes"
set_sshd_setting "HostbasedAuthentication" "no"
set_sshd_setting "Protocol" "2"
set_sshd_setting "LogLevel" "VERBOSE"
set_sshd_setting "X11Forwarding" "no"
set_sshd_setting "MaxAuthTries" "4"
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
ring_bell
read -p "Do you want to change the SSH port? (y/N): " change_port
if [[ $change_port =~ ^[Yy].* ]]; then
    while true; do
        ring_bell
        read -p "Enter the new SSH port (1-65535): " new_port
        
        # Validate the input
        if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ]; then
            break
        else
            log "Invalid port number. Please enter a number between 1 and 65535."
        fi
    done

    # Update the SSHD configuration with the new port
    # sed -i "s/^Port .*/Port $new_port/" $sshd_config
    set_sshd_setting "Port" "$new_port"
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
        systemctl enable sshd
        systemctl start sshd
        systemctl restart sshd
    elif [[ -x "$(command -v service)" ]]; then
        update-rc.d sshd defaults
        service sshd start
        service sshd restart
    else
        log "error: Unable to restart sshd service."
    fi
else
    log "error: SSH configuration has errors. Please fix them before restarting."
fi
log "Creating new SSH keys..."
# Define variables
KEY_NAME="id_ed25519"
KEY_DIR="/home/$USER/.ssh"
AUTHORIZED_KEYS="$KEY_DIR/authorized_keys"
# Check if the .ssh directory exists; if not, create it
if [ ! -d "$KEY_DIR" ]; then
    mkdir -p "$KEY_DIR"
    chmod 700 "$KEY_DIR"
fi
ssh-keygen -t ed25519 -f "$KEY_DIR/$KEY_NAME" -N ""
# Check if the key was created successfully
if [ $? -eq 0 ]; then
    log "Ed25519 SSH key generated successfully."
else
    log "error: Failed to generate SSH key."
fi
# Append the public key to authorized_keys
cat "$KEY_DIR/$KEY_NAME.pub" >> "$AUTHORIZED_KEYS"
# Set the correct permissions for the authorized_keys file
chmod 600 "$AUTHORIZED_KEYS"
log "Public key added to $AUTHORIZED_KEYS."

##### IP BANNING (FAIL2BAN) #####
log "Ban IPs with too many incorrect login attempts..."
if [[ -x "$(command -v systemctl)" ]]; then
    systemctl enable fail2ban
    systemctl start fail2ban
    systemctl restart fail2ban
elif [[ -x "$(command -v service)" ]]; then
    update-rc.d fail2ban defaults
    service fail2ban start
    service fail2ban restart
else
    log "error: Unable to restart fail2ban service."
fi

##### INTERFACE SETTINGS (e.g. USB) #####
log "Setting USB settings..."
if [[ -x "$(command -v systemctl)" ]]; then
    systemctl stop autofs
    systemctl disable autofs
    systemctl mask autofs
elif [[ -x "$(command -v service)" ]]; then
    service autofs stop
    update-rc.d autofs remove
else
    log "error: Unable to restart autofs service."
fi
if [[ -x "$(command -v systemctl)" ]]; then
    systemctl enable USBGaurdd
    systemctl start USBGaurdd
    systemctl restart USBGaurdd
elif [[ -x "$(command -v service)" ]]; then
    update-rc.d USBGaurdd defaults
    service USBGaurdd start
    service USBGaurdd restart
else
    log "error: Unable to restart USBGaurdd service."
fi
#log "Disabling USB..."
#echo 'install usb-storage /bin/true' >> /etc/modprobe.d/disable-usb-storage.conf
#log "Disabling FireWire..."
#echo "blacklist firewire-core" >> /etc/modprobe.d/firewire.conf
#log "Disabling Thunderbolt..."
#echo "blacklist thunderbolt" >> /etc/modprobe.d/thunderbolt.conf

##### REMOVING BASH ALIASES #####
log "Removing all bash aliases..."
find / -type f -name "*bashrc" 2>/dev/null | while read -r bashrc_file; do
    if [ -f "$bashrc_file" ]; then
        cp "$bashrc_file" "$bashrc_file.bak"
        sed -i '/alias /d' "$bashrc_file"
        if ! diff "$bashrc_file" "$bashrc_file.bak" >/dev/null; then
            log "Aliases removed from $bashrc_file."
        else
            log "No aliases found in $bashrc_file."
        fi
    fi
done

##### FILE/DIR PERMS/OWNERSHIP #####
log "Setting home directory permissions..."
for i in $(mawk -F: '$3 > 999 && $3 < 65534 {print $1}' /etc/passwd); do [ -d /home/${i} ] && chmod -R 750 /home/${i}; done
find /home -type d -name '.ssh' -exec chmod 700 {} \;
log "Changing permissions (and owners) of commonly exploited files..."
# chown root:root /etc/securetty
# chown root:root /etc/shadow
# chmod 0600 /etc/securetty
# chmod 600 /etc/shadow
# chmod 0440 /etc/sudoers
# chmod 644 /etc/crontab
# chmod 640 /etc/ftpusers
# chmod 440 /etc/inetd.conf
# chmod 440 /etc/xinetd.conf
# chmod 400 /etc/inetd.d
# chmod 644 /etc/hosts.allow
# chown root:root /
# chmod 755 /
# chown root:root /bin
# chmod 755 /bin
# chown root:root /boot
# chmod 755 /boot
# chown root:root /etc
# chmod 755 /etc
# chown root:root /lib
# chmod 755 /lib
# chown root:root /lib64
# chmod 755 /lib64
# chown root:root /opt
# chmod 755 /opt
# chown root:root /sbin
# chmod 755 /sbin
# chown root:root /usr
# chmod 755 /usr
# chown root:root /var
# chmod 755 /var
# chown root:root /etc/passwd
# chmod 644 /etc/passwd
# chown root:shadow /etc/shadow
# chmod 600 /etc/shadow
# chown root:root /etc/group
# chmod 644 /etc/group
# chown root:shadow /etc/gshadow
# chmod 600 /etc/gshadow
# chown root:root /etc/hosts
# chmod 644 /etc/hosts
# chown root:root /etc/ssh/ssh_host_*_key
# chmod 600 /etc/ssh/ssh_host_*_key
# chown root:root /etc/ssh/ssh_host_*_key.pub
# chmod 644 /etc/ssh/ssh_host_*_key.pub
# chown root:root /root
# chmod 700 /root
# chown root:root /tmp
# chmod 1777 /tmp
#
#
# Files related to authentication and configuration
chown root:root /etc/securetty
chown root:shadow /etc/shadow
chmod 0600 /etc/securetty
chmod 600 /etc/shadow
chmod 0440 /etc/sudoers
chmod 644 /etc/crontab
chmod 640 /etc/ftpusers
chmod 440 /etc/inetd.conf
chmod 440 /etc/xinetd.conf
chmod 400 /etc/inetd.d
chmod 644 /etc/hosts.allow
# Root and important system directories
chown root:root /
chmod 755 /
chown root:root /bin
chmod 755 /bin
chown root:root /boot
chmod 755 /boot
chown root:root /etc
chmod 755 /etc
chown root:root /lib
chmod 755 /lib
chown root:root /lib64
chmod 755 /lib64
chown root:root /opt
chmod 755 /opt
chown root:root /sbin
chmod 755 /sbin
chown root:root /usr
chmod 755 /usr
chown root:root /var
chmod 755 /var
# Password and shadow files
chown root:root /etc/passwd
chmod 644 /etc/passwd
chown root:shadow /etc/shadow
chmod 600 /etc/shadow
chown root:root /etc/group
chmod 644 /etc/group
chown root:shadow /etc/gshadow
chmod 600 /etc/gshadow
# SSH keys and directories
chown root:root /etc/ssh/ssh_host_*_key
chmod 600 /etc/ssh/ssh_host_*_key
chown root:root /etc/ssh/ssh_host_*_key.pub
chmod 644 /etc/ssh/ssh_host_*_key.pub
# Root user and sensitive directories
chown root:root /root
chmod 700 /root
chown root:root /tmp
chmod 1777 /tmp

##### CRON SETTINGS #####
log "Changing cron settings..."
cp /etc/rc.local /etc/rc.local.bak
cp /etc/cron.deny /etc/cron.deny.bak
echo "exit 0" > /etc/rc.local
echo "ALL" >> /etc/cron.deny

##### KERNEL HARDENING AND IP SETTINGS #####
log "Enabling syn cookie protection..."
sysctl -n net.ipv4.tcp_syncookies
log "Disabling IP Forwarding..."
cp /proc/sys/net/ipv4/ip_forward /proc/sys/net/ipv4/ip_forward.bak
echo 0 | tee /proc/sys/net/ipv4/ip_forward
log "Preventing IP Spoofing..."
iptables -A INPUT -s 10.0.0.0/8 -i eth0 -j DROP
iptables -A INPUT -s 172.16.0.0/12 -i eth0 -j DROP
iptables -A INPUT -s 192.168.0.0/16 -i eth0 -j DROP
iptables -A INPUT -i eth0 -m limit --limit 2/min -j LOG --log-prefix "Dropped Packet: "
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m state --state NEW -j DROP
log "Kernel Hardening..."
cp /etc/sysctl.conf /etc/sysctl.conf.bak
cat <<EOL > "/etc/sysctl.conf"
fs.file-max = 65535
fs.protected_fifos = 2
fs.protected_regular = 2
fs.suid_dumpable = 0
kernel.core_uses_pid = 1
kernel.dmesg_restrict = 1
kernel.exec-shield = 1
kernel.sysrq = 0
kernel.randomize_va_space = 2
kernel.pid_max = 65536
net.core.rmem_max = 8388608
net.core.wmem_max = 8388608
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_rmem = 10240 87380 12582912
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_wmem = 10240 87380 12582912
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.all.redirects = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.default.log_martians = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.icmp_echo_ignore_all = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.ip_forward = 0
net.ipv4.ip_local_port_range = 2000 65000
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 5
net.ipv4.tcp_timestamps = 9
# Disable IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
# Incase IPv6 is necessary
net.ipv6.conf.all.rp_filter = 1
net.ipv6.conf.default.router_solicitations = 0
net.ipv6.conf.default.accept_ra_rtr_pref = 0
net.ipv6.conf.default.accept_ra_pinfo = 0
net.ipv6.conf.default.accept_ra_defrtr = 0
net.ipv6.conf.default.autoconf = 0
net.ipv6.conf.default.dad_transmits = 0
net.ipv6.conf.default.max_addresses = 1
net.ipv6.conf.default.rp_filter = 1
EOL
sysctl -p

##### AUDITING #####
log "Setting up auditing..."
cat <<EOL > "/etc/audit/audit.rules"
-D
-w / -p rwax -k filesystem_change
-a always,exit -S all
-e 2
EOL
cat <<EOL > "/etc/audit/auditd.conf"
max_log_file = 10485760
space_left_action = email
action_mail_acct = root
admin_space_left_action = halt
max_log_file_action = keep_logs
EOL
auditctl -e 1
if [[ -x "$(command -v systemctl)" ]]; then
    systemctl enable auditd
    systemctl start auditd
    systemctl restart auditd
elif [[ -x "$(command -v service)" ]]; then
    update-rc.d auditd defaults
    service auditd start
    service auditd restart
else
    log "error: Unable to restart auditd service."
fi
df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -type f -perm -0002 # Auditing world writable files
df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -nouser # Auditing unowned files/directories
df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -nogroup # Auditing ungrouped files/directories
df --local -P | awk {'if (NR!=1)print $6'} | xargs -I '{}' find '{}' -xdev -type f -perm -4000 # Audit SUID executable
df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -type f -perm -2000 # Audit SGID executables
# Setting up rsyslog
log "Setting up rsyslog..."
if [[ -x "$(command -v systemctl)" ]]; then
    systemctl enable rsyslog
    systemctl start rsyslog
    systemctl restart rsyslog
elif [[ -x "$(command -v service)" ]]; then
    update-rc.d rsyslog defaults
    service rsyslog start
    service rsyslog restart
else
    log "error: Unable to restart rsyslog service."
fi

##### APPARMOR #####
log "Setting up AppArmor..."
aa-enforce /etc/apparmor.d/*
if [[ -x "$(command -v systemctl)" ]]; then
    systemctl enable apparmor
    systemctl start apparmor
    systemctl restart apparmor
elif [[ -x "$(command -v service)" ]]; then
    update-rc.d apparmor defaults
    service apparmor start
    service apparmor restart
else
    log "error: Unable to restart apparmor service."
fi

##### FINDING & SAVING INFO #####
log "Finding and saving open ports to \`./open_ports.txt\`..."
ss -ln > ./open_ports.txt
log "Finding and saving running services to \`./services.txt\`..."
service --status-all > ./services.txt
log "Finding & saving unused software to \`./unused_software.txt\`..."
deborphan --guess-all > ./unused_software.txt
# log "Removing unused software..."
# log "The following files will be removed:"
# cat ./unused_software.txt
# # Prompt the user for confirmation
# ring_bell
# read -p "Do you want to proceed with the deletion? (Y/n): " choice
# if [[ $choice =~ ^[Nn].* ]]; then
#     log "No software was removed."
# else
#     # Proceed with removal
#     while IFS= read -r file; do
#         rm -rf "$file"
#     done < ./unused_software.txt

#     log "Unused software has been removed."
# fi
log "Finding & saving installed software to \`./software_installed.txt\`..."
apt list --installed > ./software_installed.txt
log "Finding & saving enabled services to \`./enabled_services.txt\`..."
service --status-all > ./enabled_services.txt
log "Finding & saving media files to \`./media_files.txt\`..."
find /home/ -type f \( -name "*.mp3" -o -name "*.mp4" -o -name "*.wav" -o -name "*.avi" -o -name "*.mkv" -o -name "*.flac" -o -name "*.mov" \) -print > ./media_files.txt
log "Finding & saving possible hacking tools as packages to \`./packages.txt\`..."
find /home/ -type f \( -name "*.tar.gz" -o -name "*.tgz" -o -name "*.zip" -o -name "*.deb" \) -print > ./packages.txt
log "Finding & saving World Writable files to \`./world_writable.txt\`..."
find /dir -xdev -type d \( -perm -0002 -a ! -perm -1000 \) -print > ./world_writable.txt
log "Finding & saving No-User files to \`./no_user.txt\`..."
find /dir -xdev \( -nouser -o -nogroup \) -print > ./no_user.txt

##### REMOVING MEDIA FILES #####
log "Removing media files..."
log "The following files will be removed:"
cat ./media_files.txt
ring_bell
read -p "Do you want to proceed with the deletion? (Y/n): " choice
if [[ $choice =~ ^[Nn].* ]]; then
    log "No files were removed."
else
    while IFS= read -r file; do
        rm -rf "$file"
    done < ./media_files.txt

    log "Files have been removed."
fi
log "Removing packages..."
log "The following files will be removed:"
cat ./packages.txt
ring_bell
read -p "Do you want to proceed with the deletion? (Y/n): " choice
if [[ $choice =~ ^[Nn].* ]]; then
    log "No files were removed."
else
    while IFS= read -r file; do
        rm -rf "$file"
    done < ./packages.txt
    log "Files have been removed."
fi

##### USER MANAGEMENT #####
log "User Management..."
# Lock Root
log "Locking root account..."
passwd -l root
usermod -s /bin/false root
usermod -L root
usermod -g 0 root
# log "Setting default shell for users..."
# chsh -s /bin/bash
cp /etc/sudoers /etc/sudoers.bak
cp -r /etc/sudoers.d /etc/sudoers.d.bak
cp /etc/passwd /etc/passwd.bak
touch /etc/lightdm/lightdm.conf
touch /etc/gdm/custom.conf
touch /etc/pam.d/gdm-password
cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.bak
cp /etc/lightdm/users.conf /etc/lightdm/users.conf.bak
cp /etc/gdm/custom.conf /etc/gdm/custom.conf.bak
cp /etc/pam.d/gdm-password /etc/pam.d/gdm-password.bak
sed -i '/NOPASSWD:/s/\(NOPASSWD:.*\)/NOPASSWD:/g' /etc/sudoers
sed -i 's/nopasswd//g' /etc/sudoers
sed -i 's/!authenticate//g' /etc/sudoers
sed -i 's/nopasswd//g' /etc/sudoers.d
sed -i 's/!authenticate//g' /etc/sudoers.d
log "Running \`visudo -c\`..."
visudo -c
if [ $? -eq 0 ]; then
    log "Sudoers files validated successfully. No syntax errors found."
else
    log "error: Syntax errors detected in sudoers files, namely \`/etc/sudoers\`! It is CRITICAL to fix these errors to prevent losing \`sudo\` access."
    log "Press 'Enter' to continue..."
    read
    visudo
fi
log "Turning off guest login..."
groupdel autologin
sed -i 's/allow-guest=true/allow-guest=false/' /etc/lightdm/lightdm.conf
echo "allow-guest=false" >> /etc/lightdm/users.conf
cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf_with_autologin.bak
sed -i '/^autologin-user/s/^/#/' /etc/lightdm/lightdm.conf
sed -i 's/AutomaticLoginEnable=True/AutomaticLoginEnable=False/' /etc/gdm/custom.conf
sed -i 's/auth sufficient pam_succeed_if.so user ingroup nopasswdlogin//' /etc/pam.d/gdm-password
mawk -F: '$1 == "sudo"' /etc/group > ./admins.txt
log "Admins (saved to \`./admins.txt\`)..."
mawk -F: '$3 > 999 && $3 < 65534 {print $1}' /etc/passwd > ./users.txt
log "Users (saved to \`./users.txt\`)..."
mawk -F: '$2 == ""' /etc/passwd > ./no_passwd.txt
log "Empty Passwords (saved to \`./no_passwd.txt\`)..."
mawk -F: '$3 == 0 && $1 != "root"' /etc/passwd > ./non-root_uid0.txt
log "Non-root UID 0 users (saved to \`./non-root_uid0.txt\`)..."
# Changing Passwords and user management
NEW_PASSWORD="CyberPatr!0t"
existing_users=$(cut -d: -f1 /etc/passwd | grep -Ev "^(root|nobody|nfsnobody)$")
declare -A admin_map
declare -A user_map
for admin in "${ADMINS[@]}"; do
    admin_map["$admin"]=1
done
for user in "${USERS[@]}"; do
    user_map["$user"]=1
done
ALL_USERS=$(printf "%s\n" "${USERS[@]}" "${ADMINS[@]}")
log "Changing Passwords of all users and admins to \`$NEW_PASSWORD\` (and making sure they belong on system and have the right permissions)..."
# Add any missing users from users.txt
for u in "${USERS[@]}"; do
    if ! grep -qw "$u" <<<"$existing_users"; then # TODO: try method used in line 827 & 829
        useradd "$u"
        log "User $u added to the system as user."
    fi
done
# Add any missing admins from admins.txt
for a in "${ADMINS[@]}"; do
    if ! grep -qw "$a" <<<"$existing_users"; then # TODO: try method used in line 827 & 829
        useradd "$a"
        log "User $a added to the system as admin."
    fi
done
cut -d: -f1,3 /etc/passwd | while IFS=: read user uid; do
    # UID (User ID) >= 1000 for human users
    if [[ "$uid" -ge 1000 && "$user" != "nobody" && "$user" != "nfsnobody" && "$user" != "root" ]]; then
        # if id -nG "$user" | grep -qwE 'sudo|wheel|admin'; then
        #     current_role="Admin"
        # else
        #     current_role="User"
        # fi
        # # Determine the intended role based on the files
        # if [[ -n "${admin_map[$user]}" ]]; then
        #     ROLE="admin"
        # elif [[ -n "${user_map[$user]}" ]]; then
        #     ROLE="user"
        # else
        #     userdel -r "$user"
        #     log "$current_role $user and their data have been removed from the system."
        #     continue
        # fi

        if id -nG "$user" | grep -qwE 'sudo|wheel|admin'; then
            ROLE="admin"
        else
            ROLE="user"
        fi

        echo "$user:$NEW_PASSWORD" | chpasswd
        log "Password for $ROLE $user changed."

        # Make sure they belong on the system
        if [[ "$ROLE" == "user" ]]; then
            # Ensure user is not in admin groups
            gpasswd -d "$user" sudo &>/dev/null
            gpasswd -d "$user" admin &>/dev/null # older ubuntu versions
            gpasswd -d "$user" wheel &>/dev/null
        elif [[ "$ROLE" == "admin" ]]; then
            # Ensure user is in admin groups
            gpasswd -a "$user" sudo &>/dev/null
            gpasswd -a "$user" admin &>/dev/null # older ubuntu versions
            gpasswd -a "$user" wheel &>/dev/null
        fi
    fi
done
echo "root:$NEW_PASSWORD" | chpasswd
log "Password for admin root changed."

##### CHANGING POLICIES #####
# Setting max password days
log "Setting max password days..."
cp /etc/login.defs /etc/login.defs.bak
sed -i 's/PASS_MAX_DAYS.*$/PASS_MAX_DAYS 30/;s/PASS_MIN_DAYS.*$/PASS_MIN_DAYS 10/;s/PASS_WARN_AGE.*$/PASS_WARN_AGE 7/' /etc/login.defs
# Change PAM (Pluggable Authentication Modules) settings
log "Changing PAM settings (setting max password attempts, minimum password langths, etc.)..."
cp /etc/pam.d/common-auth /etc/pam.d/common-auth.bak
sed -i 's/\w*nullok\w*//g' /etc/pam.d/common-auth
# Lockout Policy
#sed -i 's/\(pam_tally2\.so.*\)$/\1 deny=5 audit silent unlock_time=1/' /etc/pam.d/common-auth
#echo 'auth required pam_tally2.so deny=5 onerr=fail unlock_time=1' >> /etc/pam.d/common-auth
#echo 'auth required pam_unix.so' >> /etc/pam.d/common-auth
echo "auth required pam_faillock.so preauth deny=5 unlock_time=1" >> /etc/pam.d/common-auth
echo "auth required pam_faillock.so authfail deny=5 unlock_time=1" >> /etc/pam.d/common-auth
# sed -i 's/deny=[0-9]\+/deny=5/' /etc/pam.d/common-auth
# sed -i 's/unlock_time=[0-9]\+/unlock_time=1/' /etc/pam.d/common-auth
cp /etc/pam.d/common-password /etc/pam.d/common-password.bak
sed -i 's/\(pam_unix\.so.*\)$/\1 remember=5 minlen=12/' /etc/pam.d/common-password
sed -i 's/\(pam_cracklib\.so.*\)$/\1 maxclassrepeat=5 maxsequence=5 minclass=4 dcredit=-1 ocredit=-1 lcredit=-1 ucredit=-1 minlen=12 difok=8 retry=5/' /etc/pam.d/common-password # try difok=5
cp /etc/default/useradd /etc/default/useradd.bak
sed -i 's/^EXPIRE=[0-9]\+/EXPIRE=30/' /etc/default/useradd
sed -i 's/^INACTIVE=[0-9]\+/INACTIVE=30/' /etc/default/useradd
# Change password encryption method to SHA512
log "Changing password encryption method to SHA512..."
cp /etc/login.defs /etc/login_with_max_pw_days.defs.bak
sed -i '/^ENCRYPT_METHOD/c\ENCRYPT_METHOD SHA512' /etc/login.defs
echo "SHA_CRYPT_MIN_ROUNDS 12000" >> /etc/login.defs
echo "SHA_CRYPT_MAX_ROUNDS 15000" >> /etc/login.defs

##### CALCULATING TIME #####
end_time=$(date +"%Y-%m-%d, %I:%M:%S %p")
end_secs=$(date +%s.%N)
duration=$(echo "$end_secs - $start_secs" | bc)
final_min=$(echo "$duration / 60" | bc)
final_sec=$(echo "$duration % 60" | bc)

##### ENSURING LANG IS SET TO ENGLISH (US) #####
log "Ensuring language is set to English (US)..."
update-locale LANG=$LANG_TO_KEEP LANGUAGE=$LOCALE_TO_KEEP LC_MESSAGES="POSIX"

##### FINAL NOTES FOR USER #####
log "Finished in $final_min minute(s) and $final_sec second(s)..."
log
log "Final Notes:"
log "Please manually check the world-writable files and the no-user files."
log "Please make sure only the required services are enabled."
log "Please check all the .txt files in the current directory (`pwd`) for any information saved by this script."
service --status-all
log "Make sure updates are installed daily."
ring_bell
read -p "Run \`software-properties-gtk &\`? (Y/n): " check_auto_update
if [[ $check_auto_update =~ ^[Nn].* ]]; then
    software-properties-gtk &
fi
log
# log "Launching settings..."
# if [[ "$DESKTOP_SESSION" == "gnome" ]]; then
#     gnome-control-center > /dev/null 2>&1 &
# elif [[ "$DESKTOP_SESSION" == "cinnamon" ]]; then
#     cinnamon-settings > /dev/null 2>&1 &
# elif [[ "$DESKTOP_SESSION" == "kde" ]]; then
#     systemsettings5 > /dev/null 2>&1 &
# elif [[ "$DESKTOP_SESSION" == "xfce" ]]; then
#     xfce4-settings-manager > /dev/null 2>&1 &
# else
#     log "Unsupported desktop environment (standalone window managers are not supported). Please open settings manually (if needed)."
# fi

##### WISH GOOD LUCK #####
log;log;log;
log "Thank you for using this script. Good luck for the competition!"
log
log "==================================="
log "Copyright (c) 2024 Tanav Malhotra"
log "GNU General Public License v3.0"
log "==================================="
log
log_info "End time: " $end_time # log end time

##### REBOOT #####
ring_bell
read -p "Reboot the system? (y/N): " reboot_choice
if [[ $reboot_choice =~ ^[Yy].* ]]; then
    log "Rebooting..."
    reboot
else
    log "Remember to manually reboot the system when you're ready."
fi

##### EXIT #####
exit 0
