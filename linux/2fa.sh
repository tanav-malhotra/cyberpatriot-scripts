#!/bin/bash
# =========================================================
# Author: Tanav Malhotra
# License: GNU General Public License v3.0
# Copyright (C) 2024 Tanav Malhotra
#
# DISCLAIMER:
# THE SCRIPT IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
# KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE, AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF
# CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR
# IN CONNECTION WITH THE SCRIPT OR THE USE OR OTHER DEALINGS
# IN THE SCRIPT.
# =========================================================

# Check for access
log "Checking for \`\` access (which may request your password)..."
if [[ $EUID -ne 0 ]]; then
    log "\`\` access is required. Please run \` !!\`"
    exit 1
else
    log "\`\` access confirmed. Proceeding..."
    sleep 1
fi

apt update -y && apt install -y ufw libpam-google-authenticator
ufw allow OpenSSH
ufw enable
ufw logging on
ufw logging high

# ALLOWED_IPS=("192.168.1.100" "203.0.113.50")  # Replace with IPs
# for IP in "${ALLOWED_IPS[@]}"; do
#     ufw allow from "$IP" to any port 22
# done

# Set up Google Authenticator for the user
if [ -f "/home/$USER/.google_authenticator" ]; then
    echo "Google Authenticator is already set up for user $USER."
else
    echo "Setting up Google Authenticator for user $USER."
    google-authenticator -t -d -f -r 3 -R 30 -w 3
    echo "Please scan the QR code displayed and save the emergency codes."
fi

# Configure PAM to use Google Authenticator
echo "Updating PAM configuration for SSH."
if ! grep -q "auth required pam_google_authenticator.so" /etc/pam.d/sshd; then
    echo "auth required pam_google_authenticator.so" | tee -a /etc/pam.d/sshd
fi

# Update SSH config to require 2FA
echo "Updating SSH configuration."
if ! grep -q "ChallengeResponseAuthentication yes" /etc/ssh/sshd_config; then
    echo "ChallengeResponseAuthentication yes" | tee -a /etc/ssh/sshd_config
fi

# Restart SSH service to apply changes
systemctl restart sshd

echo "UFW is configured and Google Authenticator setup is complete."

# ===========================================
# Author: Tanav Malhotra
# License: GNU General Public License v3.0
# Copyright (C) 2024 Tanav Malhotra
# ===========================================