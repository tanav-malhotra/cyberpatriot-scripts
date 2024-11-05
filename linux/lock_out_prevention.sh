#!/bin/bash
# =========================================================
# Author: Tanav Malhotra
# License: GNU General Public License v3.0
# Copyright (c) 2024 Tanav Malhotra
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

# Wishing Goodluck
echo;echo;echo;
echo "Thank you for using this script. Good luck for the competition!"
echo
echo "==================================="
echo "Copyright (c) 2024 Tanav Malhotra"
echo "GNU General Public License v3.0"
echo "==================================="
echo
exit 0