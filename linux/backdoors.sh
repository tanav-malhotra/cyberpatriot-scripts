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
    echo "Checking for suspicious processes..." | tee -a $LOGFILE
    ps aux | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# open listening ports
check_ports() {
    echo "Checking for open ports..." | tee -a $LOGFILE
    netstat -tulnp | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# check cron jobs
check_cron_jobs() {
    echo "Checking for suspicious cron jobs..." | tee -a $LOGFILE
    crontab -l -u root | tee -a $LOGFILE
    ls /etc/cron.d | tee -a $LOGFILE
    ls /etc/cron.daily | tee -a $LOGFILE
    ls /etc/cron.hourly | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# check for recently modified files
check_recent_files() {
    echo "Checking for recently modified files..." | tee -a $LOGFILE
    find / -type f -ctime -7 | tee -a $LOGFILE
    find / -type f -name '.*' | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# check SSH configuration and logs
check_ssh() {
    echo "Checking SSH configuration and logs..." | tee -a $LOGFILE
    cat /etc/ssh/sshd_config | tee -a $LOGFILE
    cat /var/log/auth.log | grep ssh | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# check for unusual user accounts
check_users() {
    echo "Checking for unusual user accounts..." | tee -a $LOGFILE
    cat /etc/passwd | tee -a $LOGFILE
    cat /etc/shadow | tee -a $LOGFILE
    groups username | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# check sudoers configuration
check_sudoers() {
    echo "Checking sudoers configuration..." | tee -a $LOGFILE
    vi-c | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# check for hidden network connections
check_network_connections() {
    echo "Checking for hidden network connections..." | tee -a $LOGFILE
    lsof -i | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# check for rootkits using chkrootkit
check_rootkit() {
    echo "Checking for rootkits using chkrootkit..." | tee -a $LOGFILE
    chkrootkit | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# check for loaded kernel modules
check_kernel_modules() {
    echo "Checking for unusual kernel modules..." | tee -a $LOGFILE
    lsmod | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# check for file integrity (AIDE)
check_file_integrity() {
    echo "Checking file integrity (requires AIDE setup)..." | tee -a $LOGFILE
    if command -v aide >/dev/null 2>&1; then
        aide --check | tee -a $LOGFILE
    else
        echo "AIDE not installed. Skipping file integrity check." | tee -a $LOGFILE
    fi
    line_sep | tee -a $LOGFILE
}
# check for suspicious GRUB modifications
check_grub() {
    echo "Checking for suspicious GRUB configurations..." | tee -a $LOGFILE
    cat /etc/default/grub | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# check suspicious services
check_services() {
    echo "Checking for suspicious services..." | tee -a $LOGFILE
    systemctl list-units --type=service --state=running | tee -a $LOGFILE
    line_sep | tee -a $LOGFILE
}
# check system logs
check_logs() {
    echo "Checking system logs..." | tee -a $LOGFILE
    cat /var/log/auth.log | tee -a $LOGFILE | less
    cat /var/log/syslog | tee -a $LOGFILE | less
    cat /var/log/daemon.log | tee -a $LOGFILE | less
    line_sep | tee -a $LOGFILE
}

##### RUN FUNCTIONS #####
echo "Searching for backdoors..."
line_sep | tee -a $LOGFILE
check_processes
check_ports
check_cron_jobs
check_recent_files
check_ssh
check_users
check_sudoers
check_network_connections
check_rootkit
check_kernel_modules
check_file_integrity
check_grub
check_services
check_logs
echo "Finished searching for backdoors..."
echo "Log saved to: $LOGFILE"

##### WISH GOODLUCK #####
echo;echo;echo;
echo "Thank you for using this script. Good luck for the competition!"
echo
echo "==================================="
echo "Copyright (c) 2024 Tanav Malhotra"
echo "GNU General Public License v3.0"
echo "==================================="
echo
exit 0