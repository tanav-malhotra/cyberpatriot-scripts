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

##### VARS #####
LOGFILE="./backdoors_script.log"
AIDE_CONF="/etc/aide/aide.conf"
AIDE_DB="/var/lib/aide/aide.db"
AIDE_DB_NEW="/var/lib/aide/aide.db.new"
AIDE_BIN="/usr/bin/aide"
AIDE_CONF_DIR="/etc/aide"

##### CHECK FOR SUDO #####
echo "Checking for \`sudo\` access (which may request your password)..."
if [[ $EUID -ne 0 ]]; then
    echo "\`sudo\` access is required. Please run \`sudo !!\`"
    exit 1
else
    echo "\`sudo\` access confirmed. Proceeding..."
    sleep 1
fi

##### FUNCTIONS #####
# line seperator
line_sep() {
    echo "----------------------------------"
}
# unusual or suspicious processes
check_processes() {
    echo "Checking for suspicious processes (\`ps aux\`)..." | tee -a $LOGFILE
    ps aux | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# open listening ports
check_ports() {
    echo "Checking for open ports (\`netstat -tulnp\`)..." | tee -a $LOGFILE
    echo "Installing netstat..." | tee -a $LOGFILE
    apt install -y net-tools
    netstat -tulnp | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# check cron jobs
check_cron_jobs() {
    echo "Checking for suspicious cron jobs..." | tee -a $LOGFILE
    echo "\`crontab -l -u root\`..." | tee -a $LOGFILE
    crontab -l -u root | tee -a $LOGFILE
    read
    echo "\`ls /etc/cron.d\`..." | tee -a $LOGFILE
    ls /etc/cron.d | tee -a $LOGFILE
    read
    echo "\`ls /etc/cron.hourly\`..." | tee -a $LOGFILE
    ls /etc/cron.hourly | tee -a $LOGFILE
    read
    echo "\`ls /etc/cron.daily\`..." | tee -a $LOGFILE
    ls /etc/cron.daily | tee -a $LOGFILE
    read
    echo "\`ls /etc/cron.weekly\`..." | tee -a $LOGFILE
    ls /etc/cron.weekly | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# check for recently modified files
check_recent_files() {
    echo "Checking for recently modified files..." | tee -a $LOGFILE
    echo "\`find / -type f -ctime -7\`..." | tee -a $LOGFILE
    find / -type f -ctime -7 | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# check SSH configuration and logs
check_ssh() {
    echo "Checking SSH configuration and logs..." | tee -a $LOGFILE
    echo "\`cat /etc/ssh/sshd_config\`..." | tee -a $LOGFILE
    cat /etc/ssh/sshd_config | tee -a $LOGFILE
    read
    echo "\`/var/log/auth.log | grep ssh\`..." | tee -a $LOGFILE
    cat /var/log/auth.log | grep ssh | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# check for unusual user accounts
check_users() {
    echo "Checking for unusual user accounts..." | tee -a $LOGFILE
    echo "\`cat /etc/passwd\`..." | tee -a $LOGFILE
    cat /etc/passwd | tee -a $LOGFILE
    read
    echo "\`cat /etc/shadow\`..." | tee -a $LOGFILE
    cat /etc/shadow | tee -a $LOGFILE
    read
    cut -d: -f1 /etc/passwd | while read user; do
        if id -nG "$user" | grep -qwE 'sudo|wheel|sudoers|admin'; then
            ROLE="admin"
        else
            ROLE="user"
        fi
        echo "Groups for $ROLE $user:" | tee -a $LOGFILE
        groups $user | tee -a $LOGFILE
    done
    line_sep | tee -a $LOGFILE
}
# check sudoers configuration
check_sudoers() {
    echo "Checking sudoers configuration..." | tee -a $LOGFILE
    echo "\`visudo -c\`..." | tee -a $LOGFILE
    visudo -c | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# check for hidden network connections
check_network_connections() {
    echo "Checking for hidden network connections..." | tee -a $LOGFILE
    echo "\`lsof -i\`..." | tee -a $LOGFILE
    lsof -i | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# check for rootkits using chkrootkit
check_rootkit() {
    echo "Checking for rootkits using chkrootkit..." | tee -a $LOGFILE
    echo "Installing chkrootkit..." | tee -a $LOGFILE
    apt install -y chkrootkit
    echo "\`chkrootkit\`..." | tee -a $LOGFILE
    chkrootkit | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# check for loaded kernel modules
check_kernel_modules() {
    echo "Checking for unusual kernel modules..." | tee -a $LOGFILE
    echo "\`lsmod\`..." | tee -a $LOGFILE
    lsmod | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# check for file integrity (AIDE)
check_file_integrity() {
    echo "Checking file integrity (requires AIDE setup)..." | tee -a $LOGFILE
    echo "Installing AIDE..." | tee -a $LOGFILE
    apt install -y aide
    echo "Configuring AIDE for CyberPatriot..." | tee -a $LOGFILE
    cat > $AIDE_CONF <<EOF
# AIDE configuration for CyberPatriot
database = $AIDE_DB
database_out = $AIDE_DB_NEW
gzip_dbout = yes

# Exclude some directories that may change frequently
exclude = /tmp
exclude = /var/tmp
exclude = /var/log
exclude = /var/run
exclude = /var/cache

# Directories to be monitored
dir = /etc
dir = /bin
dir = /sbin
dir = /usr
dir = /lib
dir = /lib64
dir = /root
dir = /home
dir = /opt
dir = /var/spool
dir = /var/lib
dir = /var/opt

# Files to be monitored
file = /etc/passwd
file = /etc/shadow
file = /etc/group
file = /etc/gshadow
file = /etc/hostname
file = /etc/hosts
file = /etc/sudoers
EOF

    echo "AIDE configuration complete." | tee -a $LOGFILE

    # 3. Initialize AIDE database
    echo "Initializing AIDE database..." | tee -a $LOGFILE
    $AIDE_BIN --init
    if [ $? -eq 0 ]; then
        mv $AIDE_DB_NEW $AIDE_DB
        echo "AIDE database initialized successfully." | tee -a $LOGFILE
    else
        echo "error: Failed to initialize AIDE database. Please check logs." | tee -a $LOGFILE
        exit 1
    fi
    echo "\`aide --check\`..." | tee -a $LOGFILE
    aide --check | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# check for suspicious GRUB modifications
check_grub() {
    echo "Checking for suspicious GRUB configurations..." | tee -a $LOGFILE
    echo "\`cat /etc/default/grub\`..." | tee -a $LOGFILE
    cat /etc/default/grub | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# check suspicious services
check_services() {
    echo "Checking for suspicious services..." | tee -a $LOGFILE
    echo "\`systemctl list-units --type=service --state=running\`..." | tee -a $LOGFILE
    systemctl list-units --type=service --state=running | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# check system logs
check_logs() {
    echo "Checking system logs..." | tee -a $LOGFILE
    echo "\`cat /var/log/auth.log\`..." | tee -a $LOGFILE
    cat /var/log/auth.log | tee -a $LOGFILE | less
    read
    echo "\`cat /var/log/syslog\`..." | tee -a $LOGFILE
    cat /var/log/syslog | tee -a $LOGFILE | less
    read
    echo "\`cat /var/log/daemon.log\`..." | tee -a $LOGFILE
    cat /var/log/daemon.log | tee -a $LOGFILE | less
    line_sep | tee -a $LOGFILE
}

##### RUN FUNCTIONS #####
echo "Updating apt..." | tee -a $LOGFILE
apt update
echo "Searching for backdoors..." | tee -a $LOGFILE
line_sep | tee -a $LOGFILE
check_processes
read
check_ports
read
check_cron_jobs
read
check_recent_files
read
check_ssh
read
check_users
read
check_sudoers
read
check_network_connections
read
check_rootkit
read
check_kernel_modules
read
check_file_integrity
read
check_grub
read
check_services
read
check_logs
read
echo "Finished searching for backdoors..."
echo "Log saved to: $LOGFILE"

##### WISH GOOD LUCK #####
echo;echo;echo;
echo "Thank you for using this script. Good luck for the competition!"
echo
echo "==================================="
echo "Copyright (c) 2024 Tanav Malhotra"
echo "GNU General Public License v3.0"
echo "==================================="
echo
exit 0