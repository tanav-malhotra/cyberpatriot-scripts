#!/bin/bash
# Check for sudo access
log "Checking for \`sudo\` access (which may request your password)..."
if [[ $EUID -ne 0 ]]; then
    log "\`sudo\` access is required. Please run \`sudo !!\`"
    exit 1
else
    log "\`sudo\` access confirmed. Proceeding..."
    sleep 1
fi

# Preventing getting locked out
while true; do
    /sbin/pam_tally2 -u "$USER" --reset
    sleep 5
done
